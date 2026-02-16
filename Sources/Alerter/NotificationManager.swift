import AppKit
import UserNotifications

struct NotificationConfig {
    let title: String
    let subtitle: String?
    let message: String
    let closeLabel: String?
    let actions: [String]?
    let dropdownLabel: String?
    let replyPlaceholder: String?
    let sound: String?
    let groupID: String?
    let appIcon: String?
    let contentImage: String?
    let timeout: Int
    let outputJSON: Bool
    let ignoreDnD: Bool
    let uuid: String
}

private let kCategoryIdentifier = "ALERTER_CATEGORY"
private let kReplyActionIdentifier = "REPLY_ACTION"
private let kMaxActions = 4

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var currentRequestIdentifier: String?
    private var currentConfig: NotificationConfig?
    private var deliveryDate: Date?

    // MARK: - Authorization

    /// Check authorization status synchronously (before NSApp.run()).
    func getAuthorizationStatus() -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let sem = DispatchSemaphore(value: 0)
        var status: UNAuthorizationStatus = .notDetermined

        center.getNotificationSettings { settings in
            status = settings.authorizationStatus
            sem.signal()
        }
        sem.wait()
        return status
    }

    /// Request authorization. Called when launched via `open` (LaunchServices).
    /// Uses NSApp.run() so the system auth dialog can appear.
    func handleAuthorizationRequest() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
            exit(0)
        }
        NSApplication.shared.run()
    }

    // MARK: - Deliver (async, called from main queue after NSApp.run())

    func deliverNotification(config: NotificationConfig) {
        currentConfig = config

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Remove earlier notification with the same group ID (async)
        if let groupID = config.groupID {
            removeNotificationAsync(groupID: groupID) {
                self.buildAndDeliver(config: config, center: center)
            }
        } else {
            buildAndDeliver(config: config, center: center)
        }
    }

    private func buildAndDeliver(config: NotificationConfig, center: UNUserNotificationCenter) {
        // Register category with actions
        let categoryID = registerCategory(for: config)

        // Build notification content
        let content = UNMutableNotificationContent()
        content.title = config.title
        if let subtitle = config.subtitle {
            content.subtitle = subtitle
        }
        content.body = config.message
        content.categoryIdentifier = categoryID

        // Store config info in userInfo for callbacks
        var userInfo: [String: String] = ["uuid": config.uuid, "timeout": "\(config.timeout)"]
        if let groupID = config.groupID { userInfo["groupID"] = groupID }
        userInfo["output"] = config.outputJSON ? "json" : "outputEvent"
        if let closeLabel = config.closeLabel { userInfo["closeLabel"] = closeLabel }
        content.userInfo = userInfo

        // Thread identifier (grouping)
        if let groupID = config.groupID {
            content.threadIdentifier = groupID
        }

        // Sound
        if let sound = config.sound {
            content.sound = (sound == "default") ? .default : UNNotificationSound(named: UNNotificationSoundName(sound))
        }

        // Content image (best-effort via attachment)
        if let contentImagePath = config.contentImage {
            if let attachment = createAttachment(from: contentImagePath) {
                content.attachments = [attachment]
            } else {
                printStderr("Warning: --contentImage could not be attached. UNNotificationAttachment may not render images on macOS as expected.")
            }
        }

        // Warnings for deprecated/unsupported features
        if config.appIcon != nil {
            printStderr("Warning: --appIcon is not supported with UNUserNotificationCenter (no public API equivalent). Ignored.")
        }
        if config.ignoreDnD {
            printStderr("Warning: --ignoreDnd is not supported with UNUserNotificationCenter (no public API equivalent). Ignored.")
        }
        if let _ = config.dropdownLabel {
            printStderr("Warning: --dropdownLabel is not supported with UNUserNotificationCenter. Actions will be shown as flat buttons.")
        }
        if let actions = config.actions, actions.count > kMaxActions {
            printStderr("Warning: macOS limits notification actions to \(kMaxActions). Extra actions will be ignored.")
        }

        // Deliver immediately (nil trigger)
        let requestIdentifier = config.uuid
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: nil)

        center.add(request) { error in
            if let error = error {
                self.printStderr("Failed to deliver notification: \(error.localizedDescription)")
                exit(1)
            }

            self.currentRequestIdentifier = requestIdentifier
            self.deliveryDate = Date()

            // Timeout handler
            if config.timeout > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(config.timeout)) { [weak self] in
                    center.removeDeliveredNotifications(withIdentifiers: [requestIdentifier])
                    DispatchQueue.main.async {
                        let event = ActivationEvent(
                            type: .timeout,
                            value: nil,
                            valueIndex: nil,
                            deliveredAt: self?.deliveryDate,
                            activatedAt: Date()
                        )
                        self?.outputAndExit(event: event)
                    }
                }
            }
        }
    }

    // MARK: - Remove

    func removeNotification(groupID: String) {
        let center = UNUserNotificationCenter.current()
        let sem = DispatchSemaphore(value: 0)
        var delivered: [UNNotification] = []

        center.getDeliveredNotifications { notifications in
            delivered = notifications
            sem.signal()
        }
        sem.wait()

        var idsToRemove: [String] = []
        for notification in delivered {
            let info = notification.request.content.userInfo
            if groupID == "ALL" || (info["groupID"] as? String) == groupID {
                idsToRemove.append(notification.request.identifier)
            }
        }

        if !idsToRemove.isEmpty {
            center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
        }
    }

    private func removeNotificationAsync(groupID: String, completion: @escaping () -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { notifications in
            var idsToRemove: [String] = []
            for notification in notifications {
                let info = notification.request.content.userInfo
                if groupID == "ALL" || (info["groupID"] as? String) == groupID {
                    idsToRemove.append(notification.request.identifier)
                }
            }
            if !idsToRemove.isEmpty {
                center.removeDeliveredNotifications(withIdentifiers: idsToRemove)
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    // MARK: - List

    func listNotifications(groupID: String) {
        let center = UNUserNotificationCenter.current()
        let sem = DispatchSemaphore(value: 0)
        var delivered: [UNNotification] = []

        center.getDeliveredNotifications { notifications in
            delivered = notifications
            sem.signal()
        }
        sem.wait()

        var results: [[String: String]] = []
        for notification in delivered {
            let content = notification.request.content
            let info = content.userInfo
            let deliveredGroupID = info["groupID"] as? String
            if groupID == "ALL" || deliveredGroupID == groupID {
                var entry: [String: String] = [:]
                entry["GroupID"] = deliveredGroupID
                entry["Title"] = content.title
                entry["subtitle"] = content.subtitle
                entry["message"] = content.body
                entry["deliveredAt"] = notification.date.description
                results.append(entry)
            }
        }

        if !results.isEmpty,
           let data = try? JSONSerialization.data(withJSONObject: results, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString, terminator: "")
        }
    }

    // MARK: - Cleanup

    func bye() {
        guard let identifier = currentRequestIdentifier else { return }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        guard info["uuid"] as? String == currentConfig?.uuid else {
            completionHandler()
            return
        }

        let event: ActivationEvent

        switch response.actionIdentifier {
        case UNNotificationDismissActionIdentifier:
            let closeLabel = info["closeLabel"] as? String
            event = ActivationEvent(
                type: .closed,
                value: closeLabel,
                valueIndex: nil,
                deliveredAt: deliveryDate,
                activatedAt: Date()
            )

        case UNNotificationDefaultActionIdentifier:
            event = ActivationEvent(
                type: .contentsClicked,
                value: nil,
                valueIndex: nil,
                deliveredAt: deliveryDate,
                activatedAt: Date()
            )

        case kReplyActionIdentifier:
            let userText = (response as? UNTextInputNotificationResponse)?.userText
            event = ActivationEvent(
                type: .replied,
                value: userText,
                valueIndex: nil,
                deliveredAt: deliveryDate,
                activatedAt: Date()
            )

        default:
            // Action buttons: ACTION_0, ACTION_1, ...
            if response.actionIdentifier.hasPrefix("ACTION_"),
               let indexStr = response.actionIdentifier.split(separator: "_").last,
               let index = Int(indexStr) {
                let actions = currentConfig?.actions ?? []
                let actionTitle = index < actions.count ? actions[index] : response.actionIdentifier
                event = ActivationEvent(
                    type: .actionClicked,
                    value: actionTitle,
                    valueIndex: index,
                    deliveredAt: deliveryDate,
                    activatedAt: Date()
                )
            } else {
                event = ActivationEvent(
                    type: .none,
                    value: nil,
                    valueIndex: nil,
                    deliveredAt: deliveryDate,
                    activatedAt: Date()
                )
            }
        }

        center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
        completionHandler()
        outputAndExit(event: event)
    }

    // MARK: - Private

    private func registerCategory(for config: NotificationConfig) -> String {
        var actions: [UNNotificationAction] = []

        if let replyPlaceholder = config.replyPlaceholder {
            // Reply action
            let replyAction = UNTextInputNotificationAction(
                identifier: kReplyActionIdentifier,
                title: "Reply",
                options: [],
                textInputButtonTitle: "Send",
                textInputPlaceholder: replyPlaceholder
            )
            actions.append(replyAction)
        } else if let actionTitles = config.actions, !actionTitles.isEmpty {
            // Button actions (max kMaxActions)
            let limit = min(actionTitles.count, kMaxActions)
            for i in 0..<limit {
                let action = UNNotificationAction(
                    identifier: "ACTION_\(i)",
                    title: actionTitles[i],
                    options: [.foreground]
                )
                actions.append(action)
            }
        }

        let category = UNNotificationCategory(
            identifier: kCategoryIdentifier,
            actions: actions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
        return kCategoryIdentifier
    }

    private func createAttachment(from path: String) -> UNNotificationAttachment? {
        let url: URL
        if let parsed = URL(string: path), let scheme = parsed.scheme, !scheme.isEmpty, scheme != "file" {
            // Remote URL — download to temp file
            guard let data = try? Data(contentsOf: parsed) else { return nil }
            let ext = parsed.pathExtension.isEmpty ? "png" : parsed.pathExtension
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
            do {
                try data.write(to: tempURL)
                return try UNNotificationAttachment(identifier: UUID().uuidString, url: tempURL, options: nil)
            } catch {
                return nil
            }
        } else {
            url = URL(fileURLWithPath: path)
            // Copy to temp to avoid file access issues
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + ext)
            do {
                try FileManager.default.copyItem(at: url, to: tempURL)
                return try UNNotificationAttachment(identifier: UUID().uuidString, url: tempURL, options: nil)
            } catch {
                return nil
            }
        }
    }

    private func outputAndExit(event: ActivationEvent) {
        let output = OutputFormatter.format(event: event, asJSON: currentConfig?.outputJSON ?? false)
        print(output, terminator: "")
        exit(0)
    }

    func printStderr(_ message: String) {
        FileHandle.standardError.write(Data("[!] \(message)\n".utf8))
    }
}
