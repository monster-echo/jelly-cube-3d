# Store Submission Assets

This directory contains store-facing material only. It is not bundled into the app.

## Status

| Area | Status |
| --- | --- |
| Brand name | Jelly Cube 3D |
| Bundle/application ID | tech.zhongbei.jellycube3d |
| Apple icon master | `store/apple/icon-1024.png` |
| Google icon | `store/google/icon-512.png` |
| Google feature graphic | `store/google/feature-graphic-1024x500.png` |
| Apple screenshots | Captured: 6.9" (1320×2868, incl. extra-types sheet), 6.5" (1242×2688), iPad 13" (2064×2752) |
| Google screenshots | Captured: phone 1080×1920, tablet 1440×2560 |
| AppGallery screenshots | Captured from OpenHarmony 7 emulator (1280×2832); signed-device recapture optional |
| Runtime smoke | iOS phone/iPad simulator, Android emulator, OpenHarmony 7 emulator launch PASS |
| Store copy | `store/listing-en.md`, `store/listing-zh-Hans.md` |
| Privacy policy | `docs/PRIVACY.md` |
| Support | `docs/SUPPORT.md` |
| IAP plan | `docs/IAP.md` |
| IAP implementation | Client implemented; store product/price and sandbox testing still required |
| Exact screenshot sets | **NOT CAPTURED** |

## IAP setup sheets

- [Apple IAP](apple/iap-product.md)
- [Google IAP](google/iap-product.md)
- [Huawei IAP status](huawei/iap-product.md)

## Screenshot rules

- Capture from the release build, not a mockup.
- Use real game states: solved hero, mid-twist, poke ripple, drop squash, 4×4 or 6×6 selection.
- Do not include debug UI, the Flutter debug banner, placeholder icons, or the old “Rubik's” name.
- Keep the same device family and orientation consistent within a set.
- App Store and Google Play dimensions must be checked against the current console requirements; never upscale a smaller screenshot.

## Current documentation images (not store-compliant)

The `screenshots/` directory at the repo root contains 780×1688, 1206×2622, 1668×2420 and 2048×1536 images for README/demo use. They are not the required store size sets and still show the pre-rename title.
