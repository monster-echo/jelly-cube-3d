# In-App Purchase — Extra Cube Types

Status: **client implemented; store product and sandbox testing pending**

Local StoreKit test config: `ios/Runner/StoreKit/JellyCube3D.storekit` (test price $2.99, not a production price). It is referenced from the Runner scheme. Flutter launch via `simctl` did not inject the config in this environment; use Xcode Run for manual StoreKit testing.

Implemented in `lib/src/purchases.dart` and `lib/src/purchase_ui.dart`: product query, one-time purchase, restore, local entitlement cache, locked/unlocked 5×5/6×6 UI, and store status. The actual product must still be created in App Store Connect, Play Console and (if sold there) AppGallery IAP Kit.

## Product

- Type: non-consumable
- Free content: 2×2, 3×3, 4×4
- Paid content: 5×5 and 6×6, plus future cube types attached to the same entitlement
- Working product ID: `tech.zhongbei.jellycube3d.extra_types`
- Store product IDs may be configured per platform; keep one product record per store.
- Price: **TBD by product owner**

## UX

- Size selector shows 2×2 / 3×3 / 4×4 normally.
- 5×5 / 6×6 tiles display a small lock badge when the entitlement is absent.
- Tapping a locked tile opens a Jelly Pass sheet:
  - what is unlocked
  - one-time price from the store
  - Buy
  - Restore Purchases
  - legal links
- Purchase success unlocks immediately and updates every size selector.
- Purchase cancellation/error is non-destructive.
- Restore is available on the purchase sheet and in Settings/About.
- The app should remain usable offline if the entitlement was previously verified; refresh entitlements in the background when the store is reachable.

## Entitlement storage

- Store a local boolean/cache keyed to the product ID.
- On every launch: read the local cache immediately, then query the store and reconcile.
- Do not require an account.
- Do not send purchase data to a developer server in v1.

## Platform implementation

### iOS

- StoreKit 2 (preferred) or StoreKit 1 via a narrow native bridge.
- `Transaction.currentEntitlements` for restore; verify locally.
- Handle `.purchase`, `.restore`, `.pending`, `.cancelled`, `.failed`.
- Add the In-App Purchase capability to the Xcode project if required.
- Add an App Store review screenshot of the locked/unlocked flow.

### Android

- Google Play Billing Library (current stable version).
- `queryPurchasesAsync` for restore, acknowledge non-consumables.
- Do not add the old AIDL/billing AIDL; use Play Billing.
- Handle pending purchases and reconnection.
- Add the `com.android.vending.BILLING` permission via the Play Billing dependency.

### HarmonyOS

- Huawei IAP Kit (`@kit.IAPKit` / IAP Kit) via ArkTS.
- HarmonyOS v1 hides 5×5/6×6 via `--dart-define=HARMONY=true`; implement Huawei IAP Kit before advertising/showing paid types there.
- Reuse the same content-entitlement model.

## Compliance

- Apple: In-App Purchase review screenshot, product metadata, restore behavior, no external purchase links.
- Google Play: billing declaration, product setup, purchase testing, no alternative payment in markets that require Play Billing.
- AppGallery: IAP Kit configuration and payment compliance.
- Privacy: store-processed payment; local entitlement; no card data.
- Terms: one-time unlock, restore, refunds via store.
- Data Safety: no developer collection; verify store definitions for purchase processing.

## Testing

- Sandbox purchase on a clean install.
- Cancel purchase.
- Pending purchase.
- Restore after reinstall.
- Restore on a second device.
- Offline launch after entitlement cached.
- Store outage during purchase.
- Switch account without entitlement.
- Verify 5×5/6×6 remain usable offline once unlocked.
