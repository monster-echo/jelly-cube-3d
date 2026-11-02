import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:jelly_cube_3d/jelly_cube_3d.dart';

class FakeIapPlatform extends InAppPurchasePlatform {
  FakeIapPlatform({this.available = true, this.productMissing = false});

  final bool available;
  final bool productMissing;
  final StreamController<List<PurchaseDetails>> _purchases =
      StreamController<List<PurchaseDetails>>.broadcast();

  int buyCalls = 0;
  int restoreCalls = 0;
  int completeCalls = 0;
  PurchaseDetails? completed;

  ProductDetails get product => ProductDetails(
    id: kExtraTypesProductId,
    title: 'Extra Cube Types',
    description: 'Unlock 5x5 and 6x6',
    price: r'$2.99',
    rawPrice: 2.99,
    currencyCode: 'USD',
    currencySymbol: r'$',
  );

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _purchases.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    if (productMissing) {
      return ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: identifiers.toList(),
      );
    }
    return ProductDetailsResponse(
      productDetails: <ProductDetails>[product],
      notFoundIDs: const <String>[],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buyCalls++;
    return true;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCalls++;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completeCalls++;
    completed = purchase;
  }

  void emit(PurchaseStatus status, {bool pending = true}) {
    final purchase = PurchaseDetails(
      purchaseID: 'test-purchase',
      productID: kExtraTypesProductId,
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server',
        source: 'test',
      ),
      transactionDate: '1700000000000',
      status: status,
    )..pendingCompletePurchase = pending;
    _purchases.add(<PurchaseDetails>[purchase]);
  }

  Future<void> close() => _purchases.close();
}

void main() {
  test('IAP service loads product and unlocks after purchase', () async {
    final fake = FakeIapPlatform();
    final service = JellyPurchaseService(platform: fake);
    addTearDown(() async {
      service.dispose();
      await fake.close();
    });

    await service.init();
    expect(service.status, JellyStoreStatus.ready);
    expect(service.price, r'$2.99');
    expect(service.unlocked, isFalse);

    await service.buy();
    expect(fake.buyCalls, 1);
    expect(service.purchasing, isTrue);

    fake.emit(PurchaseStatus.purchased);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.unlocked, isTrue);
    expect(fake.completeCalls, 1);
    expect(fake.completed?.productID, kExtraTypesProductId);
  });

  test('restore delivers a non-consumable entitlement', () async {
    final fake = FakeIapPlatform();
    final service = JellyPurchaseService(platform: fake);
    addTearDown(() async {
      service.dispose();
      await fake.close();
    });

    await service.init();
    await service.restore();
    expect(fake.restoreCalls, 1);

    fake.emit(PurchaseStatus.restored);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.unlocked, isTrue);
    expect(fake.completeCalls, 1);
  });

  test('cancel does not unlock', () async {
    final fake = FakeIapPlatform();
    final service = JellyPurchaseService(platform: fake);
    addTearDown(() async {
      service.dispose();
      await fake.close();
    });

    await service.init();
    await service.buy();
    fake.emit(PurchaseStatus.canceled, pending: false);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(service.unlocked, isFalse);
    expect(service.status, JellyStoreStatus.ready);
  });

  test('missing product reports unavailable', () async {
    final fake = FakeIapPlatform(productMissing: true);
    final service = JellyPurchaseService(platform: fake);
    addTearDown(() async {
      service.dispose();
      await fake.close();
    });

    await service.init();
    expect(service.status, JellyStoreStatus.unavailable);
    expect(service.unlocked, isFalse);
  });

  test('unavailable store reports unavailable', () async {
    final fake = FakeIapPlatform(available: false);
    final service = JellyPurchaseService(platform: fake);
    addTearDown(() async {
      service.dispose();
      await fake.close();
    });

    await service.init();
    expect(service.status, JellyStoreStatus.unavailable);
  });
}
