# Alerter 26.4 — macOS Sequoia Compatibility Fix

Alerter 26.4 is a focused update that fixes a critical compatibility issue on macOS Sequoia. If your notifications were silently disappearing — or never showing up at all — this release is for you.

## What's New

- **Notifications now work out of the box on macOS Sequoia.** macOS 15 silently drops notifications from unrecognized app identities. Alerter now defaults to the Terminal identity (`com.apple.Terminal`), which is always present on every Mac and has notification permissions. Say goodbye to silent failures and hanging processes. ([#59](https://github.com/vjeantet/alerter/issues/59))

- **Improved reliability.** A race condition between the timeout timer and dismissal polling has been fixed, preventing potential double-exit scenarios. Notification callbacks are now more robust and predictable.

- **Cleaner codebase.** Internal refactoring improves readability and maintainability — the notification lifecycle is now split into clear, focused methods.

- **Normalized JSON output for `--list`.** The JSON keys returned by `--list` are now lowercase (`groupID`, `title`, `subtitle`, `message`, `deliveredAt`) for consistency. **Note:** this is a breaking change if you were parsing the previous capitalized keys.

## Upgrading

Install or update via Homebrew:

```bash
brew upgrade vjeantet/tap/alerter
```

Or via MacPorts:

```bash
sudo port upgrade alerter
```

If you were using `--sender` with a custom bundle ID, your setup is unaffected. The default has simply changed from `fr.vjeantet.alerter` to `com.apple.Terminal`.
