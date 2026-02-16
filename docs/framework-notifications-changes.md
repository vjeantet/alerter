# Migration NSUserNotificationCenter → UNUserNotificationCenter

This document covers the behavioral changes, regressions, and new capabilities introduced by migrating from the deprecated `NSUserNotificationCenter` to `UNUserNotificationCenter`.

## Regressions

### Features Lost (No Public API Equivalent)

| Flag | Old Behavior | New Behavior | Severity |
|---|---|---|---|
| `--appIcon` | Custom icon via private API `_identityImage` | Ignored — warning emitted to stderr | High |
| `--ignoreDnd` | Bypassed Do Not Disturb via private API `_ignoresDoNotDisturb` | Ignored — warning emitted to stderr. Replaced by `--interruption-level timeSensitive` (see New Features below) | High |
| `--dropdownLabel` | Multiple actions displayed in a labeled dropdown menu | Actions shown as flat buttons — warning emitted to stderr | Medium |

### Features Degraded

| Feature | Old Behavior | New Behavior | Severity |
|---|---|---|---|
| Action count | Unlimited (dropdown via private API `_alternateActionButtonTitles`) | Hard limit of **4 actions** (macOS UNUserNotification limitation). Extra actions are silently discarded with a stderr warning. | High |
| `--contentImage` | Direct support via `notification.contentImage` | Best-effort via `UNNotificationAttachment`. Rendering on macOS is unreliable. | Medium |

### Behavioral Changes

| Behavior | Old | New |
|---|---|---|
| Dismissal detection | Polling every 200ms in background thread | `.customDismissAction` category option — cleaner, event-driven |
| Exit delay | Immediate exit after handling | 0.5s delay to prevent macOS "application is not open anymore" dialog |
| Notification removal/listing | Synchronous | Asynchronous via semaphore |

### New Operational Requirements

| Requirement | Impact |
|---|---|
| **App bundle** | The binary must run inside a `.app` wrapper. Created automatically in `~/Library/Application Support/alerter/` at first run. Adds startup overhead. |
| **Notification authorization** | User must grant permission. If denied, alerter exits with an error. |
| **LaunchServices launch** | Authorization dialog only appears when launched via `open` command. The binary re-launches itself transparently via `open -W`. |
| **Alert style enforcement** | After first authorization, alerter modifies `com.apple.ncprefs.plist` to force "Alerts" style (persistent) and restarts `NotificationCenter` + `usernoted`. |

---

## New Features Available

Features enabled by `UNUserNotificationCenter` that were impossible with the old API.

### Tier 1 — High Impact

#### Interruption Level

> Replaces the deprecated `--ignoreDnd` flag.

| Level | Behavior |
|---|---|
| `passive` | Silent delivery — no sound, no screen wake. Added to Notification Center only. |
| `active` | Default behavior. |
| `timeSensitive` | Breaks through Focus / Do Not Disturb. Requires Time Sensitive entitlement. |
| `critical` | Bypasses DnD AND mute switch. Requires `com.apple.developer.usernotifications.critical-alerts` entitlement from Apple. |

- **API:** `UNMutableNotificationContent.interruptionLevel` (`UNNotificationInterruptionLevel`)
- **Availability:** macOS 12.0+
- **Proposed flag:** `--interruption-level passive|active|timeSensitive|critical`

#### Scheduled Delivery (Time Interval)

Schedule a notification to appear after a delay.

- **API:** `UNTimeIntervalNotificationTrigger(timeInterval:repeats:)`
- **Availability:** macOS 10.14+
- **Proposed flag:** `--delay <seconds>`

#### Scheduled Delivery (Calendar)

Schedule a notification at a specific date/time.

- **API:** `UNCalendarNotificationTrigger(dateMatching:repeats:)`
- **Availability:** macOS 10.14+
- **Proposed flag:** `--at <datetime>`

#### Repeating Notifications

Both time-interval and calendar triggers support `repeats: true`.

- **Availability:** macOS 10.14+
- **Proposed flag:** `--repeat` (used with `--delay` or `--at`)
- **Note:** Time interval triggers require a minimum of 60 seconds when repeating.

#### Action Button Icons (SF Symbols)

Add SF Symbol icons to action buttons for better visual clarity.

