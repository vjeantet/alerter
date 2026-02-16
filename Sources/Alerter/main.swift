import AppKit

/// Generate an app icon from SF Symbol "app.badge" and save as .icns in the given Resources directory.
func generateAppIcon(resourcesDir: String) {
    guard let symbolImage = NSImage(systemSymbolName: "app.badge", accessibilityDescription: nil) else { return }

    let iconsetPath = resourcesDir + "/AppIcon.iconset"
    try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

    let entries: [(String, Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    for (name, px) in entries {
        let size = NSSize(width: px, height: px)
        let pointSize = CGFloat(px) * 0.85
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        guard let configured = symbolImage.withSymbolConfiguration(config) else { continue }

        let icon = NSImage(size: size, flipped: false) { rect in
            let symSize = configured.size
            let x = (rect.width - symSize.width) / 2
            let y = (rect.height - symSize.height) / 2
            configured.draw(in: NSRect(x: x, y: y, width: symSize.width, height: symSize.height))
            NSColor.systemBlue.set()
            NSRect(x: x, y: y, width: symSize.width, height: symSize.height).fill(using: .sourceAtop)
            return true
        }
        icon.isTemplate = false

        guard let tiffData = icon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else { continue }
        try? pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(name).png"))
    }

    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconsetPath, "-o", resourcesDir + "/AppIcon.icns"]
    iconutil.standardOutput = FileHandle.nullDevice
    iconutil.standardError = FileHandle.nullDevice
    try? iconutil.run()
    iconutil.waitUntilExit()

    try? FileManager.default.removeItem(atPath: iconsetPath)
}

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
    let resourcesDir = contentsDir + "/Resources"
    try? FileManager.default.createDirectory(atPath: resourcesDir, withIntermediateDirectories: true)

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
            <key>CFBundleIconFile</key>
            <string>AppIcon</string>
            <key>LSUIElement</key>
            <true/>
        </dict>
        </plist>
        """
    try? plist.write(toFile: contentsDir + "/Info.plist", atomically: true, encoding: .utf8)

    // Generate app icon from SF Symbol
    generateAppIcon(resourcesDir: resourcesDir)

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

    // Determine launch strategy:
    // - --list/--remove (without --message): just need .app bundle context → execv
    // - --message (or stdin piped): needs LaunchServices for notification auth → open -W
    //   Launching via open directly (instead of execv + relaunchViaOpen) avoids having
    //   two processes from the same .app bundle, which confuses macOS action delivery.
    let isListOrRemoveOnly = (args.contains("--list") || args.contains("--remove"))
        && !args.contains("--message")

    if isListOrRemoveOnly {
        var newArgs = CommandLine.arguments
        newArgs[0] = binaryDest
        let cArgs = newArgs.map { strdup($0) } + [nil]
        execv(binaryDest, cArgs)
        cArgs.forEach { free($0) }
        return
    }

    // For notification delivery: launch via open (LaunchServices) directly.
    // Only one process from .app will exist — no dual-process confusion.
    var appArgs = Array(CommandLine.arguments.dropFirst())
    appArgs.append("--launched-by-open")

    // Read stdin if piped (open can't forward stdin)
    if !appArgs.contains("--message") && isatty(STDIN_FILENO) == 0 {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        if let msg = String(data: data, encoding: .utf8), !msg.isEmpty {
            appArgs.append(contentsOf: ["--message", msg])
        }
    }

    let tmpDir = FileManager.default.temporaryDirectory.path
    let pid = ProcessInfo.processInfo.processIdentifier
    let stdoutPath = tmpDir + "/alerter-stdout-\(pid)"
    let stderrPath = tmpDir + "/alerter-stderr-\(pid)"
    try? FileManager.default.removeItem(atPath: stdoutPath)
    try? FileManager.default.removeItem(atPath: stderrPath)

    let openProcess = Process()
    openProcess.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    openProcess.arguments = ["-W", "--stdout", stdoutPath, "--stderr", stderrPath, appBase, "--args"] + appArgs

    guard let _ = try? openProcess.run() else {
        // Fallback to execv if open fails
        var newArgs = CommandLine.arguments
        newArgs[0] = binaryDest
        let cArgs = newArgs.map { strdup($0) } + [nil]
        execv(binaryDest, cArgs)
        cArgs.forEach { free($0) }
        return
    }

    openProcess.waitUntilExit()

    if let data = FileManager.default.contents(atPath: stdoutPath), !data.isEmpty {
        FileHandle.standardOutput.write(data)
    }
    if let data = FileManager.default.contents(atPath: stderrPath), !data.isEmpty {
        FileHandle.standardError.write(data)
    }

    try? FileManager.default.removeItem(atPath: stdoutPath)
    try? FileManager.default.removeItem(atPath: stderrPath)

    exit(openProcess.terminationStatus)
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
