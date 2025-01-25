#import "AppDelegate.h"
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>

NSString * const TerminalAlerterBundleID = @"fr.vjeantet.alerter";
NSString * const NotificationCenterUIBundleID = @"com.apple.notificationcenterui";

// Set OS Params
#define NSAppKitVersionNumber10_8 1187
#define NSAppKitVersionNumber10_9 1265

#define contains(str1, str2) ([str1 rangeOfString: str2 ].location != NSNotFound)

NSString *_fakeBundleIdentifier = nil;
UNNotificationRequest *currentNotification = nil ;

@implementation NSBundle (FakeBundleIdentifier)

// Overriding bundleIdentifier works, but overriding NSUserNotificationAlertStyle does not work.

- (NSString *)__bundleIdentifier;
{
    if (self == [NSBundle mainBundle]) {
        return _fakeBundleIdentifier ? _fakeBundleIdentifier : TerminalAlerterBundleID;
    } else {
        return [self __bundleIdentifier];
    }
}

@end

static BOOL
InstallFakeBundleIdentifierHook()
{
    Class class = objc_getClass("NSBundle");
    if (class) {
        method_exchangeImplementations(class_getInstanceMethod(class, @selector(bundleIdentifier)),
                                       class_getInstanceMethod(class, @selector(__bundleIdentifier)));
        return YES;
    }
    return NO;
}

static BOOL
isMavericks()
{
    if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_8) {
        /* On a 10.8 - 10.8.x system */
        return NO;
    } else {
        /* 10.9 or later system */
        return YES;
    }
}

// The objectForKeyedSubscript: method takes a key as its argument and returns the value associated with that key
// in the user defaults.
// If the value is a string and it starts with a backslash (\), it removes the backslash and returns the rest of the string.
// Otherwise, it returns the original value.
@implementation NSUserDefaults (SubscriptAndUnescape)
- (id)objectForKeyedSubscript:(id)key;
{
    id obj = [self objectForKey:key];
    if ([obj isKindOfClass:[NSString class]] && [(NSString *)obj hasPrefix:@"\\"]) {
        obj = [(NSString *)obj substringFromIndex:1];
    }
    return obj;
}
@end


@implementation AppDelegate


// initializes the user defaults with default values
// If the OS version is Mavericks (10.9), it sets the value of the "sender" key to "com.apple.Terminal".
//  Otherwise, if the OS version is Mountain Lion (10.8) or earlier, it sets the value of an empty key to "message".
+(void)initializeUserDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // initialize the dictionary with default values depending on OS level
    NSDictionary *appDefaults;
    
    if (isMavericks()) {
        //10.9
        appDefaults = @{@"sender": @"com.apple.Terminal"};
    } else {
        //10.8
        appDefaults = @{@"": @"message"};
    }
    
    // and set them appropriately
    [defaults registerDefaults:appDefaults];
}


