#import <dlfcn.h>
#import <objc/runtime.h>
#import <notify.h>

#define NSLog(...)

#ifndef kCFCoreFoundationVersionNumber_iOS_15_0
#define kCFCoreFoundationVersionNumber_iOS_15_0 1854.0
#endif

@interface UIKeyboardInputMode : UITextInputMode
@property (nonatomic, readonly) NSString *identifierWithLayouts;
@property (nonatomic, readonly) NSString *primaryLanguage;
@end

@interface UIKeyboardInputModeController : NSObject
@property (retain) UIKeyboardInputMode * currentInputMode; 
+(id)sharedInputModeController;
-(id)activeInputModes;
-(void)setCurrentInputMode:(UIKeyboardInputMode *)arg1;
-(void)switchToNextInputMode;
@end

@interface UIKeyboardImpl : UIView
@property (retain) UISwipeGestureRecognizer * gestureSwipeUp;
@property (retain) UISwipeGestureRecognizer * gestureSwipeDown;
+(id)sharedInstance;
-(BOOL)isWeChatKeyboard;
@end

static BOOL Enabled;
static BOOL isRootless = NO;

static NSString* getPreferencesPath(void) {
    NSString *rootlessPath = @"/var/jb/var/mobile/Library/Preferences/com.delewhopper.keyswipeprefs.plist";
    NSString *rootedPath = @"/var/mobile/Library/Preferences/com.delewhopper.keyswipeprefs.plist";
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:rootlessPath]) {
        isRootless = YES;
        return rootlessPath;
    }
    return rootedPath;
}

%hook UIKeyboardInputModeController
%new
- (void)handleKeySwipe:(UISwipeGestureRecognizer*)gesture
{
    UIKeyboardImpl *keyboard = [%c(UIKeyboardImpl) sharedInstance];
    BOOL isWeChat = [keyboard isWeChatKeyboard];
    
    if (isWeChat) {
        NSArray* inputs = [self activeInputModes];
        UIKeyboardInputMode* currentMode = [self currentInputMode];
        NSString *currentLang = currentMode.primaryLanguage;
        UIKeyboardInputMode* targetMode = nil;
        
        BOOL isUpSwipe = (gesture.direction == UISwipeGestureRecognizerDirectionUp);
        
        for (UIKeyboardInputMode* mode in inputs) {
            NSString *lang = mode.primaryLanguage;
            if (isUpSwipe) {
                if ([currentLang hasPrefix:@"zh"] && [lang hasPrefix:@"en"]) {
                    targetMode = mode;
                    break;
                } else if ([currentLang hasPrefix:@"en"] && [lang hasPrefix:@"zh"]) {
                    targetMode = mode;
                    break;
                }
            } else {
                if ([currentLang hasPrefix:@"en"] && [lang hasPrefix:@"zh"]) {
                    targetMode = mode;
                    break;
                } else if ([currentLang hasPrefix:@"zh"] && [lang hasPrefix:@"en"]) {
                    targetMode = mode;
                    break;
                }
            }
        }
        
        if (targetMode) {
            [self setCurrentInputMode:targetMode];
            return;
        }
    }
    
    NSArray* inputs = [self activeInputModes];
    int currIdx = [inputs indexOfObject:[self currentInputMode]];
    UIKeyboardInputMode* newInput = nil;
    if(gesture.direction == UISwipeGestureRecognizerDirectionUp) {
        if((currIdx+1) >= [inputs count]) {
            newInput = [inputs objectAtIndex:0];
        } else {
            newInput = [inputs objectAtIndex:currIdx+1];
        }
    } else {
        if((currIdx-1) < 0) {
            newInput = [inputs objectAtIndex:[inputs count]-1];
        } else {
            newInput = [inputs objectAtIndex:currIdx-1];
        }
    }
    [self setCurrentInputMode:newInput];
}
%end

%hook UIKeyboardImpl
%property (retain) id gestureSwipeUp;
%property (retain) id gestureSwipeDown;

%new
-(BOOL)isWeChatKeyboard
{
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleID isEqualToString:@"com.tencent.xin"]) {
        return YES;
    }
    
    UIKeyboardInputMode *currentMode = [[%c(UIKeyboardInputModeController) sharedInputModeController] currentInputMode];
    if (currentMode) {
        NSString *identifier = currentMode.identifierWithLayouts;
        if ([identifier containsString:@"WeChatKeyboard"] || 
            [identifier containsString:@"com.tencent"]) {
            return YES;
        }
    }
    
    return NO;
}

-(void)updateLayout
{
    %orig;
    if(!self.gestureSwipeUp) {
        self.gestureSwipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:[%c(UIKeyboardInputModeController) sharedInputModeController] action:@selector(handleKeySwipe:)];
    }
    self.gestureSwipeUp.enabled = Enabled;
    [self.gestureSwipeUp setDirection:UISwipeGestureRecognizerDirectionUp];
    [self removeGestureRecognizer:self.gestureSwipeUp];
    [self addGestureRecognizer:self.gestureSwipeUp];
    
    if(!self.gestureSwipeDown) {
        self.gestureSwipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:[%c(UIKeyboardInputModeController) sharedInputModeController] action:@selector(handleKeySwipe:)];
    }
    self.gestureSwipeDown.enabled = Enabled;
    [self.gestureSwipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    [self removeGestureRecognizer:self.gestureSwipeDown];
    [self addGestureRecognizer:self.gestureSwipeDown];
    
    for(UIGestureRecognizer *recognizer in self.gestureRecognizers) {
        if (recognizer != self.gestureSwipeUp && recognizer != self.gestureSwipeDown) {
            [recognizer requireGestureRecognizerToFail:self.gestureSwipeUp];
            [recognizer requireGestureRecognizerToFail:self.gestureSwipeDown];
        }
    }
}
%end


static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    @autoreleasepool {
        NSString *prefsPath = getPreferencesPath();
        NSDictionary *Prefs = [NSDictionary dictionaryWithContentsOfFile:prefsPath]?:@{};
        Enabled = [Prefs[@"active"]?:@YES boolValue];
    }
}

%ctor
{
    prefsChanged(NULL, NULL, NULL, NULL, NULL);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, (CFStringRef)@"com.delewhopper.keyswipeprefs.reloadPrefs", NULL, 0);
}