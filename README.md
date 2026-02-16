# Alerter
<p align="center">
    <a href="LICENSE.md"><img src="https://badgen.net/github/license/vjeantet/alerter"/></a>
</p>

Alerter is a command-line tool for sending macOS notifications (alerts), built with Swift and Swift Package Manager.
The program exits when the user interacts with the alert or when it is dismissed, printing the result to stdout as plain text or JSON.

Alerts are macOS notifications that stay on screen until dismissed. Requires macOS 13.0 or later.

Two kinds of alerts can be triggered: **Reply Alert** and **Actions Alert**.

## Reply alert
Displays a notification with a "Reply" button that opens a text input field.

## Actions alert
Displays a notification with one or more action buttons to click on.

## Features
* Set the alert icon, title, subtitle, and image.
* Capture text typed by the user in reply-type alerts.
* Timeout: automatically close the alert after a delay.
* Customize the close button label.
* Customize the actions dropdown label.
* Play a sound when delivering the notification.
* Plain text or JSON output for alert events (closed, timeout, replied, activated, etc.).
* Ignore Do Not Disturb mode.
* Gracefully close the notification on SIGINT and SIGTERM.

## Installation

### Homebrew (recommended)

```bash
brew install vjeantet/tap/alerter
```

### Manual

1. Download the zipped precompiled binary from the
[releases section](https://github.com/vjeantet/alerter/releases).
2. Extract the binary.
3. Place it in a directory listed in your `$PATH` (e.g. `/usr/local/bin`).

### Build from source

```bash
git clone https://github.com/vjeantet/alerter.git
cd alerter
swift build -c release
# Binary is at .build/release/alerter
```

## Release workflow

Versioning uses the format `YY.N` (e.g. `26.1`, `26.2`). The version is bumped automatically.

```
1. ./scripts/release.sh                    # bump version, build, sign, notarize, tag, GitHub Release
2. ./scripts/update-homebrew-formula.sh     # update formula in vjeantet/homebrew-tap
```

## Usage

```
$ ./alerter --message|--group|--list [VALUE|ID|ID] [options]
```

Examples:

Display piped data with a sound

```
$ echo 'Piped Message Data!' | alerter --sound default
```

![Display piped data with a sound](/img1.png?raw=true "")

Multiple actions and custom dropdown list
```
./alerter --message "Deploy now on UAT ?" --actions "Now,Later today,Tomorrow" --dropdownLabel "When ?"
```

![Multiple actions and custom dropdown list](/img2.png?raw=true "")

Yes or No?
```
./alerter --title ProjectX --subtitle "new tag detected" --message "Deploy now on UAT ?" --closeLabel No --actions Yes --appIcon http://vjeantet.fr/images/logo.png
```

![Yes or No](/img3.png?raw=true "")

What is the name of this release?
```
./alerter --reply "Type release name" --message "What is the name of this release?" --title "Deploy in progress..."
```

![What is the name of this release](/img4.png?raw=true "")

## Options

At a minimum, you must specify either `--message`, `--remove`, or `--list`.

-------------------------------------------------------------------------------

`--message VALUE`  **[required]**

The message body of the notification.

Note that if this option is omitted and data is piped to the application, that
data will be used instead.

-------------------------------------------------------------------------------

`--reply TEXT`

Displays the notification as a reply-type alert. TEXT is used as placeholder text in the input field.

-------------------------------------------------------------------------------

`--actions VALUE1,VALUE2,"VALUE 3"`

The available notification actions.
When more than one value is provided, a dropdown is displayed.
You can customize the dropdown label with the `--dropdownLabel` option.
Cannot be combined with `--reply`.

-------------------------------------------------------------------------------

`--dropdownLabel VALUE`

The label for the actions dropdown (only used when multiple `--actions` values are provided).
Cannot be combined with `--reply`.

-------------------------------------------------------------------------------

`--closeLabel VALUE`

A custom label for the notification's "Close" button.

-------------------------------------------------------------------------------

`--title VALUE`

The title of the notification. Defaults to 'Terminal'.

-------------------------------------------------------------------------------

`--subtitle VALUE`

The subtitle of the notification.

-------------------------------------------------------------------------------

`--timeout NUMBER`

Automatically close the notification after NUMBER seconds. Defaults to 0 (no timeout).

-------------------------------------------------------------------------------

`--sound NAME`

The name of a sound to play when the notification appears. The names are listed
in Sound Preferences. Use 'default' for the default notification sound.

-------------------------------------------------------------------------------

`--json`

Output the result as a JSON object describing the alert event.

-------------------------------------------------------------------------------

`--group ID`

Specifies the 'group' a notification belongs to. For any 'group' only _one_
notification will ever be shown, replacing previously posted notifications.

A notification can be explicitly removed with the `--remove` option, described
below.

Examples:

* The sender's name, to scope notifications by tool.
* The sender's process ID, to scope notifications by process.
* The current working directory, to scope notifications by project.

-------------------------------------------------------------------------------

`--remove ID`  **[required]**

Removes a previously sent notification with the specified 'group' ID,
if one exists. Use the special group "ALL" to remove all notifications.

-------------------------------------------------------------------------------

`--list ID` **[required]**

Lists details about the specified 'group' ID. Use the special group
"ALL" to list all currently active notifications.

Output is a JSON array of notifications.

-------------------------------------------------------------------------------

`--sender ID`

Makes the notification appear as if it was sent by the specified application,
including using its icon. Defaults to `fr.vjeantet.alerter`.

When this option is used, clicking the notification will launch the impersonated
application instead of alerter.

-------------------------------------------------------------------------------

`--appIcon PATH`

The path or URL of an image to display instead of the application icon.

**WARNING: This option relies on a private API and may break in future macOS releases.**

-------------------------------------------------------------------------------

`--contentImage PATH`

The path or URL of an image to display inside the notification.

**WARNING: This option relies on a private API and may break in future macOS releases.**

-------------------------------------------------------------------------------

`--ignoreDnd`

Sends the notification even if Do Not Disturb is enabled.

**WARNING: This option relies on a private API and may break in future macOS releases.**

-------------------------------------------------------------------------------


## Shell script example
```bash
ANSWER="$(./alerter --message 'Start now ?' --closeLabel No --actions 'YES,MAYBE,one more action' --timeout 10)"
case $ANSWER in
    "@TIMEOUT") echo "Timeout man, sorry" ;;
    "@CLOSED") echo "You clicked on the default alert' close button" ;;
    "@CONTENTCLICKED") echo "You clicked the alert's content !" ;;
    "@ACTIONCLICKED") echo "You clicked the alert default action button" ;;
    "MAYBE") echo "Action MAYBE" ;;
    "NO") echo "Action NO" ;;
    "YES") echo "Action YES" ;;
    **) echo "? --> $ANSWER" ;;
esac
```

## Support & Contributors

### Code Contributors

This project exists thanks to all the people who contribute. [[Contribute](CONTRIBUTING.md)].

This project is based on a fork of [terminal notifier](https://github.com/julienXX/terminal-notifier) by [@JulienXX](https://github.com/julienXX).

## License

All work is available under the MIT license.

Copyright (C) 2012-2026 Valère Jeantet <valere.jeantet@gmail.com>, Eloy Durán <eloy.de.enige@gmail.com>, Julien Blanchard
<julien@sideburns.eu>

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
