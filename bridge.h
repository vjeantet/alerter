// bridge.h
// CGo bridge header for UserNotifications framework
// Copyright (C) 2025 Valère Jeantet <valere.jeantet@gmail.com>
// All the works are available under the MIT license.

#ifndef BRIDGE_H
#define BRIDGE_H

#include <stdbool.h>

// Notification options structure passed from Go to Objective-C
typedef struct {
    const char* title;
    const char* subtitle;
    const char* message;
    const char* groupID;
    const char* actions;
    const char* reply;
    const char* dropdownLabel;
    const char* closeLabel;
    const char* appIcon;
    const char* contentImage;
    const char* sound;
    int timeout;
    bool ignoreDnD;
    bool jsonOutput;
} NotificationOptions;

// Initialize the notification system with a bundle identifier
bool InitNotificationSystem(const char* bundleID);

// Deliver a notification with the specified options
// Returns a string containing the result (event or JSON)
// Caller must free the returned string
char* DeliverNotification(NotificationOptions opts);

// List notifications for a group ID (use "ALL" for all notifications)
// Returns a JSON string with notification details
// Caller must free the returned string
char* ListNotifications(const char* groupID);

// Remove notifications for a group ID (use "ALL" for all notifications)
void RemoveNotifications(const char* groupID);

// Cleanup and remove current notification
void Cleanup(void);

#endif // BRIDGE_H
