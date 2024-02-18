#import <MobileGestalt/MobileGestalt.h>
#import <PSHeader/Misc.h>
#import <substrate.h>
#import <dlfcn.h>

%hook PXVisualIntelligenceManager

+ (BOOL)isVisualSearchSupported {
    return YES;
}

%end

%group Camera

%hook CAMCaptureCapabilities

- (BOOL)isImageAnalysisSupported {
    return YES;
}

%end

%end

extern void CameraHook() {
    %init(Camera);
}

%group VisionKitCore

MSImageRef vkRef;
void (*vk_deviceSupportsImageAnalysis_block_invoke)(void) = NULL;

%hookf(void, vk_deviceSupportsImageAnalysis_block_invoke) {
    %orig;
    bool *supportsWithOverride = (bool *)_PSFindSymbolReadable(vkRef, "_vk_deviceSupportsImageAnalysis._supportsWithOverride");
    *supportsWithOverride = true;
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
void CameraSettingsBundleLoadedNotificationFired(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (objc_getClass("CameraSettingsController") == nil)
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CameraHook();
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetLocalCenter(), bundleLoadedObserver, (__bridge CFStringRef)NSBundleDidLoadNotification, NULL);
    });
}

%end

%ctor {
    %init;
    NSString *processName = [[NSProcessInfo processInfo] processName];
    if ([processName isEqualToString:@"Camera"]) {
        CameraHook();
    }
    const char *vkPath = "/System/Library/PrivateFrameworks/VisionKitCore.framework/VisionKitCore";
    dlopen(vkPath, RTLD_LAZY);
    vkRef = MSGetImageByName(vkPath);
    vk_deviceSupportsImageAnalysis_block_invoke = (void (*)(void))MSFindSymbol(vkRef, "___vk_deviceSupportsImageAnalysis_block_invoke");
    if (vk_deviceSupportsImageAnalysis_block_invoke) {
        %init(VisionKitCore);
    }
    if (![[NSBundle mainBundle].bundleIdentifier isEqualToString:@"com.apple.Preferences"]) return;
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetLocalCenter(),
            bundleLoadedObserver,
            InternationalSettingsBundleLoadedNotificationFired,
            (__bridge CFStringRef)NSBundleDidLoadNotification,
            (__bridge CFBundleRef)[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/InternationalSettings.bundle"],
            CFNotificationSuspensionBehaviorCoalesce);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetLocalCenter(),
            bundleLoadedObserver,
            CameraSettingsBundleLoadedNotificationFired,
            (__bridge CFStringRef)NSBundleDidLoadNotification,
            (__bridge CFBundleRef)[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/CameraSettings.bundle"],
            CFNotificationSuspensionBehaviorCoalesce);
    }
}