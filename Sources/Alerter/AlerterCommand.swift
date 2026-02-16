import ArgumentParser
import AppKit
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

    // MARK: - Run

    mutating func validate() throws {
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
        // List
        if let listID = list {
            NotificationManager.shared.listNotifications(groupID: listID)
            throw ExitCode.success
        }

        // Install fake bundle identifier
        _ = InstallFakeBundleIdentifierHook(sender)

        // Remove
        if let removeID = remove {
            NotificationManager.shared.removeNotification(groupID: removeID)
            if message == nil {
                throw ExitCode.success
            }
        }

        // Deliver notification
        if let message = message {
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

            let manager = NotificationManager.shared
            manager.deliverNotification(config: config)

            // Start the run loop to receive notification callbacks
            NSApplication.shared.run()
        }
    }

    private func printError(_ message: String) {
        FileHandle.standardError.write(Data("[!] \(message)\n".utf8))
    }
}
