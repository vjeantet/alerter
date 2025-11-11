// bridge.m
// CGo bridge implementation using UserNotifications framework
// Copyright (C) 2025 Valère Jeantet <valere.jeantet@gmail.com>
// All the works are available under the MIT license.

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>
#import <Cocoa/Cocoa.h>
#import "bridge.h"

// Global variables
static NSString *currentBundleID = nil;
static NSString *currentNotificationID = nil;
static dispatch_semaphore_t notificationSemaphore = nil;
static NSString *notificationResult = nil;
static BOOL isJSONOutput = NO;

// Notification delegate
@interface NotificationDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation NotificationDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    // Show notification even when app is in foreground
    if (@available(macOS 11.0, *)) {
        completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
    } else {
        completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler {

    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSString *notifID = userInfo[@"notificationID"];

    // Only handle our notification
    if (![notifID isEqualToString:currentNotificationID]) {
        completionHandler();
        return;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";

    NSDate *deliveredDate = response.notification.date;
    result[@"deliveredAt"] = [dateFormatter stringFromDate:deliveredDate];
    result[@"activationAt"] = [dateFormatter stringFromDate:[NSDate date]];

    if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
        // User dismissed the notification
        result[@"activationType"] = @"closed";
        NSString *closeLabel = userInfo[@"closeLabel"];
        if (closeLabel && ![closeLabel isEqualToString:@""]) {
            result[@"activationValue"] = closeLabel;
        }
    } else if ([response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        // User clicked the notification body
        result[@"activationType"] = @"contentsClicked";
    } else if ([response isKindOfClass:[UNTextInputNotificationResponse class]]) {
        // User replied with text
        UNTextInputNotificationResponse *textResponse = (UNTextInputNotificationResponse *)response;
        result[@"activationType"] = @"replied";
        result[@"activationValue"] = textResponse.userText;
    } else {
        // User clicked an action button
        result[@"activationType"] = @"actionClicked";
        result[@"activationValue"] = response.actionIdentifier;

        // Find the action index
        NSArray *actionTitles = userInfo[@"actionTitles"];
        if (actionTitles) {
            NSUInteger index = [actionTitles indexOfObject:response.actionIdentifier];
            if (index != NSNotFound) {
                result[@"activationValueIndex"] = [NSString stringWithFormat:@"%lu", (unsigned long)index];
            }
        }
    }

    // Store result
    if (isJSONOutput) {
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
        if (jsonData) {
            notificationResult = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        }
    } else {
        // Simple event string output
        NSString *activationType = result[@"activationType"];
        if ([activationType isEqualToString:@"closed"]) {
            NSString *value = result[@"activationValue"];
            notificationResult = value && ![value isEqualToString:@""] ? value : @"@CLOSED";
        } else if ([activationType isEqualToString:@"contentsClicked"]) {
            notificationResult = @"@CONTENTCLICKED";
        } else if ([activationType isEqualToString:@"replied"]) {
            notificationResult = result[@"activationValue"] ?: @"";
        } else if ([activationType isEqualToString:@"actionClicked"]) {
            NSString *value = result[@"activationValue"];
            notificationResult = value && ![value isEqualToString:@""] ? value : @"@ACTIONCLICKED";
        }
    }

    // Signal completion
    if (notificationSemaphore) {
        dispatch_semaphore_signal(notificationSemaphore);
    }

    completionHandler();
}

@end

static NotificationDelegate *notificationDelegate = nil;

bool InitNotificationSystem(const char* bundleID) {
    @autoreleasepool {
        if (bundleID) {
            currentBundleID = [NSString stringWithUTF8String:bundleID];
        }

        // Check if Notification Center is running
        NSArray *runningProcesses = [[[NSWorkspace sharedWorkspace] runningApplications] valueForKey:@"bundleIdentifier"];
        if (![runningProcesses containsObject:@"com.apple.notificationcenterui"]) {
            return false;
        }

        // Set up notification delegate
        if (!notificationDelegate) {
            notificationDelegate = [[NotificationDelegate alloc] init];
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            center.delegate = notificationDelegate;
        }

        return true;
    }
}

char* DeliverNotification(NotificationOptions opts) {
    @autoreleasepool {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

        isJSONOutput = opts.jsonOutput;
        notificationResult = nil;
        currentNotificationID = [[NSUUID UUID] UUIDString];

        // Create semaphore for waiting
        notificationSemaphore = dispatch_semaphore_create(0);

        // Remove old notification with same group ID if specified
        NSString *groupID = opts.groupID ? [NSString stringWithUTF8String:opts.groupID] : nil;
        if (groupID && ![groupID isEqualToString:@""]) {
            RemoveNotifications(opts.groupID);
        }

        // Request authorization (this will be cached after first request)
        __block BOOL authGranted = NO;
        dispatch_semaphore_t authSemaphore = dispatch_semaphore_create(0);

        UNAuthorizationOptions authOptions = UNAuthorizationOptionAlert | UNAuthorizationOptionSound;
        [center requestAuthorizationWithOptions:authOptions
                              completionHandler:^(BOOL granted, NSError *error) {
            authGranted = granted;
            dispatch_semaphore_signal(authSemaphore);
        }];

        dispatch_semaphore_wait(authSemaphore, DISPATCH_TIME_FOREVER);

        if (!authGranted) {
            return strdup("ERROR: Notification authorization denied");
        }

        // Create notification content
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        content.title = opts.title ? [NSString stringWithUTF8String:opts.title] : @"Terminal";

        if (opts.subtitle && strlen(opts.subtitle) > 0) {
            content.subtitle = [NSString stringWithUTF8String:opts.subtitle];
        }

        content.body = opts.message ? [NSString stringWithUTF8String:opts.message] : @"";

        // Sound
        if (opts.sound && strlen(opts.sound) > 0) {
            NSString *soundName = [NSString stringWithUTF8String:opts.sound];
            if ([soundName isEqualToString:@"default"]) {
                content.sound = [UNNotificationSound defaultSound];
            } else {
                content.sound = [UNNotificationSound soundNamed:soundName];
            }
        }

        // User info for tracking
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
        userInfo[@"notificationID"] = currentNotificationID;
        if (groupID) userInfo[@"groupID"] = groupID;
        if (opts.closeLabel && strlen(opts.closeLabel) > 0) {
            userInfo[@"closeLabel"] = [NSString stringWithUTF8String:opts.closeLabel];
        }

        // Handle actions or reply
        NSString *actionsStr = opts.actions && strlen(opts.actions) > 0 ? [NSString stringWithUTF8String:opts.actions] : nil;
        NSString *replyStr = opts.reply && strlen(opts.reply) > 0 ? [NSString stringWithUTF8String:opts.reply] : nil;

        NSMutableArray *categories = [NSMutableArray array];
        NSString *categoryID = @"ALERTER_CATEGORY";

        if (replyStr) {
            // Reply type notification
            UNTextInputNotificationAction *replyAction = [UNTextInputNotificationAction
                actionWithIdentifier:@"REPLY_ACTION"
                title:@"Reply"
                options:UNNotificationActionOptionNone
                textInputButtonTitle:@"Send"
                textInputPlaceholder:replyStr];

            NSArray *actions = @[replyAction];
            UNNotificationCategory *category = [UNNotificationCategory
                categoryWithIdentifier:categoryID
                actions:actions
                intentIdentifiers:@[]
                options:UNNotificationCategoryOptionNone];

            [categories addObject:category];
            content.categoryIdentifier = categoryID;

        } else if (actionsStr) {
            // Action buttons
            NSArray *actionTitles = [actionsStr componentsSeparatedByString:@","];
            NSMutableArray *actions = [NSMutableArray array];

            for (NSString *actionTitle in actionTitles) {
                NSString *trimmedTitle = [actionTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                UNNotificationAction *action = [UNNotificationAction
                    actionWithIdentifier:trimmedTitle
                    title:trimmedTitle
                    options:UNNotificationActionOptionNone];
                [actions addObject:action];
            }

            userInfo[@"actionTitles"] = actionTitles;

            UNNotificationCategory *category = [UNNotificationCategory
                categoryWithIdentifier:categoryID
                actions:actions
                intentIdentifiers:@[]
                options:UNNotificationCategoryOptionNone];

            [categories addObject:category];
            content.categoryIdentifier = categoryID;
        }

        if (categories.count > 0) {
            [center setNotificationCategories:[NSSet setWithArray:categories]];
        }

        // Images (using attachments for UserNotifications)
        if (opts.contentImage && strlen(opts.contentImage) > 0) {
            NSString *imagePath = [NSString stringWithUTF8String:opts.contentImage];
            NSURL *imageURL = nil;

            if ([imagePath hasPrefix:@"http://"] || [imagePath hasPrefix:@"https://"]) {
                imageURL = [NSURL URLWithString:imagePath];
            } else {
                imageURL = [NSURL fileURLWithPath:imagePath];
            }

            if (imageURL) {
                NSError *error = nil;
                UNNotificationAttachment *attachment = [UNNotificationAttachment
                    attachmentWithIdentifier:@"image"
                    URL:imageURL
                    options:nil
                    error:&error];

                if (attachment) {
                    content.attachments = @[attachment];
                }
            }
        }

        content.userInfo = userInfo;

        // Create notification request
        UNNotificationRequest *request = [UNNotificationRequest
            requestWithIdentifier:currentNotificationID
            content:content
            trigger:nil]; // nil trigger means deliver immediately

        // Add the notification
        __block NSError *addError = nil;
        dispatch_semaphore_t addSemaphore = dispatch_semaphore_create(0);

        [center addNotificationRequest:request withCompletionHandler:^(NSError *error) {
            addError = error;
            dispatch_semaphore_signal(addSemaphore);
        }];

        dispatch_semaphore_wait(addSemaphore, DISPATCH_TIME_FOREVER);

        if (addError) {
            char *errorMsg = strdup([[NSString stringWithFormat:@"ERROR: %@", addError.localizedDescription] UTF8String]);
            return errorMsg;
        }

        // Handle timeout if specified
        if (opts.timeout > 0) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(opts.timeout * NSEC_PER_SEC));
                long result = dispatch_semaphore_wait(notificationSemaphore, timeout);

                if (result != 0) {
                    // Timeout occurred
                    [center removeDeliveredNotificationsWithIdentifiers:@[currentNotificationID]];

                    if (opts.jsonOutput) {
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";

                        NSDictionary *timeoutResult = @{
                            @"activationType": @"timeout",
                            @"activationAt": [dateFormatter stringFromDate:[NSDate date]]
                        };

                        NSError *error = nil;
                        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:timeoutResult options:NSJSONWritingPrettyPrinted error:&error];
                        if (jsonData) {
                            notificationResult = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                        }
                    } else {
                        notificationResult = @"@TIMEOUT";
                    }

                    dispatch_semaphore_signal(notificationSemaphore);
                }
            });
        }

        // Wait for user interaction or timeout
        dispatch_semaphore_wait(notificationSemaphore, DISPATCH_TIME_FOREVER);

        // Clean up
        [center removeDeliveredNotificationsWithIdentifiers:@[currentNotificationID]];

        // Return result
        if (notificationResult) {
            return strdup([notificationResult UTF8String]);
        }

        return strdup("");
    }
}

