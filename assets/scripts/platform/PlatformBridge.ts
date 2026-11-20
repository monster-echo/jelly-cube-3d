// Jelly Cube 3D — Cross-Platform Bridge for AdMob, IAP, and Haptics
// Supports: iOS / Android (native.reflection), WeChat Mini-Game (wx), Web fallback.

import { native, sys } from 'cc';

export type AdPlacement = 'hint' | 'double_reward' | 'skin_trial' | 'level_complete';

export interface PlatformListener {
    onCoinsGranted?(amount: number): void;
}

class PlatformBridgeImpl {
    private _adBusy = false;

    get isNativeMobile(): boolean {
        return sys.isNative && (sys.os === sys.OS.IOS || sys.os === sys.OS.ANDROID);
    }

    get isWeChat(): boolean {
        return sys.platform === sys.Platform.WECHAT_GAME;
    }

    /**
     * Shows a Rewarded Video Ad (AdMob on iOS/Android, wx.createRewardedVideoAd on WeChat).
     * Returns true if the user earned the reward.
     */
    async showRewardedAd(placement: AdPlacement): Promise<boolean> {
        if (this._adBusy) return false;
        this._adBusy = true;
        try {
            if (sys.isNative && sys.os === sys.OS.IOS) {
                return await this._callNativeAsync('AdMobBridge', 'showRewardedAd:', placement);
            }
            if (sys.isNative && sys.os === sys.OS.ANDROID) {
                return await this._callNativeAsync(
                    'com/jellycube3d/bridge/AdMobBridge',
                    'showRewardedAd',
                    placement,
                );
            }
            if (this.isWeChat) {
                return await this._showWeChatRewarded(placement);
            }
            // Web / Preview mode: simulate a short rewarded ad completion
            await new Promise((r) => setTimeout(r, 350));
            return true;
        } finally {
            this._adBusy = false;
        }
    }

    /** Shows an Interstitial Ad between levels (respects frequency cap on native). */
    showInterstitialAd(placement: AdPlacement): void {
        if (sys.isNative && sys.os === sys.OS.IOS) {
            native.reflection.callStaticMethod('AdMobBridge', 'showInterstitialAd:', placement);
            return;
        }
        if (sys.isNative && sys.os === sys.OS.ANDROID) {
            native.reflection.callStaticMethod(
                'com/jellycube3d/bridge/AdMobBridge',
                'showInterstitialAd',
                '(Ljava/lang/String;)V',
                placement,
            );
        }
    }

    /** Controls bottom Banner visibility (hidden during active 3D drag). */
    setBannerVisible(visible: boolean): void {
        if (sys.isNative && sys.os === sys.OS.IOS) {
            native.reflection.callStaticMethod(
                'AdMobBridge',
                'setBannerVisible:',
                visible ? '1' : '0',
            );
        } else if (sys.isNative && sys.os === sys.OS.ANDROID) {
            native.reflection.callStaticMethod(
                'com/jellycube3d/bridge/AdMobBridge',
                'setBannerVisible',
                '(Z)V',
                visible,
            );
        }
    }

    /** Light / Medium / Success tactile feedback. */
    vibrate(style: 'light' | 'medium' | 'success', enabled: boolean): void {
        if (!enabled) return;
        if (sys.isNative && sys.os === sys.OS.IOS) {
            native.reflection.callStaticMethod('HapticsBridge', 'impact:', style);
            return;
        }
        if (sys.isNative && sys.os === sys.OS.ANDROID) {
            native.reflection.callStaticMethod(
                'com/jellycube3d/bridge/HapticsBridge',
                'impact',
                '(Ljava/lang/String;)V',
                style,
            );
            return;
        }
        if (this.isWeChat) {
            const wxAny = (globalThis as Record<string, unknown>)['wx'] as
                | { vibrateShort?: (opts: { type: string }) => void }
                | undefined;
            wxAny?.vibrateShort?.({ type: style === 'light' ? 'light' : 'medium' });
            return;
        }
        if (typeof navigator !== 'undefined' && typeof navigator.vibrate === 'function') {
            navigator.vibrate(style === 'success' ? [12, 30, 18] : style === 'medium' ? 14 : 7);
        }
    }

    /** Native / WeChat / Web share sheet. */
    async shareGame(title: string, text: string): Promise<boolean> {
        if (this.isWeChat) {
            const wxAny = (globalThis as Record<string, unknown>)['wx'] as
                | { shareAppMessage?: (opts: { title: string }) => void }
                | undefined;
            wxAny?.shareAppMessage?.({ title: `${title} - ${text}` });
            return true;
        }
        if (typeof navigator !== 'undefined' && typeof (navigator as Navigator).share === 'function') {
            try {
                await (navigator as Navigator).share({ title, text });
                return true;
            } catch {
                return false;
            }
        }
        return false;
    }

    /** Opens App Store / Google Play review prompt on native. */
    openStoreReview(): void {
        if (sys.isNative && sys.os === sys.OS.IOS) {
            native.reflection.callStaticMethod('AdMobBridge', 'requestReview:', '');
        } else if (sys.isNative && sys.os === sys.OS.ANDROID) {
            native.reflection.callStaticMethod(
                'com/jellycube3d/bridge/AdMobBridge',
                'requestReview',
                '()V',
            );
        }
    }

    private _callNativeAsync(cls: string, method: string, arg: string): Promise<boolean> {
        return new Promise((resolve) => {
            const cbName = `__jellyAdCb_${Date.now()}`;
            (globalThis as Record<string, unknown>)[cbName] = (ok: boolean) => {
                delete (globalThis as Record<string, unknown>)[cbName];
                resolve(Boolean(ok));
            };
            if (sys.os === sys.OS.IOS) {
                native.reflection.callStaticMethod(cls, `${method}callback:`, arg, cbName);
            } else {
                native.reflection.callStaticMethod(
                    cls,
                    method,
                    '(Ljava/lang/String;Ljava/lang/String;)V',
                    arg,
                    cbName,
                );
            }
        });
    }

    private _showWeChatRewarded(_placement: string): Promise<boolean> {
        return new Promise((resolve) => {
            const wxAny = (globalThis as Record<string, unknown>)['wx'] as
                | {
                      createRewardedVideoAd?: (opts: { adUnitId: string }) => {
                          show: () => Promise<void>;
                          load: () => Promise<void>;
                          onClose: (cb: (res: { isEnded: boolean }) => void) => void;
                          offClose: (cb: (res: { isEnded: boolean }) => void) => void;
                      };
                  }
                | undefined;
            if (!wxAny?.createRewardedVideoAd) {
                resolve(true);
                return;
            }
            const ad = wxAny.createRewardedVideoAd({ adUnitId: 'WECHAT_REWARDED_UNIT_ID' });
            const handler = (res: { isEnded: boolean }) => {
                ad.offClose(handler);
                resolve(Boolean(res?.isEnded));
            };
            ad.onClose(handler);
            ad.show().catch(() => ad.load().then(() => ad.show()).catch(() => resolve(false)));
        });
    }
}

export const PlatformBridge = new PlatformBridgeImpl();
