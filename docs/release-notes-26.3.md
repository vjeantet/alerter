# Alerter 26.3 — Schedule It, Style It, Own It

Alerter 26.3 brings powerful new scheduling capabilities and a polished notification experience. You can now precisely control *when* your notifications appear, and they'll look better than ever doing it.

## What's New

- **Schedule notifications for later with `--at`** — You can now deliver a notification at a specific time using `--at HH:mm` (fires at the next occurrence) or `--at "yyyy-MM-dd HH:mm"` for an exact date and time. Perfect for reminders, cron-like alerting, or time-sensitive workflows.

- **Delay delivery with `--delay`** — Need a notification to appear in a few seconds? The new `--delay` flag lets you defer delivery by a specified number of seconds — no external `sleep` command needed.

- **Persistent banner-style notifications** — Notifications now use the `alert` style by default, meaning they stay on screen until you interact with them. No more missing important alerts because a banner disappeared too quickly.

- **A proper app icon** — Alerter now ships with its own icon, giving your notifications a clean, recognizable look in Notification Center instead of a generic placeholder.

- **Available on MacPorts** — In addition to Homebrew, you can now install Alerter via MacPorts for seamless integration with your preferred package manager.

## Upgrading

Install or update via Homebrew:

```bash
brew upgrade vjeantet/tap/alerter
```

Or via MacPorts:

```bash
sudo port upgrade alerter
```

Enjoy the new scheduling superpowers!
