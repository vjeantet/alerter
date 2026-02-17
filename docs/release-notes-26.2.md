# Alerter 26.2 — The Swift Era, Refined

**Alerter has been completely rebuilt from the ground up.**

Starting with version 26.0, Alerter continues to mature after its landmark rewrite in Swift. The entire codebase has been modernized, delivering a cleaner, faster, and more reliable notification experience on macOS. Whether you're building automation scripts, integrating notifications into CI/CD pipelines, or just need a quick way to send alerts from the terminal, Alerter 26.2 is ready.

### What's new in the 26.x series

- **Fully rewritten in Swift.** Say goodbye to the legacy Objective-C implementation. Alerter now leverages Swift Package Manager and Swift Argument Parser for a modern, maintainable architecture. The result? A snappier tool with cleaner CLI syntax.

- **New double-dash CLI syntax.** You can now use standard CLI conventions with `--message`, `--title`, `--json`, and all other options. It's the command-line experience you'd expect from a modern tool.

- **Install with Homebrew.** We're excited to announce first-class Homebrew support! Just run `brew install vjeantet/tap/alerter` and you're up and running in seconds. No more manual downloads.

- **Signed and notarized by Apple.** Alerter is now code-signed and notarized, so macOS trusts it out of the box. No more Gatekeeper warnings, no more manual security exceptions — just install, and run.

- **Proper bundle identity.** Alerter now uses its own identity (`fr.vjeantet.alerter`) by default instead of impersonating Terminal. Your notifications look and behave exactly as they should.

- **Reply, actions, JSON output, Do Not Disturb override, and more** — all the features you rely on are still here, now running on a cleaner, faster engine.
