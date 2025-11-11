// Alerter - macOS User Notifications for the command line
// Copyright (C) 2025 Valère Jeantet <valere.jeantet@gmail.com>
// All the works are available under the MIT license.

package main

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation -framework UserNotifications -framework Cocoa
#include "bridge.h"
#include <stdlib.h>
*/
import "C"
import (
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"unsafe"
)

const version = "2.0.0"

var (
	// Required options
	message = flag.String("message", "", "The notification message body")
	remove  = flag.String("remove", "", "Remove notification with the specified group ID")
	list    = flag.String("list", "", "List notifications for the specified group ID (use 'ALL' for all)")

	// Notification content
	title    = flag.String("title", "Terminal", "The notification title")
	subtitle = flag.String("subtitle", "", "The notification subtitle")

	// Reply type notification
	reply = flag.String("reply", "", "Display as reply type alert with this placeholder text")

	// Actions type notification
	actions       = flag.String("actions", "", "Comma-separated list of action button titles")
	dropdownLabel = flag.String("dropdownLabel", "", "Label for actions dropdown (when multiple actions)")
	closeLabel    = flag.String("closeLabel", "", "Label for the close button")

	// Visual options
	appIcon      = flag.String("appIcon", "", "URL or path to app icon image (macOS 10.14+)")
	contentImage = flag.String("contentImage", "", "URL or path to content image (macOS 10.14+)")

	// Behavior options
	sound     = flag.String("sound", "", "Sound name to play (use 'default' for system sound)")
	timeout   = flag.Int("timeout", 0, "Auto-close notification after N seconds")
	group     = flag.String("group", "", "Group ID for notification management")
	sender    = flag.String("sender", "com.apple.Terminal", "Bundle identifier of sender app")
	ignoreDnD = flag.Bool("ignoreDnD", false, "Send notification even if Do Not Disturb is enabled")

	// Output options
	jsonOutput = flag.Bool("json", false, "Output result as JSON instead of simple event string")

	// Help
	help = flag.Bool("help", false, "Display this help message")
)

func printHelp() {
	fmt.Printf(`alerter (%s) - macOS User Notifications for the command line

Usage: alerter -[message|list|remove] [VALUE|ID|ID] [options]

Required (one of):
  -help              Display this help message
  -message VALUE     The notification message body (or pipe data to stdin)
  -remove ID         Remove notification with the specified group ID
  -list ID           List notifications for group ID (use 'ALL' for all)

Notification Content:
  -title VALUE       Notification title (default: "Terminal")
  -subtitle VALUE    Notification subtitle

Reply Type Notification:
  -reply VALUE       Display as reply type alert, VALUE is placeholder text

Actions Type Notification:
  -actions VALUE1,VALUE2,...
                     Comma-separated action button titles
                     Multiple values create a dropdown menu
  -dropdownLabel VALUE
                     Label for actions dropdown (when multiple actions)
  -closeLabel VALUE  Label for the close button

Visual Options:
  -appIcon URL       URL or path to app icon image
  -contentImage URL  URL or path to content image

Behavior Options:
  -sound NAME        Sound name (use 'default' for system sound)
  -timeout NUMBER    Auto-close notification after NUMBER seconds
  -group ID          Group ID for notification management
  -sender ID         Bundle identifier of sender app
  -ignoreDnD         Send notification even if Do Not Disturb is enabled

Output Options:
  -json              Output result as JSON struct

Event Outputs (non-JSON mode):
  @TIMEOUT           Notification timed out
  @CLOSED            Notification closed by user
  @CONTENTCLICKED    Notification content clicked
  @ACTIONCLICKED     Default action clicked
  <action-value>     Specific action button clicked

Examples:
  # Simple notification
  alerter -message "Hello, World!"

  # With piped input
  echo "Build complete" | alerter -sound default

  # Multiple actions
  alerter -message "Deploy now?" -actions "Yes,No,Later" -title "Deployment"

  # Reply type
  alerter -reply -message "Enter release name:" -title "Release"

For more information: https://github.com/vjeantet/alerter
`, version)
}

