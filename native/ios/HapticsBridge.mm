// iOS Haptics Bridge for Cocos Creator 3.8.6
#import <UIKit/UIKit.h>

@interface HapticsBridge : NSObject
+ (void)impact:(NSString *)style;
@end

@implementation HapticsBridge
+ (void)impact:(NSString *)style {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([style isEqualToString:@"success"]) {
            UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
            [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
        } else {
            UIImpactFeedbackStyle s = [style isEqualToString:@"medium"]
                ? UIImpactFeedbackStyleMedium
                : UIImpactFeedbackStyleLight;
            UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:s];
            [gen impactOccurred];
        }
    });
}
@end
