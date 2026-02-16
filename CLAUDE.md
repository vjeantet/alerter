# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Alerter is a macOS command-line tool (Swift + Objective-C bridge) that sends native user notifications and captures user interactions (clicks, replies, actions, timeouts). Output goes to stdout as plain text or JSON.

## Build Commands

```bash
# Build (debug)
swift build

# Build (release)
swift build -c release

# Run directly
swift run alerter --message "Test message"

# Manual test examples
.build/debug/alerter --message "Test message"
.build/debug/alerter --message "Reply test" --reply "Type here"
.build/debug/alerter --message "Actions" --actions "Yes,No,Maybe"
.build/debug/alerter --message "Test" --json
.build/debug/alerter --list ALL
.build/debug/alerter --remove mygroup
.build/debug/alerter --message "Timeout" --timeout 3
.build/debug/alerter --help
```

There are no automated tests. Testing is done manually by invoking the built binary.

## Architecture

Two SPM targets:

- **`BundleHook`** (Objective-C) — Bundle ID swizzling via `method_exchangeImplementations`. Must stay in ObjC as Swift cannot use the ObjC runtime directly. Exposes `InstallFakeBundleIdentifierHook()` to Swift.
- **`alerter`** (Swift) — Main executable with 4 source files:
  - **`main.swift`** — Entry point. Signal handlers (SIGTERM/SIGINT), launches `AlerterCommand`.
  - **`AlerterCommand.swift`** — CLI argument parsing via Swift ArgumentParser (`ParsableCommand`). Orchestrates list/remove/deliver flow, then starts `NSApplication.run()` for notification callbacks.
  - **`NotificationManager.swift`** — Singleton handling notification lifecycle: delivery, removal, listing, delegate callbacks, polling for dismissal, timeout. Contains `NotificationConfig` struct.
  - **`OutputFormatter.swift`** — Formats activation events as plain text (`@CLOSED`, `@TIMEOUT`, `@CONTENTCLICKED`) or JSON.

**Execution flow:** Parse CLI args (ArgumentParser) → validate → deliver notification via NSUserNotificationCenter → `NSApp.run()` → delegate callbacks capture interaction → format output to stdout → `exit(0)`.

## Key Technical Details

- **Private APIs:** Uses undocumented NSUserNotification properties via KVC (`setValue(_:forKey:)`): `_showsButtons`, `_identityImage`, `_alternateActionButtonTitles`, `_ignoresDoNotDisturb`, etc.
- **Bundle ID swapping:** ObjC runtime method swizzling to impersonate other apps' bundle identifiers (`--sender` flag).
- **NSUserNotificationCenter is deprecated** since macOS 10.15. The project uses Swift 5 language mode (`swiftSettings: [.swiftLanguageMode(.v5)]`) to allow these deprecated APIs without strict concurrency errors.
- **Dependency:** `apple/swift-argument-parser` (~> 1.3) via SPM.
- **Deployment target:** macOS 13.0.

## Versioning

Format: **`YY.N`** — `YY` = last 2 digits of the current year, `N` = auto-incrementing number (resets to 1 each year). Examples: `26.1`, `26.2`, `27.1`.

The version is determined automatically by `release.sh` based on existing git tags (`v26.*`). No manual version editing needed.

## Release Workflow

```
1. ./scripts/release.sh                    # bump version, build, sign, notarize, tag, GitHub Release
2. ./scripts/update-homebrew-formula.sh     # update formula in vjeantet/homebrew-tap
```

- `release.sh` auto-bumps the version in `AlerterCommand.swift`, commits, then builds, signs, notarizes (.zip + .pkg), creates a git tag `v$VERSION`, and publishes a GitHub Release with both assets.
- `update-homebrew-formula.sh` computes the SHA256 of the .zip, clones `vjeantet/homebrew-tap`, updates `Formula/alerter.rb`, and pushes.
- Homebrew tap: `vjeantet/homebrew-tap` — users install via `brew install vjeantet/tap/alerter`.