// Display the default help message
- (void)printHelpBanner;
{
    const char *appName = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleExecutable"] UTF8String];
    const char *appVersion = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] UTF8String];
    printf("%s (%s) is a command-line tool to send OS X User Notifications.   \n" \
           "\n" \
           "Usage: %s -[message|list|remove] [VALUE|ID|ID] [options]\n" \
           "\n" \
           "   Either of these is required (unless message data is piped to the tool):\n" \
           "\n" \
           "       -help              Display this help banner.\n" \
           "       -message VALUE     The notification message.\n" \
           "       -remove ID         Removes a notification with the specified ‘group’ ID.\n" \
           "       -list ID           If the specified ‘group’ ID exists show when it was delivered,\n" \
           "                          or use ‘ALL’ as ID to see all notifications.\n" \
           "                          The output is a tab-separated list.\n"
           "\n" \
           "   Reply type notification:\n" \
           "\n" \
           "       -reply VALUE       The notification will be displayed as a reply type alert, VALUE used as placeholder.\n" \
           "\n" \
           "   Actions type notification:\n" \
           "\n" \
           "       -actions VALUE1,VALUE2.\n" \
           "                          The notification actions avalaible.\n" \
           "                          When you provide more than one value, a dropdown will be displayed.\n" \
           "                          You can customize this dropdown label with the next option.\n" \
           "       -dropdownLabel VALUE    The notification actions dropdown title (only when multiples actions are provided.\n" \
           "\n" \
           "   Optional:\n" \
           "\n" \
           "       -title VALUE       The notification title. Defaults to ‘Terminal’.\n" \
           "       -subtitle VALUE    The notification subtitle.\n" \
           "       -closeLabel VALUE  The notification close button label.\n" \
           "       -sound NAME        The name of a sound to play when the notification appears. The names are listed\n" \
           "                          in Sound Preferences. Use 'default' for the default notification sound.\n" \
           "       -group ID          A string which identifies the group the notifications belong to.\n" \
           "                          Old notifications with the same ID will be removed.\n" \
           "       -sender ID         The bundle identifier of the application that should be shown as the sender, including its icon.\n" \
           "       -appIcon URL       The URL of a image to display instead of the application icon (Mavericks+ only)\n" \
           "       -contentImage URL  The URL of a image to display attached to the notification (Mavericks+ only)\n" \
           "       -json       Write only event or value to stdout \n" \
           "       -timeout NUMBER    Close the notification after NUMBER seconds.\n" \
           "       -ignoreDnD         Send notification even if Do Not Disturb is enabled.\n" \
           "\n" \
           "When the user activates or close a notification, the results are logged to stdout as a json struct.\n" \
           "\n" \
           "Note that in some circumstances the first character of a message has to be escaped in order to be recognized.\n" \
           "An example of this is when using an open bracket, which has to be escaped like so: ‘\\[’.\n" \
           "\n" \
           "For more information see https://github.com/vjeantet/alerter.\n",
           appName, appVersion, appName);
}

// Called when the application finishes launching
// - Checks if the -help command line argument was provided and if so, exit printing the help banner.
// - Retrieves user input values subtitle, message, remove, list, and sound, use stdin when message is empty
// - check for mandatories fields, or exit printing the help banner
// - When list, call listNotificationWithGroupID and exit
// - Install a fake bundle identifier hook and sets the _fakeBundleIdentifier variable to the value of the sender key.
// - When remove value is set, call the removeNotificationWithGroupID: to remove a remaining notification
// - Deliver a notification to the user with given options
- (void)applicationDidFinishLaunching:(NSNotification *)notification;
{
    // Checks if the "-help" command line argument is present and prints a help banner if it is.
    if ([[[NSProcessInfo processInfo] arguments] indexOfObject:@"-help"] != NSNotFound) {
        [self printHelpBanner];
        exit(0);
    }
    
    // Checks if the Notification Center is running, and exits the application if it is not.
    NSArray *runningProcesses = [[[NSWorkspace sharedWorkspace] runningApplications] valueForKey:@"bundleIdentifier"];
    if ([runningProcesses indexOfObject:NotificationCenterUIBundleID] == NSNotFound) {
        NSLog(@"[!] Unable to post a notification for the current user (%@), as it has no running NotificationCenter instance.", NSUserName());
        exit(1);
    }
    
    // Prepare configurations values into the defaults map from given inputs
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *subtitle = defaults[@"subtitle"];
    NSString *message  = defaults[@"message"];
    NSString *remove   = defaults[@"remove"];
    NSString *list     = defaults[@"list"];
    NSString *sound    = defaults[@"sound"];

    
    // If the message is nil and standard input is being piped to the application,
    // read the piped data and set it as the message.
    if (message == nil && !isatty(STDIN_FILENO)) {
        NSData *inputData = [NSData dataWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile]];
        message = [[NSString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];
        if ([message length] == 0) {
            message = nil;
        }
    }

    // If no message or remove or list command found, print help message and exit.
    if (message == nil && remove == nil && list == nil) {
        [self printHelpBanner];
        exit(1);
    }
    
    
    if (list) {
        [self listNotificationWithGroupID:list];
        exit(0);
    }
    
    // Install the fake bundle ID hook so we can fake the sender. This also
    // needs to be done to be able to remove a message.
    if (defaults[@"sender"]) {
        @autoreleasepool {
            if (InstallFakeBundleIdentifierHook()) {
                _fakeBundleIdentifier = defaults[@"sender"];
            }
        }
    }
    
    if (remove) {
        [self removeNotificationWithGroupID:remove];
        if (message == nil) exit(0);
    }
    
    // deliver the notification if a message exists with the given options dictionary to customize it.
    // The dictionary values are set based on corresponding user defaults, and some keys are set
    // based on the command line arguments passed to the application.
    if (message) {
        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        if (defaults[@"closeLabel"])  options[@"closeLabel"]   = defaults[@"closeLabel"];
        if (defaults[@"dropdownLabel"])  options[@"dropdownLabel"]   = defaults[@"dropdownLabel"];
        
        if (defaults[@"actions"])options[@"actions"]   = defaults[@"actions"];
        if([[[NSProcessInfo processInfo] arguments] containsObject:@"-reply"] == true) {
            options[@"reply"] = @"Reply" ;
            if (defaults[@"reply"])  options[@"reply"]   = defaults[@"reply"];
        }
        
        options[@"output"] = @"outputEvent" ;
        if([[[NSProcessInfo processInfo] arguments] containsObject:@"-json"] == true) {
            options[@"output"] = @"json" ;
        }
        
        
        if (defaults[@"group"])    options[@"groupID"]          = defaults[@"group"];
        if (defaults[@"appIcon"])  options[@"appIcon"]          = defaults[@"appIcon"];
        if (defaults[@"contentImage"]) options[@"contentImage"] = defaults[@"contentImage"];
        
        options[@"timeout"] = @"0" ;
        if (defaults[@"timeout"])    options[@"timeout"]          = defaults[@"timeout"];
        
        options[@"uuid"] = [NSString stringWithFormat:@"%ld", self.hash] ;
        
        if([[[NSProcessInfo processInfo] arguments] containsObject:@"-ignoreDnD"] == true) {
          options[@"ignoreDnD"] = @YES;
        }
        
        [self deliverNotificationWithTitle:defaults[@"title"] ?: @"Terminal"
                                  subtitle:subtitle
                                   message:message
                                   options:options
                                     sound:sound];
    }
}

