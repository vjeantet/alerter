import AppKit

// UNUserNotificationCenter requires a proper .app bundle (bundleProxyForCurrentProcess).
// If running as a bare CLI executable, create a wrapper .app bundle and re-exec from it.
// The .app bundle is placed in ~/Library/Application Support/alerter/ (not /tmp, which
// macOS Sequoia restricts for notification authorization).
// The binary is copied (not symlinked) and ad-hoc codesigned for authorization to work.
func ensureRunningFromAppBundle() {
    let bundlePath = Bundle.main.bundlePath
    if bundlePath.hasSuffix(".app") || bundlePath.contains(".app/") {
        return // Already running from an .app bundle
    }

    // Resolve the path to the current executable
    let executablePath = CommandLine.arguments[0]
    let resolvedPath: String
    if executablePath.hasPrefix("/") {
        resolvedPath = executablePath
    } else {
        resolvedPath = FileManager.default.currentDirectoryPath + "/" + executablePath
    }

    // Quick-parse --sender from argv to use the correct bundle ID
    var senderBundleID = "fr.vjeantet.alerter"
    let args = CommandLine.arguments
    for (i, arg) in args.enumerated() {
        if arg == "--sender" && i + 1 < args.count {
            senderBundleID = args[i + 1]
        } else if arg.hasPrefix("--sender=") {
            senderBundleID = String(arg.dropFirst("--sender=".count))
        }
    }

    // Create .app bundle in ~/Library/Application Support/alerter/
    let appSupportDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/alerter").path
    let appBase = appSupportDir + "/alerter.app"
    let contentsDir = appBase + "/Contents"
    let macosDir = contentsDir + "/MacOS"
    let binaryDest = macosDir + "/alerter"

    try? FileManager.default.createDirectory(atPath: macosDir, withIntermediateDirectories: true)

    // Write Info.plist with the appropriate bundle identifier
    let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>\(senderBundleID)</string>
            <key>CFBundleName</key>
            <string>alerter</string>
            <key>CFBundleExecutable</key>
            <string>alerter</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
            <key>LSUIElement</key>
            <true/>
        </dict>
        </plist>
        """
    try? plist.write(toFile: contentsDir + "/Info.plist", atomically: true, encoding: .utf8)

    // Copy the binary (symlinks don't work for codesigning/authorization)
    try? FileManager.default.removeItem(atPath: binaryDest)
    try? FileManager.default.copyItem(atPath: resolvedPath, toPath: binaryDest)

    // Ad-hoc codesign the .app bundle (required for notification authorization)
    let codesign = Process()
    codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    codesign.arguments = ["--force", "--sign", "-", appBase]
    codesign.standardOutput = FileHandle.nullDevice
    codesign.standardError = FileHandle.nullDevice
    try? codesign.run()
    codesign.waitUntilExit()

    // Re-exec from the .app bundle (same PID, replaces process image)
    var newArgs = CommandLine.arguments
    newArgs[0] = binaryDest
    let cArgs = newArgs.map { strdup($0) } + [nil]
    execv(binaryDest, cArgs)

    // If execv failed, clean up and continue anyway (best effort)
    cArgs.forEach { free($0) }
}

ensureRunningFromAppBundle()

let notificationManager = NotificationManager.shared

signal(SIGTERM) { _ in
    notificationManager.bye()
    exit(EXIT_FAILURE)
}

signal(SIGINT) { _ in
    notificationManager.bye()
    exit(EXIT_FAILURE)
}

AlerterCommand.main()
