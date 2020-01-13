# Alerter

<p align="center">
    <a href="LICENSE.md"><img src="https://badgen.net/github/license/vjeantet/alerter" /></a>
</p>

alerter is a command-line tool to send Mac OS X User Alerts (Notifications),
which are available in Mac OS X 10.8 and higher. (even catalina)
the program ends when the alerter is activated or closed, writing a the activated value to output (stdout), or a json object to describe the alert event.

Alerts are OS X notifications that stay on screen unless dismissed.

2 kinds of alert notification can be triggered : "Reply Alert" or "Actions Alert"

## Reply alert
Open a notification in the top-right corner of your screen and display a "Reply" button, which opens a text input.

## Actions alert
Open a notification in the top-right corner of your screen and display one or more actions to click on.

## Features
* set alert's icon, title, subtitle, image.
* capture text typed by user in the reply type alert.
* timeout : automatically close the alert notification after a delay.
* change the close button label.
* change the actions dropdown label.
* play a sound while delivering the alert notification.
* value or json output on alert's event (closed, timeout, replied, activated...)
* close the alert notification on SIGINT, SIGTERM.

## Installation

1. Download the zipped precompiled binary from the
[releases section](https://github.com/vjeantet/alerter/releases).
2. Extract the binary.
3. Use as described below.

### Adding to `$PATH`

If you don't want to have to specify the absolute/relative path to the binary, you can place the binary in any directory that is listed in your `$PATH` so that your system can automatically find it.

If you would like to see which directories are currently in your `$PATH`, you can run `echo $PATH`.

You can use the `cp` command to copy the binary to your chosen directory. For example:

```shell
cp ~/Downloads/alerter /path/to/directory/you/choose/
```

## Usage

```
$ ./alerter -[message|group|list] [VALUE|ID|ID] [options]
```

Some examples are:

Display piped data with a sound

```
$ echo 'Piped Message Data!' | alerter -sound default
```

![Display piped data with a sound](/img1.png?raw=true "")

Multiple actions and custom dropdown list
```
./alerter -message "Deploy now on UAT ?" -actions Now,"Later today","Tomorrow" -dropdownLabel "When ?"
```

![Multiple actions and custom dropdown list](/img2.png?raw=true "")

Yes or No ?
```
./alerter -title ProjectX -subtitle "new tag detected" -message "Deploy now on UAT ?" -closeLabel No -actions Yes -appIcon http://vjeantet.fr/images/logo.png
```

![Yes or No](/img3.png?raw=true "")

What is the name of this release ?
```
./alerter -reply -message "What is the name of this release ?" -title "Deploy in progress..."
```

![What is the name of this release](/img4.png?raw=true "")

## Options

At a minimum, you have to specify either the `-message` , the `-remove`
or the `-list` option.

-------------------------------------------------------------------------------

`-message VALUE`  **[required]**

The message body of the notification.

Note that if this option is omitted and data is piped to the application, that
data will be used instead.

-------------------------------------------------------------------------------

`-reply`

The notification will be displayed as a reply type alert.

-------------------------------------------------------------------------------

`-actions VALUE1,VALUE2,"VALUE 3"`

The notification actions available.
When you provide more than one value, a dropdown will be displayed.
You can customize this dropdown label with the next option.
Does not work when -reply is used.

-------------------------------------------------------------------------------

`-dropdownLabel VALUE`

The notification actions dropdown title (only when multiples -actions values are provided).
Does not work when -reply is used.

-------------------------------------------------------------------------------

`-closeLabel VALUE`

The notification "Close" button label.

-------------------------------------------------------------------------------

`-title VALUE`

The title of the notification. This defaults to ‘Terminal’.

-------------------------------------------------------------------------------

`-subtitle VALUE`

The subtitle of the notification.

-------------------------------------------------------------------------------

`-timeout NUMBER`

Auto close the alert notification after NUMBER seconds.

-------------------------------------------------------------------------------

`-sound NAME`

The name of a sound to play when the notification appears. The names are listed
in Sound Preferences. Use 'default' for the default notification sound.

-------------------------------------------------------------------------------

`-json`

Alerter will output a json struct to describe what happened to the alert.

-------------------------------------------------------------------------------

`-group ID`

Specifies the ‘group’ a notification belongs to. For any ‘group’ only _one_
notification will ever be shown, replacing previously posted notifications.

A notification can be explicitly removed with the `-remove` option, described
below.

Examples are:

* The sender’s name to scope the notifications by tool.
* The sender’s process ID to scope the notifications by a unique process.
* The current working directory to scope notifications by project.

-------------------------------------------------------------------------------

`-remove ID`  **[required]**

Removes a notification that was previously sent with the specified ‘group’ ID,
if one exists. If used with the special group "ALL", all message are removed.

-------------------------------------------------------------------------------

`-list ID` **[required]**

Lists details about the specified ‘group’ ID. If used with the special group
"ALL", details about all currently active  messages are displayed.

The output of this command is a json array of alert notifications.

-------------------------------------------------------------------------------

`-sender ID`

Specifying this will make it appear as if the notification was send by that
application instead, including using its icon.

Using this option fakes the sender application, so that the notification system
will launch that application when the notification is clicked. Because of this
it is important to note that you cannot combine this with options like
`-execute`, `-open`, and `-activate` which depend on the sender of the
notification to be ‘alerter’ to perform its work.

For information on the `ID` see the `-activate` option.

-------------------------------------------------------------------------------

`-appIcon PATH` **[10.9+ only]**

Specifies The PATH or URL of an image to display instead of the application icon.

**WARNING: This option is subject to change since it relies on a private method.**

-------------------------------------------------------------------------------

`-contentImage PATH` **[10.9+ only]**

Specifies The PATH or URL of an image to display attached inside the notification.

**WARNING: This option is subject to change since it relies on a private method.**

-------------------------------------------------------------------------------


## Example usage with shell script
```bash
ANSWER="$(./alerter -message 'Start now ?' -closeLabel No -actions YES,MAYBE,'one more action' -timeout 10)"
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

All the works are available under the MIT license.

Copyright (C) 2012-2020 Valère Jeantet <valere.jeantet@gmail.com>, Eloy Durán <eloy.de.enige@gmail.com>, Julien Blanchard
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
