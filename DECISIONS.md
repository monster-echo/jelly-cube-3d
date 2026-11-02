# Release Decisions — Jelly Cube 3D

- Status: **ACCEPTED (with IAP implementation pending product/price setup)**
- Created: 2026-11-02
- Decision owner: product owner
- Supersedes: working name “Rubik's Jelly”

## Decision log

| ID | Decision | Status | Date |
| --- | --- | --- | --- |
| D1 | Rename to **Jelly Cube 3D**; stop using “Rubik's” in store-facing material | ACCEPTED | 2026-11-02 |
| D2 | First release: **global excluding mainland China** | ACCEPTED | 2026-11-02 |
| D3 | HarmonyOS route: **Flutter-OHOS first**, with runtime quality gate | ACCEPTED | 2026-11-02 |
| D4 | **Free download + non-consumable IAP**; 2×2/3×3/4×4 free; IAP unlocks additional cube types (5×5/6×6 and future types) | ACCEPTED (product/price TBD) | 2026-11-02 |
| D5 | Accounts/signing **not complete**; produce a checklist and collect assets | ACCEPTED | 2026-11-02 |
| D6 | Official identifiers: `tech.zhongbei.jellycube3d` for iOS / Android / HarmonyOS | ACCEPTED | 2026-11-02 |

## D1 — Brand

- Public name: `Jelly Cube 3D`
- Store subtitle candidates: `A soft-body twisty puzzle`, `Wobble. Twist. Solve.`
- Remove “Rubik's” from:
  - iOS display name
  - Android label
  - Harmony app label
  - macOS product name
  - Web title/manifest
  - In-app title
  - Store descriptions/keywords/screenshots
  - README and release docs
- Internal Dart source can keep legacy identifiers temporarily, but public API/docs should migrate to `JellyCube*`.

## D2 — Regions

- First submission: global, **excluding mainland China**.
- App Store / Google Play / AppGallery country lists must exclude `China mainland`.
- China-specific software copyright, APP filing, game approval and Chinese legal review are **out of scope for v1**.
- Do not promise a mainland launch date until a separate compliance track is opened.

## D3 — HarmonyOS

- Use the locally installed Flutter-OHOS fork (`/Users/echo/flutter-ohos-3.41.9`, 3.41.10-ohos-0.0.4-dev, Dart 3.11.5).
- HAP compile spike passed in `/tmp/rj_ohos_spike`; tests pass after lowering SDK constraint to `>=3.11.0 <4.0.0`.
- Required before release:
  - `ohos/` host project in-repo
  - ArkTS audio platform channel for `tech.zhongbei/jellycube3d_audio` (rename with brand)
  - remove `ohos.permission.INTERNET` unless justified
  - phone + tablet / 2-in-1 device types
  - Rubik's-independent app icon/label
  - Harmony signing profile
  - signed-device runtime QA for shader fallback, haptics, 120 Hz, split-screen
- If runtime quality fails, fallback is force CustomPainter on OHOS; native ArkUI rewrite is a separate project.

## D4 — Monetization

- **Free download.**
- **Free content:** 2×2, 3×3, 4×4.
- **Paid content:** additional cube types, starting with 5×5 and 6×6, unlocked by a **non-consumable** IAP.
- Working product ID: `tech.zhongbei.jellycube3d.extra_types` (Apple/Google product IDs and Harmony IAP IDs may differ; finalize in stores).
- Price: **TBD by owner**.
- Required before implementation:
  - final product name/price
  - restore purchases UX
  - local entitlement cache for offline use
  - purchase/restore/error handling
  - App Store “In-App Purchases” review screenshot
  - Google Play billing declaration and product setup
  - HarmonyOS IAP Kit equivalent if IAP is offered there
- IAP does **not** unlock a subscription; no account and no backend for v1.
- Privacy/data disclosures must mention store-processed purchases and local entitlement storage; the developer does not receive payment card data.

## D5 — Accounts and signing

Known local state:

- Apple team `2VA9TC6SG4` exists; 3 valid codesigning identities; profiles exist for Pindou/CortexTerminal only.
- Google publisher service-account key exists for another project; access to a new app is unverified.
- New Android upload key generated for this app and local signed AAB/APK verified.
- DevEco Studio 26 + OpenHarmony 7 emulator exist; no Jelly Cube 3D Harmony signing profile exists.

Required: see [`ACCOUNTS_AND_SIGNING.md`](ACCOUNTS_AND_SIGNING.md).

## D6 — Identifiers

Use consistently:

```text
Public name:       Jelly Cube 3D
iOS bundle:        tech.zhongbei.jellycube3d
macOS bundle:      tech.zhongbei.jellycube3d
Android package:   tech.zhongbei.jellycube3d
Harmony bundle:    tech.zhongbei.jellycube3d
IAP product:       tech.zhongbei.jellycube3d.extra_types
Audio channel:     tech.zhongbei/jellycube3d_audio
```

These identifiers are immutable after first store submission. Do not create App Store / Play / AGC records until D5 account access is confirmed.
