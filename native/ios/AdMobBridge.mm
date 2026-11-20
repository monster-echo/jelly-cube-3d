// iOS AdMob Bridge for Cocos Creator 3.8.6 (GoogleMobileAds SDK)
// Production App ID (Info.plist GADApplicationIdentifier): ca-app-pub-2271052258925299~4315636529

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <GoogleMobileAds/GoogleMobileAds.h>
#include "cocos/bindings/jswrapper/SeApi.h"

static NSString *const kIosRewardedUnitId = @"ca-app-pub-2271052258925299/2302936450";
static NSString *const kIosInterstitialUnitId = @"ca-app-pub-2271052258925299/7327585319";
static NSString *const kIosBannerUnitId = @"ca-app-pub-2271052258925299/9110787308";
static const NSTimeInterval kInterstitialCooldownSec = 60.0;

@interface AdMobBridge : NSObject <GADFullScreenContentDelegate>
+ (instancetype)shared;
+ (void)preloadAds;
+ (void)showRewardedAd:(NSString *)placement callback:(NSString *)cbName;
+ (void)showInterstitialAd:(NSString *)placement;
+ (void)setBannerVisible:(NSString *)visibleFlag;
+ (void)requestReview:(NSString *)unused;
@end

@implementation AdMobBridge {
    GADRewardedAd *_rewardedAd;
    BOOL _rewardedLoading;
    GADInterstitialAd *_interstitialAd;
    BOOL _interstitialLoading;
    NSTimeInterval _lastInterstitialTime;
    GADBannerView *_bannerView;
    NSString *_pendingRewardCb;
    BOOL _rewardEarned;
}

+ (instancetype)shared {
    static AdMobBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AdMobBridge alloc] init];
    });
    return instance;
}

+ (UIViewController *)rootVC {
    return UIApplication.sharedApplication.keyWindow.rootViewController;
}

+ (void)evalJsCallback:(NSString *)cbName ok:(BOOL)ok {
    if (!cbName || cbName.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        se::ScriptEngine::getInstance()->evalString(
            [NSString stringWithFormat:@"globalThis['%@'] && globalThis['%@'](%@);",
             cbName, cbName, ok ? @"true" : @"false"].UTF8String
        );
    });
}

+ (void)preloadAds {
    AdMobBridge *s = [self shared];
    static dispatch_once_t initOnce;
    dispatch_once(&initOnce, ^{
        if (@available(iOS 14, *)) {
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                [GADMobileAds.sharedInstance startWithCompletionHandler:nil];
            }];
        } else {
            [GADMobileAds.sharedInstance startWithCompletionHandler:nil];
        }
    });

    if (!s->_rewardedAd && !s->_rewardedLoading) {
        s->_rewardedLoading = YES;
        [GADRewardedAd loadWithAdUnitID:kIosRewardedUnitId
                                request:[GADRequest request]
                      completionHandler:^(GADRewardedAd *ad, NSError *error) {
            s->_rewardedLoading = NO;
            if (!error && ad) {
                ad.fullScreenContentDelegate = s;
                s->_rewardedAd = ad;
            }
        }];
    }

    if (!s->_interstitialAd && !s->_interstitialLoading) {
        s->_interstitialLoading = YES;
        [GADInterstitialAd loadWithAdUnitID:kIosInterstitialUnitId
                                    request:[GADRequest request]
                          completionHandler:^(GADInterstitialAd *ad, NSError *error) {
            s->_interstitialLoading = NO;
            if (!error && ad) {
                ad.fullScreenContentDelegate = s;
                s->_interstitialAd = ad;
            }
        }];
    }
}

+ (void)showRewardedAd:(NSString *)placement callback:(NSString *)cbName {
    dispatch_async(dispatch_get_main_queue(), ^{
        AdMobBridge *s = [self shared];
        if (!s->_rewardedAd) {
            [self preloadAds];
            [self evalJsCallback:cbName ok:NO];
            return;
        }
        GADRewardedAd *ad = s->_rewardedAd;
        s->_rewardedAd = nil;
        s->_pendingRewardCb = [cbName copy];
        s->_rewardEarned = NO;

        [ad presentFromRootViewController:[self rootVC] userDidEarnRewardHandler:^{
            s->_rewardEarned = YES;
        }];
    });
}

+ (void)showInterstitialAd:(NSString *)placement {
    dispatch_async(dispatch_get_main_queue(), ^{
        AdMobBridge *s = [self shared];
        NSTimeInterval now = CACurrentMediaTime();
        if (now - s->_lastInterstitialTime < kInterstitialCooldownSec) {
            return;
        }
        if (s->_interstitialAd) {
            GADInterstitialAd *ad = s->_interstitialAd;
            s->_interstitialAd = nil;
            s->_lastInterstitialTime = now;
            [ad presentFromRootViewController:[self rootVC]];
        } else {
            [self preloadAds];
        }
    });
}

#pragma mark - GADFullScreenContentDelegate

- (void)adDidDismissFullScreenContent:(id<GADFullScreenPresentingAd>)ad {
    if (_pendingRewardCb) {
        NSString *cb = _pendingRewardCb;
        BOOL ok = _rewardEarned;
        _pendingRewardCb = nil;
        _rewardEarned = NO;
        [AdMobBridge evalJsCallback:cb ok:ok];
    }
    [AdMobBridge preloadAds];
}

- (void)ad:(id<GADFullScreenPresentingAd>)ad didFailToPresentFullScreenContentWithError:(NSError *)error {
    if (_pendingRewardCb) {
        NSString *cb = _pendingRewardCb;
        _pendingRewardCb = nil;
        _rewardEarned = NO;
        [AdMobBridge evalJsCallback:cb ok:NO];
    }
    [AdMobBridge preloadAds];
}

+ (void)setBannerVisible:(NSString *)visibleFlag {
    BOOL show = [visibleFlag isEqualToString:@"1"];
    dispatch_async(dispatch_get_main_queue(), ^{
        AdMobBridge *s = [self shared];
        if (!s->_bannerView && show) {
            UIViewController *vc = [self rootVC];
            s->_bannerView = [[GADBannerView alloc] initWithAdSize:GADAdSizeBanner];
            s->_bannerView.adUnitID = kIosBannerUnitId;
            s->_bannerView.rootViewController = vc;
            s->_bannerView.translatesAutoresizingMaskIntoConstraints = NO;
            [vc.view addSubview:s->_bannerView];
            [NSLayoutConstraint activateConstraints:@[
                [s->_bannerView.centerXAnchor constraintEqualToAnchor:vc.view.centerXAnchor],
                [s->_bannerView.bottomAnchor constraintEqualToAnchor:vc.view.safeAreaLayoutGuide.bottomAnchor]
            ]];
            [s->_bannerView loadRequest:[GADRequest request]];
        }
        if (s->_bannerView) s->_bannerView.hidden = !show;
    });
}

+ (void)requestReview:(NSString *)unused {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 14.0, *)) {
            UIWindowScene *scene = (UIWindowScene *)UIApplication.sharedApplication.connectedScenes.anyObject;
            if (scene) [SKStoreReviewController requestReviewInScene:scene];
        } else {
            [SKStoreReviewController requestReview];
        }
    });
}

@end
