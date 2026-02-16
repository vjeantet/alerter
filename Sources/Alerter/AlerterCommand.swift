import ArgumentParser
import AppKit
import UserNotifications
import BundleHook

struct AlerterCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "alerter",
        abstract: "A command-line tool to send macOS user notifications.",
        version: "26.2"
    )

    // MARK: - Required (at least one)

    @Option(help: "The notification message.")
    var message: String?

    @Option(help: "Remove a notification with the specified group ID.")
    var remove: String?

    @Option(help: "List notifications by group ID, or use 'ALL' to see all.")
    var list: String?

    // MARK: - Reply

    @Option(help: "Display as reply-type alert. VALUE is used as placeholder text.")
    var reply: String?

    // MARK: - Actions

    @Option(help: "Comma-separated list of actions. Multiple values create a dropdown.")
    var actions: String?

    @Option(help: "Label for the actions dropdown (when multiple actions).")
    var dropdownLabel: String?

    // MARK: - Optional

    @Option(help: "The notification title. (default: Terminal)")
    var title: String = "Terminal"

    @Option(help: "The notification subtitle.")
    var subtitle: String?

    @Option(help: "The close button label.")
    var closeLabel: String?

    @Option(help: "Sound name to play. Use 'default' for the default sound.")
    var sound: String?

    @Option(help: "Group ID for notification replacement.")
    var group: String?

    @Option(help: "Bundle identifier of the app to impersonate. (default: fr.vjeantet.alerter)")
    var sender: String = "fr.vjeantet.alerter"

    @Option(help: "URL or path of an image to use as app icon.")
    var appIcon: String?

    @Option(help: "URL or path of an image attached to the notification.")
    var contentImage: String?

    @Option(help: "Auto-close the notification after N seconds.")
    var timeout: Int = 0

    @Flag(help: "Output result as JSON.")
    var json: Bool = false

    @Flag(help: "Send notification even if Do Not Disturb is enabled.")
    var ignoreDnd: Bool = false

    // Internal flag: request notification authorization and exit (launched via `open`)
    @Flag(name: .long, help: .hidden)
    var authorizeNotifications: Bool = false

    // Internal flag: indicates this process was launched via LaunchServices (`open`)
    @Flag(name: .long, help: .hidden)
    var launchedByOpen: Bool = false

    // MARK: - Run

    mutating func validate() throws {
        // These internal flags bypass normal validation
        if authorizeNotifications || launchedByOpen { return }

        // Read stdin if no message and input is piped
        if message == nil && isatty(STDIN_FILENO) == 0 {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            let stdinMessage = String(data: data, encoding: .utf8)
            if let msg = stdinMessage, !msg.isEmpty {
                message = msg
            }
        }

        if message == nil && remove == nil && list == nil {
            throw ValidationError("At least one of --message, --remove, or --list is required.")
        }
    }

    func run() throws {
        // Handle authorization-only mode (launched via `open` to request permission)
        if authorizeNotifications {
            NSApplication.shared.setActivationPolicy(.accessory)
            NotificationManager.shared.handleAuthorizationRequest()
            throw ExitCode.success
        }

        // Install fake bundle identifier (before any UNUserNotificationCenter usage)
        _ = InstallFakeBundleIdentifierHook(sender)

        // List
        if let listID = list {
            NotificationManager.shared.listNotifications(groupID: listID)
            throw ExitCode.success
        }

        // Remove
        if let removeID = remove {
            NotificationManager.shared.removeNotification(groupID: removeID)
            if message == nil {
                throw ExitCode.success
            }
        }

        // Deliver notification
        if let message = message {
            let manager = NotificationManager.shared

            // Check authorization status
            let status = manager.getAuthorizationStatus()

            if status == .denied {
                manager.printStderr("Notifications are denied. Please enable them in System Settings > Notifications > alerter.")
                throw ExitCode.failure
            }

            // If not yet authorized and not launched via `open`, relaunch via LaunchServices
            // macOS Sequoia requires apps to be launched via LaunchServices for auth prompts
            if status != .authorized && status != .provisional && !launchedByOpen {
                let appBundle = Bundle.main.bundlePath
                if appBundle.hasSuffix(".app") {
                    return try relaunchViaOpen(appBundle: appBundle, stdinMessage: message)
                }
                manager.printStderr("Notification permission not granted. Please run alerter from its .app bundle.")
                throw ExitCode.failure
            }

            // Launched via `open` but not yet authorized: request authorization now.
            // requestAuthorization() requires LaunchServices launch (which is our case here).
            // The TCC dialog is system-level so it shows even with the main thread blocked.
            if status != .authorized && status != .provisional && launchedByOpen {
                let authSem = DispatchSemaphore(value: 0)
                var authGranted = false
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    authGranted = granted
                    authSem.signal()
                }
                authSem.wait()
                if !authGranted {
                    manager.printStderr("Notification permission was denied. Enable in System Settings > Notifications > alerter.")
                    throw ExitCode.failure
                }
                // Switch from default Banners to Alerts (stay on screen until dismissed)
                manager.setAlertStyle()
            }

            let config = NotificationConfig(
                title: title,
                subtitle: subtitle,
                message: message,
                closeLabel: closeLabel,
                actions: actions?.components(separatedBy: ","),
                dropdownLabel: dropdownLabel,
                replyPlaceholder: reply,
                sound: sound,
                groupID: group,
                appIcon: appIcon,
                contentImage: contentImage,
                timeout: timeout,
                outputJSON: json,
                ignoreDnD: ignoreDnd,
                uuid: "\(NSApplication.shared.hash)"
            )

            // Set activation policy for notification display
            NSApplication.shared.setActivationPolicy(.accessory)

            // Schedule delivery on the main queue (after run loop starts)
            DispatchQueue.main.async {
                manager.deliverNotification(config: config)
            }

            // Start the run loop to receive notification callbacks
            NSApplication.shared.run()
        }
    }

    /// Relaunch the current command via `open` (LaunchServices) to get notification authorization.
    /// Uses temp files for stdout/stderr forwarding since `open` doesn't pipe directly.
    private func relaunchViaOpen(appBundle: String, stdinMessage: String? = nil) throws {
        let tmpDir = FileManager.default.temporaryDirectory.path
        let stdoutPath = tmpDir + "/alerter-stdout-\(ProcessInfo.processInfo.processIdentifier)"
        let stderrPath = tmpDir + "/alerter-stderr-\(ProcessInfo.processInfo.processIdentifier)"

        // Clean up any previous temp files
        try? FileManager.default.removeItem(atPath: stdoutPath)
        try? FileManager.default.removeItem(atPath: stderrPath)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")

        // Build the argument list: original args + --launched-by-open flag
        var appArgs = Array(CommandLine.arguments.dropFirst()) // drop argv[0]
        appArgs.append("--launched-by-open")

        // If the message came from stdin, it's not in the CLI args — add it explicitly
        if let stdinMessage = stdinMessage,
           !appArgs.contains("--message") {
            appArgs.append(contentsOf: ["--message", stdinMessage])
        }

        process.arguments = ["-W", "--stdout", stdoutPath, "--stderr", stderrPath, appBundle, "--args"] + appArgs

        try process.run()
        process.waitUntilExit()

        // Forward the output
        if let stdoutData = FileManager.default.contents(atPath: stdoutPath), !stdoutData.isEmpty {
            FileHandle.standardOutput.write(stdoutData)
        }
        if let stderrData = FileManager.default.contents(atPath: stderrPath), !stderrData.isEmpty {
            FileHandle.standardError.write(stderrData)
        }

        // Clean up temp files
        try? FileManager.default.removeItem(atPath: stdoutPath)
        try? FileManager.default.removeItem(atPath: stderrPath)

        let exitCode = process.terminationStatus
        throw ExitCode(exitCode)
    }

    private func printError(_ message: String) {
        FileHandle.standardError.write(Data("[!] \(message)\n".utf8))
    }
}