// This method takes a URL as an argument and returns an NSImage object with
// the content.
// If the URL has no scheme, the method assumes that it is a file URL and
// prefixes it with 'file://'.
- (NSImage*)getImageFromURL:(NSString *) url;
{
    NSURL *imageURL = [NSURL URLWithString:url];
    if([[imageURL scheme] length] == 0){
        // Prefix 'file://' if no scheme
        imageURL = [NSURL fileURLWithPath:url];
    }
    return [[NSImage alloc] initWithContentsOfURL:imageURL];
}



- (void)deliverNotificationWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                             message:(NSString *)message
                             options:(NSDictionary *)options
                               sound:(NSString *)sound;
{
    // First remove earlier notification with the same group ID.
    if (options[@"groupID"]) [self removeNotificationWithGroupID:options[@"groupID"]];
    
    UNMutableNotificationContent *content = [UNMutableNotificationContent new];
    content.title = title;
    content.subtitle = subtitle;
    content.body = message;
    content.userInfo = options;
    
    if (isMavericks()) {
        // Mavericks options
        if (options[@"appIcon"]) {
            // replacement app icon
            [content setValue:[self getImageFromURL:options[@"appIcon"]] forKey:@"_identityImage"];
            [content setValue:@(false) forKey:@"_identityImageHasBorder"];
        }
        if (options[@"contentImage"]) {
            // content image
            content.attachments = @[[UNNotificationAttachment attachmentWithIdentifier:@"contentImage" URL:[NSURL URLWithString:options[@"contentImage"]] options:nil error:nil]];
        }
    }
    
    // Actions
    if (options[@"actions"]) {
        NSMutableArray *actions = [NSMutableArray array];
        NSArray *myActions = [options[@"actions"] componentsSeparatedByString:@","];
        for (NSString *action in myActions) {
            [actions addObject:[UNNotificationAction actionWithIdentifier:action title:action options:UNNotificationActionOptionForeground]];
        }
        UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"actionsCategory" actions:actions intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
        [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithObject:category]];
        content.categoryIdentifier = @"actionsCategory";
    } else if (options[@"reply"]) {
        UNTextInputNotificationAction *replyAction = [UNTextInputNotificationAction actionWithIdentifier:@"reply" title:@"Reply" options:UNNotificationActionOptionForeground textInputButtonTitle:@"Send" textInputPlaceholder:options[@"reply"]];
        UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"replyCategory" actions:@[replyAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
        [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithObject:category]];
        content.categoryIdentifier = @"replyCategory";
    }
    
    // Close button
    if (options[@"closeLabel"]) {
        UNNotificationAction *closeAction = [UNNotificationAction actionWithIdentifier:@"close" title:options[@"closeLabel"] options:UNNotificationActionOptionDestructive];
        UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:@"closeCategory" actions:@[closeAction] intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
        [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:[NSSet setWithObject:category]];
        content.categoryIdentifier = @"closeCategory";
    }
    
    if (sound != nil) {
        content.sound = [sound isEqualToString:@"default"] ? [UNNotificationSound defaultSound] : [UNNotificationSound soundNamed:sound];
    }
    
    if (options[@"ignoreDnD"]) {
        [content setValue:@YES forKey:@"_ignoresDoNotDisturb"];
    }
    
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:options[@"uuid"] content:content trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
    currentNotification = request;
}



