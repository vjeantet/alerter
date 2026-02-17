import AppKit

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

class NotificationManager: NSObject, NSUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var currentNotification: NSUserNotification?
    private var currentConfig: NotificationConfig?
    private var hasExited = false

    // MARK: - Deliver

    func deliverNotification(config: NotificationConfig) {
        currentConfig = config

        // Remove earlier notification with the same group ID
        if let groupID = config.groupID {
            removeNotification(groupID: groupID)
        }

        let notification = NSUserNotification()
        notification.title = config.title
        notification.subtitle = config.subtitle
        notification.informativeText = config.message

        // Store config info in userInfo for callbacks
        var userInfo: [String: String] = ["uuid": config.uuid, "timeout": "\(config.timeout)"]
        if let groupID = config.groupID { userInfo["groupID"] = groupID }
        userInfo["output"] = config.outputJSON ? "json" : "outputEvent"
        notification.userInfo = userInfo

        // App icon (private API)
        if let appIconPath = config.appIcon {
            if let image = loadImage(from: appIconPath) {
                notification.setValue(image, forKey: "_identityImage")
                notification.setValue(false, forKey: "_identityImageHasBorder")
            }
        }

        // Content image
        if let contentImagePath = config.contentImage {
            notification.contentImage = loadImage(from: contentImagePath)
        }

        // Actions
        if let actions = config.actions, !actions.isEmpty {
            notification.setValue(true, forKey: "_showsButtons")
            if actions.count > 1 {
                notification.setValue(true, forKey: "_alwaysShowAlternateActionMenu")
                notification.setValue(actions, forKey: "_alternateActionButtonTitles")
                if let dropdownLabel = config.dropdownLabel {
                    notification.actionButtonTitle = dropdownLabel
                    notification.hasActionButton = true
                }
            } else {
                notification.actionButtonTitle = actions[0]
            }
        } else if config.replyPlaceholder != nil {
            notification.setValue(true, forKey: "_showsButtons")
            notification.hasReplyButton = true
            notification.responsePlaceholder = config.replyPlaceholder
        }

        // Close button
        if let closeLabel = config.closeLabel {
            notification.otherButtonTitle = closeLabel
        }

        // Sound
        if let sound = config.sound {
            notification.soundName = (sound == "default") ? NSUserNotificationDefaultSoundName : sound
        }

        // Ignore Do Not Disturb (private API)
        if config.ignoreDnD {
            notification.setValue(true, forKey: "_ignoresDoNotDisturb")
        }

        let center = NSUserNotificationCenter.default
        center.delegate = self
        center.deliver(notification)
    }

    // MARK: - Remove

    func removeNotification(groupID: String) {
        let center = NSUserNotificationCenter.default
        for notification in center.deliveredNotifications {
            if groupID == "ALL" || notification.userInfo?["groupID"] as? String == groupID {
                center.removeDeliveredNotification(notification)
            }
        }
    }

    // MARK: - List

    func listNotifications(groupID: String) {
        let center = NSUserNotificationCenter.default
        var results: [[String: String]] = []

        for notification in center.deliveredNotifications {
            let deliveredGroupID = notification.userInfo?["groupID"] as? String
            if groupID == "ALL" || deliveredGroupID == groupID {
                var entry: [String: String] = [:]
                entry["groupID"] = deliveredGroupID
                entry["title"] = notification.title
                entry["subtitle"] = notification.subtitle
                entry["message"] = notification.informativeText
                entry["deliveredAt"] = notification.actualDeliveryDate?.description
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
        guard let uuid = currentNotification?.userInfo?["uuid"] as? String else { return }
        let center = NSUserNotificationCenter.default
        for notification in center.deliveredNotifications {
            if notification.userInfo?["uuid"] as? String == uuid {
                center.removeDeliveredNotification(notification)
            }
        }
    }

    // MARK: - NSUserNotificationCenterDelegate

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                didDeliver notification: NSUserNotification) {
        currentNotification = notification
        startDismissalPolling(for: notification)
        startTimeoutIfNeeded(for: notification, center: center)
    }

    private func startDismissalPolling(for notification: NSUserNotification) {
        let uuid = currentConfig?.uuid ?? ""
        DispatchQueue.global().async { [weak self] in
            while true {
                var stillPresent = false
                for n in NSUserNotificationCenter.default.deliveredNotifications {
                    if n.userInfo?["uuid"] as? String == uuid {
                        stillPresent = true
                    }
                }
                if !stillPresent {
                    DispatchQueue.main.async {
                        let event = ActivationEvent(
                            type: .closed,
                            value: notification.otherButtonTitle,
                            valueIndex: nil,
                            deliveredAt: notification.actualDeliveryDate,
                            activatedAt: Date()
                        )
                        self?.outputAndExit(event: event)
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
    }

    private func startTimeoutIfNeeded(for notification: NSUserNotification, center: NSUserNotificationCenter) {
        guard let config = currentConfig, config.timeout > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(config.timeout)) { [weak self] in
            center.removeDeliveredNotification(notification)
            let event = ActivationEvent(
                type: .timeout,
                value: nil,
                valueIndex: nil,
                deliveredAt: notification.actualDeliveryDate,
                activatedAt: Date()
            )
            self?.outputAndExit(event: event)
        }
    }

    func userNotificationCenter(_ center: NSUserNotificationCenter,
                                didActivate notification: NSUserNotification) {
        guard notification.userInfo?["uuid"] as? String == currentConfig?.uuid else { return }

        let event = activationEvent(for: notification)
        center.removeDeliveredNotification(notification)
        if let current = currentNotification {
            center.removeDeliveredNotification(current)
        }
        outputAndExit(event: event)
    }

    private func activationEvent(for notification: NSUserNotification) -> ActivationEvent {
        let deliveredAt = notification.actualDeliveryDate
        let activatedAt = Date()

        switch notification.activationType {
        case .additionalActionClicked, .actionButtonClicked:
            return actionClickedEvent(notification: notification, deliveredAt: deliveredAt, activatedAt: activatedAt)

        case .contentsClicked:
            return ActivationEvent(type: .contentsClicked, value: nil, valueIndex: nil,
                                   deliveredAt: deliveredAt, activatedAt: activatedAt)

        case .replied:
            return ActivationEvent(type: .replied, value: notification.response?.string, valueIndex: nil,
                                   deliveredAt: deliveredAt, activatedAt: activatedAt)

        case .none:
            fallthrough
        @unknown default:
            return ActivationEvent(type: .none, value: nil, valueIndex: nil,
                                   deliveredAt: deliveredAt, activatedAt: activatedAt)
        }
    }

    private func actionClickedEvent(notification: NSUserNotification,
                                    deliveredAt: Date?, activatedAt: Date) -> ActivationEvent {
        let alternateTitles = (notification as NSObject).value(forKey: "_alternateActionButtonTitles") as? [String]
        if let titles = alternateTitles, titles.count > 1 {
            let index = ((notification as NSObject).value(forKey: "_alternateActionIndex") as? NSNumber)?.intValue ?? 0
            return ActivationEvent(type: .actionClicked, value: titles[index], valueIndex: index,
                                   deliveredAt: deliveredAt, activatedAt: activatedAt)
        }
        return ActivationEvent(type: .actionClicked, value: notification.actionButtonTitle, valueIndex: nil,
                               deliveredAt: deliveredAt, activatedAt: activatedAt)
    }

    // MARK: - Private

    private func outputAndExit(event: ActivationEvent) {
        guard !hasExited else { return }
        hasExited = true
        let output = OutputFormatter.format(event: event, asJSON: currentConfig?.outputJSON ?? false)
        print(output, terminator: "")
        exit(0)
    }

    private func loadImage(from path: String) -> NSImage? {
        let url: URL
        if let parsed = URL(string: path), parsed.scheme != nil, !parsed.scheme!.isEmpty {
            url = parsed
        } else {
            url = URL(fileURLWithPath: path)
        }
        return NSImage(contentsOf: url)
    }
}