char* ListNotifications(const char* groupID) {
    @autoreleasepool {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

        __block NSArray *deliveredNotifications = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> *notifications) {
            deliveredNotifications = notifications;
            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        NSString *targetGroupID = groupID ? [NSString stringWithUTF8String:groupID] : nil;
        NSMutableArray *results = [NSMutableArray array];

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";

        for (UNNotification *notification in deliveredNotifications) {
            NSDictionary *userInfo = notification.request.content.userInfo;
            NSString *notifGroupID = userInfo[@"groupID"];

            if ([targetGroupID isEqualToString:@"ALL"] || [notifGroupID isEqualToString:targetGroupID]) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                dict[@"GroupID"] = notifGroupID ?: @"";
                dict[@"Title"] = notification.request.content.title ?: @"";
                dict[@"subtitle"] = notification.request.content.subtitle ?: @"";
                dict[@"message"] = notification.request.content.body ?: @"";
                dict[@"deliveredAt"] = [dateFormatter stringFromDate:notification.date];

                [results addObject:dict];
            }
        }

        if (results.count > 0) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:&error];
            if (jsonData) {
                NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                return strdup([jsonString UTF8String]);
            }
        }

        return strdup("");
    }
}

void RemoveNotifications(const char* groupID) {
    @autoreleasepool {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

        __block NSArray *deliveredNotifications = nil;
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

        [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> *notifications) {
            deliveredNotifications = notifications;
            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

        NSString *targetGroupID = groupID ? [NSString stringWithUTF8String:groupID] : nil;
        NSMutableArray *idsToRemove = [NSMutableArray array];

        for (UNNotification *notification in deliveredNotifications) {
            NSDictionary *userInfo = notification.request.content.userInfo;
            NSString *notifGroupID = userInfo[@"groupID"];

            if ([targetGroupID isEqualToString:@"ALL"] || [notifGroupID isEqualToString:targetGroupID]) {
                [idsToRemove addObject:notification.request.identifier];
            }
        }

        if (idsToRemove.count > 0) {
            [center removeDeliveredNotificationsWithIdentifiers:idsToRemove];
        }
    }
}

void Cleanup(void) {
    @autoreleasepool {
        if (currentNotificationID) {
            UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
            [center removeDeliveredNotificationsWithIdentifiers:@[currentNotificationID]];
        }
    }
}