- (void)removeNotificationWithGroupID:(NSString *)groupID;
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        for (UNNotification *notification in notifications) {
            if ([@"ALL" isEqualToString:groupID] || [notification.request.content.userInfo[@"groupID"] isEqualToString:groupID]) {
                [center removeDeliveredNotificationsWithIdentifiers:@[notification.request.identifier]];
            }
        }
    }];
}


- (BOOL)userNotificationCenter:(UNUserNotificationCenter *)center
     shouldPresentNotification:(UNNotification *)notification;
{
    return YES;
}

// Once the notification is delivered we can exit. (Only if no actions or reply
// WORKS
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
        didDeliverNotification:(UNNotification *)notification;
{
    currentNotification = notification.request;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block BOOL notificationStillPresent;
        do {
            notificationStillPresent = NO;
            [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
                for (UNNotification *nox in notifications) {
                    if ([nox.request.identifier isEqualToString:[NSString stringWithFormat:@"%ld", self.hash]]) {
                        notificationStillPresent = YES;
                    }
                }
            }];
            if (notificationStillPresent) [NSThread sleepForTimeInterval:0.20f];
        } while (notificationStillPresent);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *udict = @{@"activationType" : @"closed", @"activationValue" : notification.request.content.userInfo[@"closeLabel"]};
            [self Quit:udict notification:notification] ;
            exit(0);
        });
    });
    
    if ([notification.request.content.userInfo[@"timeout"] integerValue] > 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [NSThread sleepForTimeInterval:[notification.request.content.userInfo[@"timeout"] integerValue]];
            [center removeDeliveredNotificationsWithIdentifiers:@[currentNotification.identifier]];
            NSDictionary *udict = @{@"activationType" : @"timeout"};
            [self Quit:udict notification:notification] ;
            exit(0);
        });
    }
}


- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       didActivateNotification:(UNNotification *)notification {

    if (![notification.request.identifier isEqualToString:[NSString stringWithFormat:@"%ld", self.hash]]) {
        return;
    };
    
    NSString *ActionsClicked = @"";
    switch (notification.request.content.categoryIdentifier) {
        case @"actionsCategory": {
            NSArray *actions = notification.request.content.userInfo[@"actions"];
            NSUInteger actionIndex = [actions indexOfObject:notification.request.identifier];
            ActionsClicked = actions[actionIndex];
            NSDictionary *udict = @{@"activationType" : @"actionClicked", @"activationValue" : ActionsClicked, @"activationValueIndex" : [NSString stringWithFormat:@"%lu", (unsigned long)actionIndex]};
            [self Quit:udict notification:notification];
            break;
        }
        case @"replyCategory": {
            NSString *response = notification.request.content.userInfo[@"reply"];
            NSDictionary *udict = @{@"activationType" : @"replied", @"activationValue" : response};
            [self Quit:udict notification:notification];
            break;
        }
        case @"closeCategory": {
            NSDictionary *udict = @{@"activationType" : @"closed", @"activationValue" : notification.request.content.userInfo[@"closeLabel"]};
            [self Quit:udict notification:notification];
            break;
        }
        default:
            [self Quit:@{@"activationType" : @"none"} notification:notification];
            break;
    }
    
    [center removeDeliveredNotificationsWithIdentifiers:@[notification.request.identifier]];
    exit(0);
}

