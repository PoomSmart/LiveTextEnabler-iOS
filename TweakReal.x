#import <MobileGestalt/MobileGestalt.h>
#import "../PSHeader/Misc.h"

%hook VKImageAnalyzer

+ (BOOL)deviceSupportsImageAnalysis {
    return YES;
}

%end

%group Preferences

BOOL override = NO;

%hookf(bool, MGGetBoolAnswer, CFStringRef question) {
    return override && CFStringEqual(question, CFSTR("+N9mZUAHooNvMiQnjeTJ8g")) ? true : %orig;
}

%hook InternationalSettingsController

- (id)specifiers {
    override = YES;
    id r = %orig;
    override = NO;
    return r;
}

%end

char *bundleLoadedObserver = "LTE";
void InternationalSettingsBundleLoadedNotificationFired(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (objc_getClass("InternationalSettingsController") == nil)
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(Preferences);
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetLocalCenter(), bundleLoadedObserver, (__bridge CFStringRef)NSBundleDidLoadNotification, NULL);
    });
}

%end

%ctor {
    %init;
    if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return;
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetLocalCenter(),
            bundleLoadedObserver,
            InternationalSettingsBundleLoadedNotificationFired,
            (__bridge CFStringRef)NSBundleDidLoadNotification,
            (__bridge CFBundleRef)[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/InternationalSettings.bundle"],
            CFNotificationSuspensionBehaviorCoalesce);
    }
}