#import "BundleIdentifierHook.h"
#import <objc/runtime.h>

static NSString *_fakeBundleIdentifier = nil;

@implementation NSBundle (FakeBundleIdentifier)

- (NSString *)__bundleIdentifier {
    if (self == [NSBundle mainBundle]) {
        return _fakeBundleIdentifier ?: @"fr.vjeantet.alerter";
    } else {
        return [self __bundleIdentifier];
    }
}

@end

BOOL InstallFakeBundleIdentifierHook(NSString * _Nonnull fakeBundleID) {
    Class class = objc_getClass("NSBundle");
    if (class) {
        _fakeBundleIdentifier = [fakeBundleID copy];
        method_exchangeImplementations(
            class_getInstanceMethod(class, @selector(bundleIdentifier)),
            class_getInstanceMethod(class, @selector(__bundleIdentifier))
        );
        return YES;
    }
    return NO;
}