- (BOOL)Quit:(NSDictionary *)udict notification:(UNNotification *)notification;
{
    if ([notification.request.content.userInfo[@"output"] isEqualToString:@"outputEvent"]) {
        if ([udict[@"activationType"] isEqualToString:@"closed"]) {
            if ([udict[@"activationValue"] isEqualToString:@""]) {
                printf("%s", "@CLOSED");
            } else {
                printf("%s", [udict[@"activationValue"] UTF8String]);
            }
        } else if ([udict[@"activationType"] isEqualToString:@"timeout"]) {
            printf("%s", "@TIMEOUT");
        } else if ([udict[@"activationType"] isEqualToString:@"contentsClicked"]) {
            printf("%s", "@CONTENTCLICKED");
        } else {
            if ([udict[@"activationValue"] isEqualToString:@""]) {
                printf("%s", "@ACTIONCLICKED");
            } else {
                printf("%s", [udict[@"activationValue"] UTF8String]);
            }
        }
        return 1;
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss Z";
    
    // Dictionary with several key/value pairs and the above array of arrays
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict addEntriesFromDictionary:udict];
    [dict setValue:[dateFormatter stringFromDate:notification.date] forKey:@"deliveredAt"];
    [dict setValue:[dateFormatter stringFromDate:[NSDate new]] forKey:@"activationAt"];
    
    NSError *error = nil;
    NSData *json;
    
    // Dictionary convertable to JSON?
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        // Serialize the dictionary
        json = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
        
        // If no errors, let's view the JSON
        if (json != nil && error == nil) {
            NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
            printf("%s", [jsonString cStringUsingEncoding:NSUTF8StringEncoding]);
        }
    }
    
    return 1;
}

// This method lists all notifications delivered to the Notification Center
// that belong to the specified groupID. If the groupID argument is set to "ALL",
// then all notifications are listed. The method iterates through all delivered
// notifications and builds an array of dictionaries, where each dictionary
// represents a single notification and contains information such as its groupID,
// title, subtitle, message, and delivery time. If any notifications are found,
// the information is serialized to JSON format and printed to the console.
- (void)listNotificationWithGroupID:(NSString *)listGroupID;
{
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    
    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        NSMutableArray *lines = [NSMutableArray array];
        for (UNNotification *notification in notifications) {
            NSString *deliveredgroupID = notification.request.content.userInfo[@"groupID"];
            NSString *title = notification.request.content.title;
            NSString *subtitle = notification.request.content.subtitle;
            NSString *message = notification.request.content.body;
            NSString *deliveredAt = [notification.date description];
            if ([@"ALL" isEqualToString:listGroupID] || [deliveredgroupID isEqualToString:listGroupID]) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                [dict setValue:deliveredgroupID forKey:@"GroupID"];
                [dict setValue:title forKey:@"Title"];
                [dict setValue:subtitle forKey:@"subtitle"];
                [dict setValue:message forKey:@"message"];
                [dict setValue:deliveredAt forKey:@"deliveredAt"];
                [lines addObject:dict];
            }
        }
        
        if (lines.count > 0) {
            NSData *json;
            NSError *error = nil;
            // Dictionary convertable to JSON?
            if ([NSJSONSerialization isValidJSONObject:lines]) {
                // Serialize the dictionary
                json = [NSJSONSerialization dataWithJSONObject:lines options:NSJSONWritingPrettyPrinted error:&error];
                
                // If no errors, let's view the JSON
                if (json != nil && error == nil) {
                    NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
                    printf("%s", [jsonString cStringUsingEncoding:NSUTF8StringEncoding]);
                }
            }
        }
    }];
}

// This method looks for a delivered notification with a UUID that matches the UUID of
// the current notification. When a matching notification is found, it is removed from
// the Notification Center using the removeDeliveredNotification method.
- (void)bye; {
    NSString *UUID = currentNotification.identifier;
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    [center getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        for (UNNotification *nox in notifications) {
            if ([nox.request.identifier isEqualToString:UUID]) {
                [center removeDeliveredNotificationsWithIdentifiers:@[nox.request.identifier]];
            }
        }
    }];
}

@end
