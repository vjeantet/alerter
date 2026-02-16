#import <Foundation/Foundation.h>

/// Installs a method swizzle on NSBundle so that the main bundle's
/// bundleIdentifier returns the given fake identifier.
/// Returns YES on success.
BOOL InstallFakeBundleIdentifierHook(NSString * _Nonnull fakeBundleID);
