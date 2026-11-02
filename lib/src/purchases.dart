import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one non-consumable product for the paid cube types.
const String kExtraTypesProductId = 'tech.zhongbei.jellycube3d.extra_types';

enum JellyStoreStatus {
  idle,
  loading,
  ready,
  purchasing,
  restoring,
  unavailable,
  error,
}

/// StoreKit 2 / Play Billing entitlement for 5×5 and 6×6.
///
/// The purchase itself is always processed by the platform store. This class
/// only listens to transactions, stores a local offline entitlement flag, and
/// exposes product/price/status to the UI. There is no developer backend.
class JellyPurchaseService extends ChangeNotifier {
  JellyPurchaseService({this.debugUnlocked = false})
    : _unlocked = debugUnlocked;

  static const String _prefsKey = 'jelly_cube_3d.extra_types.unlocked';

  final bool debugUnlocked;
  InAppPurchase? _iapInstance;
  InAppPurchase get _iap => _iapInstance ??= InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  SharedPreferences? _prefs;
  ProductDetails? _product;
  bool _unlocked;
  bool _initialized = false;
  JellyStoreStatus _status = JellyStoreStatus.idle;
  String? _message;

  bool get unlocked => _unlocked;
  ProductDetails? get product => _product;
  String get price => _product?.price ?? '—';
  String get title => _product?.title ?? 'Extra Cube Types';
  String get description =>
      _product?.description ??
      'Unlock 5×5 and 6×6 cubes, plus future extra types.';
  JellyStoreStatus get status => _status;
  String? get message => _message;
  bool get initializing => _status == JellyStoreStatus.loading;
  bool get purchasing => _status == JellyStoreStatus.purchasing;
  bool get restoring => _status == JellyStoreStatus.restoring;

  bool get _storePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  /// Reads the offline entitlement without touching the store. Safe to call
  /// during app startup and in widget tests.
  Future<void> loadCached() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final cached = _prefs?.getBool(_prefsKey) ?? false;
      if (cached && !_unlocked) {
        _unlocked = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _status = JellyStoreStatus.loading;
    notifyListeners();

    try {
      _prefs = await SharedPreferences.getInstance();
      _unlocked = debugUnlocked || (_prefs?.getBool(_prefsKey) ?? false);
    } catch (_) {
      // Local persistence is optional; entitlement still follows the store.
    }

    if (!_storePlatform) {
      _status = JellyStoreStatus.unavailable;
      _message = 'In-app purchase is available in the iOS and Android builds.';
      notifyListeners();
      return;
    }

    try {
      final available = await _iap.isAvailable();
      if (!available) {
        _status = JellyStoreStatus.unavailable;
        _message = 'The store is not available on this device right now.';
        notifyListeners();
        return;
      }

      _subscription ??= _iap.purchaseStream.listen(
        _handlePurchases,
        onError: (Object error) {
          _status = JellyStoreStatus.error;
          _message = 'The store returned an error. Please try again.';
          notifyListeners();
        },
      );

      final response = await _iap.queryProductDetails(<String>{
        kExtraTypesProductId,
      });
      if (response.productDetails.isEmpty) {
        _status = JellyStoreStatus.unavailable;
        _message = response.notFoundIDs.contains(kExtraTypesProductId)
            ? 'Extra Cube Types is not configured in the store yet.'
            : 'Store product details are unavailable.';
      } else {
        _product = response.productDetails.first;
        _status = JellyStoreStatus.ready;
        _message = _unlocked ? 'Extra Cube Types is unlocked.' : null;
      }
    } catch (_) {
      _status = JellyStoreStatus.unavailable;
      _message =
          'The store is unavailable. Check your connection and try again.';
    }
    notifyListeners();
  }

  Future<void> buy() async {
    if (_unlocked) return;
    if (!_initialized) await init();
    final product = _product;
    if (product == null) {
      _status = JellyStoreStatus.unavailable;
      _message = 'The store product is not configured yet.';
      notifyListeners();
      return;
    }
    _status = JellyStoreStatus.purchasing;
    _message = null;
    notifyListeners();
    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _status = JellyStoreStatus.error;
        _message = 'The purchase could not be started.';
        notifyListeners();
      }
    } catch (_) {
      _status = JellyStoreStatus.error;
      _message = 'The purchase could not be started.';
      notifyListeners();
    }
  }

  Future<void> restore() async {
    if (!_initialized) await init();
    if (!_storePlatform) return;
    _status = JellyStoreStatus.restoring;
    _message = null;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      // Restored purchases arrive on purchaseStream. If none arrives, keep the
      // UI in ready state and explain that no purchase was found.
      _status = JellyStoreStatus.ready;
      _message = _unlocked
          ? 'Extra Cube Types is unlocked.'
          : 'No previous purchase was found for this store account.';
      notifyListeners();
    } catch (_) {
      _status = JellyStoreStatus.error;
      _message = 'Restore failed. Check your store account and try again.';
      notifyListeners();
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kExtraTypesProductId) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _status = JellyStoreStatus.purchasing;
          _message = 'Waiting for the store to confirm the purchase…';
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _unlocked = true;
          try {
            await _prefs?.setBool(_prefsKey, true);
          } catch (_) {}
          _status = JellyStoreStatus.ready;
          _message = 'Extra Cube Types is unlocked.';
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (_) {}
          }
          notifyListeners();
          break;
        case PurchaseStatus.error:
          _status = JellyStoreStatus.error;
          _message =
              purchase.error?.message ??
              'The store could not complete the purchase.';
          if (purchase.pendingCompletePurchase) {
            try {
              await _iap.completePurchase(purchase);
            } catch (_) {}
          }
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _status = JellyStoreStatus.ready;
          _message = 'Purchase canceled.';
          notifyListeners();
          break;
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