- **API:** `UNNotificationActionIcon(systemImageName:)` or `UNNotificationActionIcon(templateImageName:)`
- **Availability:** macOS 12.0+
- **Proposed flag:** `--action-icons "checkmark.circle,xmark.circle"`

#### Action Button Options

Mark actions as destructive (red), requiring authentication, or foreground-launching.

- **API:** `UNNotificationActionOptions` — `.destructive`, `.authenticationRequired`, `.foreground`
- **Availability:** macOS 10.14+
- **Proposed flag:** `--action-options "destructive,foreground"`

#### Badge Count

Set the badge number on the app icon in the Dock.

- **API:** `UNMutableNotificationContent.badge` + `UNUserNotificationCenter.setBadgeCount(_:)`
- **Availability:** macOS 13.0+
- **Proposed flag:** `--badge <number>` (0 clears the badge)

### Tier 2 — Medium Impact

#### Relevance Score

Controls sorting priority among grouped notifications.

- **API:** `UNMutableNotificationContent.relevanceScore` (`Double`, 0.0–1.0)
- **Availability:** macOS 12.0+
- **Proposed flag:** `--relevance-score <0.0-1.0>`

#### Query Notification Settings

Dump the current notification settings (authorization status, alert style, sound/badge/alert enabled, etc.) as JSON.

- **API:** `UNUserNotificationCenter.getNotificationSettings()`
- **Availability:** macOS 10.14+
- **Proposed flag:** `--settings`

#### Pending Notification Management

List or remove notifications that are scheduled but not yet delivered.

- **API:** `getPendingNotificationRequests()`, `removePendingNotificationRequests(withIdentifiers:)`
- **Availability:** macOS 10.14+
- **Proposed flags:** `--list-pending`, `--remove-pending <group>`

#### Foreground Presentation Control

Control how the notification is displayed when the app is in the foreground. Currently hardcoded to `[.banner, .sound]`.

- **API:** `UNNotificationPresentationOptions` — `.list`, `.banner`, `.badge`, `.sound`
- **Availability:** macOS 11.0+
- **Proposed flag:** `--presentation "list,banner,sound"`

### Tier 3 — Niche

#### Focus Filter Criteria

Allows the system to decide whether to show the notification based on the current Focus mode.

- **API:** `UNMutableNotificationContent.filterCriteria`
- **Availability:** macOS 13.0+
- **Proposed flag:** `--filter-criteria <string>`

#### Provisional Authorization

Deliver notifications silently without an explicit user permission prompt. Notifications go directly to Notification Center.

- **API:** `UNAuthorizationOptions.provisional`
- **Availability:** macOS 10.14+
- **Proposed flag:** `--provisional`

#### Attachment Thumbnail Options

Control how the notification attachment thumbnail is displayed.

- **API:** `UNNotificationAttachmentOptionsThumbnailHiddenKey`, `UNNotificationAttachmentOptionsThumbnailClippingRectKey`, `UNNotificationAttachmentOptionsThumbnailTimeKey`
- **Availability:** macOS 10.14+
- **Proposed flags:** `--thumbnail-hidden`, `--thumbnail-time <seconds>`

#### Multiple Attachments

The API accepts an array of attachments, allowing mixed media types (image + audio).

- **API:** `UNMutableNotificationContent.attachments` (`[UNNotificationAttachment]`)
- **Availability:** macOS 10.14+
- **Proposed flag:** `--attachment <path>` (repeatable)

---

## Not Available on macOS

These UNUserNotificationCenter features are explicitly unavailable on macOS:

| Feature | Reason |
|---|---|
| `targetContentIdentifier` | iOS 13+ only |
| `launchImageName` | `API_UNAVAILABLE(macos)` |
| `UNLocationNotificationTrigger` | `API_UNAVAILABLE(macos)` |
| `defaultRingtoneSound` / `ringtoneSoundNamed` | `API_UNAVAILABLE(macos)` |
| `.allowInCarPlay` (category option) | `API_UNAVAILABLE(macos)` |
| `.allowAnnouncement` (category option) | `API_UNAVAILABLE(macos)`, deprecated |
| `UNAuthorizationStatusEphemeral` | iOS App Clips only |

---

## Summary

The migration trades **3 private-API features** (appIcon, ignoreDnd, unlimited dropdown actions) for a **supported, future-proof API** with significant new capabilities — most notably interruption levels, scheduled/repeating notifications, action icons, and badge control.
