package com.jellycube3d.bridge;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;

import com.cocos.lib.CocosHelper;
import com.cocos.lib.CocosJavascriptJavaBridge;
import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.AdSize;
import com.google.android.gms.ads.AdView;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.interstitial.InterstitialAd;
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;

public class AdMobBridge {
    // Production App ID (AndroidManifest.xml APPLICATION_ID): ca-app-pub-2271052258925299~2443463295
    private static final String REWARDED_UNIT_ID = "ca-app-pub-2271052258925299/9079650680";
    private static final String INTERSTITIAL_UNIT_ID = "ca-app-pub-2271052258925299/9929697921";
    private static final String BANNER_UNIT_ID = "ca-app-pub-2271052258925299/4611149991";

    private static final long INTERSTITIAL_COOLDOWN_MS = 60_000L;

    private static Activity sActivity;
    private static RewardedAd sRewardedAd;
    private static boolean sRewardedLoading = false;
    private static InterstitialAd sInterstitialAd;
    private static boolean sInterstitialLoading = false;
    private static long sLastInterstitialMs = 0L;
    private static AdView sBannerView;

    public static void init(Activity activity) {
        sActivity = activity;
        MobileAds.initialize(activity, initializationStatus -> preloadAds());
    }

    public static void preloadAds() {
        if (sActivity == null) return;
        sActivity.runOnUiThread(() -> {
            AdRequest req = new AdRequest.Builder().build();
            if (sRewardedAd == null && !sRewardedLoading) {
                sRewardedLoading = true;
                RewardedAd.load(sActivity, REWARDED_UNIT_ID, req, new RewardedAdLoadCallback() {
                    @Override
                    public void onAdLoaded(@NonNull RewardedAd ad) {
                        sRewardedAd = ad;
                        sRewardedLoading = false;
                    }

                    @Override
                    public void onAdFailedToLoad(@NonNull LoadAdError err) {
                        sRewardedAd = null;
                        sRewardedLoading = false;
                    }
                });
            }
            if (sInterstitialAd == null && !sInterstitialLoading) {
                sInterstitialLoading = true;
                InterstitialAd.load(sActivity, INTERSTITIAL_UNIT_ID, req, new InterstitialAdLoadCallback() {
                    @Override
                    public void onAdLoaded(@NonNull InterstitialAd ad) {
                        sInterstitialAd = ad;
                        sInterstitialLoading = false;
                    }

                    @Override
                    public void onAdFailedToLoad(@NonNull LoadAdError err) {
                        sInterstitialAd = null;
                        sInterstitialLoading = false;
                    }
                });
            }
        });
    }

    private static void evalJs(String cbName, boolean ok) {
        CocosHelper.runOnGameThread(() -> CocosJavascriptJavaBridge.evalString(
            "globalThis['" + cbName + "'] && globalThis['" + cbName + "'](" + (ok ? "true" : "false") + ");"
        ));
    }

    public static void showRewardedAd(String placement, String cbName) {
        if (sActivity == null) {
            evalJs(cbName, false);
            return;
        }
        sActivity.runOnUiThread(() -> {
            if (sRewardedAd == null) {
                preloadAds();
                evalJs(cbName, false);
                return;
            }
            RewardedAd ad = sRewardedAd;
            sRewardedAd = null;
            final boolean[] earned = { false };

            ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                @Override
                public void onAdDismissedFullScreenContent() {
                    evalJs(cbName, earned[0]);
                    preloadAds();
                }

                @Override
                public void onAdFailedToShowFullScreenContent(@NonNull AdError adError) {
                    evalJs(cbName, false);
                    preloadAds();
                }
            });

            ad.show(sActivity, rewardItem -> earned[0] = true);
        });
    }

    public static void showInterstitialAd(String placement) {
        if (sActivity == null) return;
        long now = System.currentTimeMillis();
        if (now - sLastInterstitialMs < INTERSTITIAL_COOLDOWN_MS) return;
        sActivity.runOnUiThread(() -> {
            if (sInterstitialAd != null) {
                InterstitialAd ad = sInterstitialAd;
                sInterstitialAd = null;
                sLastInterstitialMs = System.currentTimeMillis();
                ad.setFullScreenContentCallback(new FullScreenContentCallback() {
                    @Override
                    public void onAdDismissedFullScreenContent() {
                        preloadAds();
                    }

                    @Override
                    public void onAdFailedToShowFullScreenContent(@NonNull AdError adError) {
                        preloadAds();
                    }
                });
                ad.show(sActivity);
            } else {
                preloadAds();
            }
        });
    }

    public static void setBannerVisible(boolean visible) {
        if (sActivity == null) return;
        sActivity.runOnUiThread(() -> {
            if (sBannerView == null && visible) {
                sBannerView = new AdView(sActivity);
                sBannerView.setAdSize(AdSize.BANNER);
                sBannerView.setAdUnitId(BANNER_UNIT_ID);
                FrameLayout.LayoutParams lp = new FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
                );
                sActivity.addContentView(sBannerView, lp);
                sBannerView.loadAd(new AdRequest.Builder().build());
            }
            if (sBannerView != null) {
                sBannerView.setVisibility(visible ? View.VISIBLE : View.GONE);
            }
        });
    }

    public static void requestReview() {
        if (sActivity == null) return;
        sActivity.runOnUiThread(() -> {
            String pkg = sActivity.getPackageName();
            try {
                sActivity.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + pkg)));
            } catch (Exception e) {
                sActivity.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=" + pkg)));
            }
        });
    }
}
