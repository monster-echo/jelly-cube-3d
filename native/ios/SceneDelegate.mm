// UIScene lifecycle for iOS 26+.
//
// Apps linked against the iOS 26 SDK must adopt the scene lifecycle; without
// it UIKit traps at launch inside
// UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption.
//
// AppDelegate keeps the engine/SDK bootstrap and the legacy (manifest-less)
// window path; this delegate owns the window when the scene manifest exists
// and forwards the foreground/background callbacks the Cocos bridge needs.

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface AppDelegate (SceneSupport)
- (void)setupWindowWithScene:(UIWindowScene *)scene;
@end

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;

    AppDelegate *app = (AppDelegate *)UIApplication.sharedApplication.delegate;
    [app setupWindowWithScene:(UIWindowScene *)scene];
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    AppDelegate *app = (AppDelegate *)UIApplication.sharedApplication.delegate;
    [app applicationDidBecomeActive:UIApplication.sharedApplication];
}

- (void)sceneWillResignActive:(UIScene *)scene {
    AppDelegate *app = (AppDelegate *)UIApplication.sharedApplication.delegate;
    [app applicationWillResignActive:UIApplication.sharedApplication];
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    AppDelegate *app = (AppDelegate *)UIApplication.sharedApplication.delegate;
    [app applicationDidEnterBackground:UIApplication.sharedApplication];
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    AppDelegate *app = (AppDelegate *)UIApplication.sharedApplication.delegate;
    [app applicationWillEnterForeground:UIApplication.sharedApplication];
}

@end