func main() {
	flag.Parse()

	if *help {
		printHelp()
		os.Exit(0)
	}

	// Initialize the notification system
	if !initNotificationSystem() {
		fmt.Fprintln(os.Stderr, "[!] Unable to initialize notification system")
		fmt.Fprintln(os.Stderr, "[!] Make sure NotificationCenter is running")
		os.Exit(1)
	}

	// Handle list command
	if *list != "" {
		handleList(*list)
		os.Exit(0)
	}

	// Handle remove command
	if *remove != "" {
		handleRemove(*remove)
		if *message == "" {
			os.Exit(0)
		}
	}

	// Read from stdin if no message provided
	msg := *message
	if msg == "" {
		// Check if stdin is being piped
		stat, _ := os.Stdin.Stat()
		if (stat.Mode() & os.ModeCharDevice) == 0 {
			data, err := io.ReadAll(os.Stdin)
			if err == nil && len(data) > 0 {
				msg = strings.TrimSpace(string(data))
			}
		}
	}

	// Validate that we have something to do
	if msg == "" {
		printHelp()
		os.Exit(1)
	}

	// Set up signal handling for graceful shutdown
	setupSignalHandlers()

	// Deliver the notification
	handleNotification(msg)
}

func initNotificationSystem() bool {
	cSender := C.CString(*sender)
	defer C.free(unsafe.Pointer(cSender))

	result := C.InitNotificationSystem(cSender)
	return bool(result)
}

func handleList(groupID string) {
	cGroupID := C.CString(groupID)
	defer C.free(unsafe.Pointer(cGroupID))

	cResult := C.ListNotifications(cGroupID)
	defer C.free(unsafe.Pointer(cResult))

	result := C.GoString(cResult)
	if result != "" {
		fmt.Print(result)
	}
}

func handleRemove(groupID string) {
	cGroupID := C.CString(groupID)
	defer C.free(unsafe.Pointer(cGroupID))

	C.RemoveNotifications(cGroupID)
}

func handleNotification(msg string) {
	// Build notification options
	opts := C.NotificationOptions{}

	// Basic content
	opts.title = C.CString(*title)
	defer C.free(unsafe.Pointer(opts.title))

	opts.subtitle = C.CString(*subtitle)
	defer C.free(unsafe.Pointer(opts.subtitle))

	opts.message = C.CString(msg)
	defer C.free(unsafe.Pointer(opts.message))

	// Group ID
	opts.groupID = C.CString(*group)
	defer C.free(unsafe.Pointer(opts.groupID))

	// Actions or Reply
	opts.actions = C.CString(*actions)
	defer C.free(unsafe.Pointer(opts.actions))

	opts.reply = C.CString(*reply)
	defer C.free(unsafe.Pointer(opts.reply))

	opts.dropdownLabel = C.CString(*dropdownLabel)
	defer C.free(unsafe.Pointer(opts.dropdownLabel))

	opts.closeLabel = C.CString(*closeLabel)
	defer C.free(unsafe.Pointer(opts.closeLabel))

	// Visual options
	opts.appIcon = C.CString(*appIcon)
	defer C.free(unsafe.Pointer(opts.appIcon))

	opts.contentImage = C.CString(*contentImage)
	defer C.free(unsafe.Pointer(opts.contentImage))

	// Sound
	opts.sound = C.CString(*sound)
	defer C.free(unsafe.Pointer(opts.sound))

	// Behavior
	opts.timeout = C.int(*timeout)
	opts.ignoreDnD = C.bool(*ignoreDnD)
	opts.jsonOutput = C.bool(*jsonOutput)

	// Deliver the notification and wait for response
	cResult := C.DeliverNotification(opts)
	defer C.free(unsafe.Pointer(cResult))

	result := C.GoString(cResult)
	if result != "" {
		fmt.Print(result)
	}
}

func setupSignalHandlers() {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		<-sigChan
		C.Cleanup()
		os.Exit(1)
	}()
}
