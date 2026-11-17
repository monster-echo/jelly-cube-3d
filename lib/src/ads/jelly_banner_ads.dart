import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Bottom anchored banner ads for Jelly Cube 3D.
///
/// Ad unit IDs are injected per platform at build time via --dart-define;
/// when absent we fall back to Google's official test ad units (local
/// development ONLY — shipping test IDs to the store is invalid traffic and
/// Google will suspend the account):
///   --dart-define=ADMOB_ANDROID_BANNER_UNIT=ca-app-pub-xxx/bbb
///   --dart-define=ADMOB_IOS_BANNER_UNIT=ca-app-pub-xxx/bbb
/// The App ID is injected separately through AndroidManifest
/// (${admobAppId}) and iOS Info.plist ($(ADMOB_APPLICATION_ID)).
///
/// Compliance flow (Google recommended order): UMP consent gathering →
/// iOS ATT → canRequestAds gate → MobileAds.initialize. Initialization
/// must not run before the privacy/consent gate completes.
final class JellyAds {
  JellyAds._();

  static final JellyAds instance = JellyAds._();

  /// Whether the MobileAds SDK initialized successfully and banner ads may
  /// be requested. Notified via [availability].
  bool _available = false;

  bool _initializing = false;

  final ValueNotifier<bool> availability = ValueNotifier<bool>(false);

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Banner ad unit for the current platform, or Google's test banner when
  /// no production ID was injected.
  static String get bannerUnitId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return const String.fromEnvironment(
        'ADMOB_IOS_BANNER_UNIT',
        defaultValue: 'ca-app-pub-3940256099942544/2934735716',
      );
    }
    return const String.fromEnvironment(
      'ADMOB_ANDROID_BANNER_UNIT',
      defaultValue: 'ca-app-pub-3940256099942544/6300978111',
    );
  }

  /// True when the current ad unit is a Google test ID (i.e. production
  /// IDs have not been injected yet).
  static bool get usingTestAdUnit =>
      bannerUnitId.contains('3940256099942544');

  /// Idempotent bootstrap: UMP consent → iOS ATT → SDK init. Safe to call
  /// from `main()` after `WidgetsFlutterBinding.ensureInitialized()`; on
  /// unsupported platforms (web/macOS/ohos) it is a no-op.
  Future<void> ensureInitialized() async {
    if (!_supported || _available || _initializing) return;
    _initializing = true;
    try {
      await _gatherConsent();
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        _available = true;
        availability.value = true;
      }
      // canRequestAds == false (refused/pending): stay unavailable; the
      // privacy options form remains reachable in a later session.
    } catch (_) {
      // Consent flow or SDK init failure (e.g. emulator without Google
      // Play Services): degrade to no ads.
      _available = false;
      availability.value = false;
    } finally {
      _initializing = false;
    }
  }

  /// UMP consent gathering + iOS ATT (Google order: UMP first, then ATT).
  Future<void> _gatherConsent() async {
    final params = ConsentRequestParameters();
    // requestConsentInfoUpdate is a void callback API; wrap the form
    // presentation in a Completer so the outer await truly waits until the
    // form is dismissed.
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        try {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
          }
          completer.complete();
        } catch (e) {
          completer.completeError(e);
        }
      },
      (FormError error) => completer.completeError(error),
    );
    await completer.future;

    // iOS only: request tracking permission after consent, best-effort.
    if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
      try {
        await AppTrackingTransparency.requestTrackingAuthorization();
      } catch (_) {
        // Pre-iOS14 or window not ready: ignore.
      }
    }
  }
}

/// Slot that renders a bottom anchored adaptive banner. Hidden entirely on
/// unsupported platforms, before consent, or when [unlocked] is true
/// (paying users see no ads).
class JellyBannerSlot extends StatefulWidget {
  const JellyBannerSlot({super.key, required this.unlocked});

  /// Whether the ad-free entitlement is owned (Extra Cube Types purchase).
  final bool unlocked;

  @override
  State<JellyBannerSlot> createState() => _JellyBannerSlotState();
}

class _JellyBannerSlotState extends State<JellyBannerSlot> {
  BannerAd? _banner;
  bool _loaded = false;
  int _lastWidth = 0;

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  void _ensureBanner(double width) {
    if (!JellyAds.instance._available || widget.unlocked) return;
    final px = width.floor();
    if (_banner != null && px == _lastWidth) return;
    _lastWidth = px;
    _banner?.dispose();
    _loaded = false;
    AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      px.clamp(320, 728),
    ).then((size) {
      if (size == null) return;
      if (!mounted) return;
      final ad = BannerAd(
        adUnitId: JellyAds.bannerUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (mounted) setState(() => _loaded = false);
          },
        ),
      );
      _banner = ad;
      ad.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: JellyAds.instance.availability,
      builder: (context, available, _) {
        if (!available || widget.unlocked) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, constraints) {
            _ensureBanner(constraints.maxWidth);
            final ad = _banner;
            if (!_loaded || ad == null) return const SizedBox.shrink();
            return SafeArea(
              top: false,
              child: SizedBox(
                width: ad.size.width.toDouble(),
                height: ad.size.height.toDouble(),
                child: AdWidget(ad: ad),
              ),
            );
          },
        );
      },
    );
  }
}
