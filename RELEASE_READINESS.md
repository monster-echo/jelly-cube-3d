# Release Readiness Audit — Rubik's Jelly

- Audit date: 2026-11-02
- Repository: `/Users/echo/workspace/Rubik's Jelly`
- Scope: App Store (iOS), Google Play (Android), Huawei AppGallery / HarmonyOS
- Auditor role: release engineering / store compliance
- Verdict: **NOT STORE-SUBMITTABLE YET**
- Code changes made by this audit: **none**
> **Post-audit decision update (2026-11-02):** the product owner accepted the rename to **Jelly Cube 3D**, bundle ID `tech.zhongbei.jellycube3d`, global excluding mainland China, Flutter-OHOS, and free download + non-consumable IAP for extra cube types. This document preserves the original audit evidence from the pre-rename tree; see `DECISIONS.md` for current decisions.
 (temporary OHOS spike was built in `/tmp/rj_ohos_spike` only)


## 0. Post-audit remediation checkpoint (2026-11-02, after decisions)

The original findings below are preserved as audit evidence. This pass has already changed the tree:

| Item | Before | Now |
| --- | --- | --- |
| Public name | Rubik's Jelly | **Jelly Cube 3D** |
| iOS/Android/Harmony IDs | `studio.jelly.rubiksJelly` / `studio.jelly.rubiks_jelly` | **`tech.zhongbei.jellycube3d`** |
| Dart package / entry | `rubiks_jelly` / `rubiks_jelly.dart` | `jelly_cube_3d` / `jelly_cube_3d.dart` |
| iOS AppIcon / LaunchImage | default Flutter placeholders | procedural branded 1024/launch set |
| Android icons / splash | default Flutter mipmaps / white launch | adaptive icon, monochrome, Android 12 splash, lilac launch |
| iOS privacy manifest | missing | `ios/Runner/PrivacyInfo.xcprivacy` in bundle |
| Encryption declaration | missing | `ITSAppUsesNonExemptEncryption=false` |
| Android release hardening | default backup, no round icon | `allowBackup=false`, `usesCleartextTraffic=false`, round/adaptive icon |
| Legal / support | missing | `docs/PRIVACY.md`, `TERMS.md`, `SUPPORT.md` + in-app About entry |
| Store copy / assets | missing | English/Chinese listing drafts, icons, Play feature graphic, screenshot requirements |
| Release scripts | missing | `scripts/build-release.sh`, `scripts/verify-release.sh`, CI workflow skeleton |
| HarmonyOS | not investigated | `ohos/` host integrated; Flutter-OHOS compile/test/HAP passed; see `docs/HARMONY_SPIKE.md` |
| Git baseline | local only | Git repository initialized on `main`; no remote yet |
| Android signing | ready locally | **app-specific 4096-bit upload key generated and AAB/APK signed** |
| Store screenshots | missing | Apple 6.9/6.5/iPad 13 and Google phone/tablet sets captured |

### Current blockers after this pass

Running `scripts/verify-release.sh` now reports:

```text
FAIL iOS archive is not Apple Distribution-signed / IPA missing
FAIL HarmonyOS HAP is unsigned
```

Plus work not yet represented by the verifier:

- 5×5/6×6 IAP flow and product IDs are not implemented; `docs/IAP.md` is the implementation plan.
- Exact App Store / Google Play / AppGallery screenshot sets are not captured.
- App Store Connect, Play Console and AppGallery Connect app records are not created/verified.
- Huawei/Apple/Google app-specific signing material is not present.
- Store consoles, age ratings, privacy/data-safety answers and review notes are drafts only.
- HarmonyOS host is committed and a HAP compiles from a sanitized path, but the HAP is unsigned and ArkTS audio/haptics are not verified.
- Mainland China is out of v1 scope; no software copyright/APP filing/game approval work has been started.
- A local Git repository now exists on `main`; a remote and CI execution are still open.

## 1. Executive summary

The game code is in good shape: `flutter analyze` is clean, all 22 tests pass, Android release AAB and iOS unsigned archive build successfully, and a HarmonyOS HAP can be built with the locally installed Flutter-OHOS toolchain after lowering the pubspec SDK constraint.

The remaining distance to a store submission is primarily release engineering and compliance:

1. **Brand/IP gate** — the product name contains “Rubik's” and is used in native labels, UI copy, web metadata and README. This is a high-risk trademark issue and must be resolved before any store submission.
2. **Android signing** — an app-specific upload key now signs the AAB/APK; Play App Signing enrollment is still a console action.
3. **iOS delivery** — the archive is unsigned; there is no app-level `PrivacyInfo.xcprivacy`; there is no IPA; the App Icon and Launch Image are still Flutter placeholders (Flutter’s own archive validation flags both).
4. **Store assets** — the existing screenshots are documentation images at 780×1688 / 1206×2622 / 1668×2420 / 2048×1536, not the exact current App Store / Play / AppGallery sizes. There is no 1024×500 Play feature graphic, no 512×512 Play icon, and no store metadata directory.
5. **HarmonyOS is now technically feasible, not yet integrated** — Flutter-OHOS 3.41.10, DevEco Studio 26 and an OpenHarmony 7 emulator are installed; a temporary HAP build succeeded. The real repo has no `ohos/` project, no ArkTS audio channel, no Harmony signing, and the generated template currently requests `ohos.permission.INTERNET` and only declares phone form factor.
6. **No legal/store foundation** — no privacy policy, terms, support page, Data Safety answers, App Store Privacy answers, AppGallery materials, or in-app legal entry.
7. **Release pipeline** — a local Git repository, `.github/` workflow, build scripts and a secret policy now exist; a remote and CI execution are still missing.
8. **China distribution is an independent project** — software copyright, APP filing, and game approval requirements need a separate decision and timeline.

## 2. Environment and build evidence

| Item | Observed |
| --- | --- |
| Flutter | 3.47.6 stable, Dart 3.13.5 |
| Xcode | 27.1 |
| Android compile / target SDK | 36 / 36 |
| Android AGP / Kotlin | 9.1.0 / 2.4.0 |
| Android NDK | 28.2.13676358 |
| Flutter-OHOS | 3.41.10-ohos-0.0.4-dev, Dart 3.11.5 |
| DevEco Studio | 26.0.0 |
| Harmony SDK / emulator | OpenHarmony 7.0.0.105, API 26, `127.0.0.1:5557` |
| Git | local repository on `main`; no remote configured |

### Verification commands

```text
flutter analyze
→ No issues found

./tool/test.sh
→ 22 tests passed

flutter build appbundle --release
→ build/app/outputs/bundle/release/app-release.aab (45.6 MB)
→ SHA-256 9aa79993c1789c4f745f7174272636cb7dfc627f1d0d2ac900d7424b7bf08a40
→ second build: byte-identical AAB

flutter build apk --release
→ build/app/outputs/flutter-apk/app-release.apk (45.6 MB)
→ SHA-256 4496ab2411f5711a1931753ea8ccd54031243fdb84d0d19872d69f73775ff6f6
→ signed with CN=Android Debug

flutter build ipa --release --no-codesign
→ build/ios/archive/Runner.xcarchive (170.8 MB)
→ no IPA produced (codesigning disabled)
→ Flutter validation: default App Icon and Launch Image placeholders

Temporary OHOS spike:
flutter pub get / analyze / test under Flutter-OHOS 3.41.10
→ analyzer clean, 22 tests passed
flutter build hap --debug --no-codesign
→ entry-default-unsigned.hap (92 MB)
flutter build hap --release --no-codesign
→ entry-default-unsigned.hap (21.2 MB)
```

### Android artifact facts

- `applicationId`: `studio.jelly.rubiks_jelly`
- `versionName`: `1.0.0`; `versionCode`: `1`
- `minSdk`: 24; `targetSdk`: 36
- Release APK permissions: only the auto-generated `studio.jelly.rubiks_jelly.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. No `INTERNET` permission.
- 16 KB page-size check: `zipalign -c -P 16 -v 4` → successful; `libflutter.so` LOAD segments are aligned to `0x10000`.
- Native ABIs: `arm64-v8a`, `armeabi-v7a`, `x86_64`.
- R8/minify is active (`min_api: 24`).
- Release signing: `CN=Android Debug`; no project keystore, no `key.properties`.
- AAB reproducibility: two consecutive builds produced the same SHA-256 with the same signing material.

### iOS artifact facts

- Bundle identifier: `studio.jelly.rubiksJelly` (mixed case; must be finalized)
- Version: `1.0.0` build `1`
- Deployment target: 15.0
- Supported: iPhone portrait + landscape; iPad all four orientations
- App-level `PrivacyInfo.xcprivacy`: **missing**
- `ITSAppUsesNonExemptEncryption`: **missing**
- `Flutter.framework` contains its own privacy manifest; that does not replace the app manifest
- Code signing: **not signed**
- Launch screen: default white with a 1×1 transparent `LaunchImage`
- App icon: default Flutter placeholder
- dSYMs: present in the xcarchive
- Local Apple profiles checked: only `tech.zhongbei.pindou` and `top.rwecho.cortexterminal`; no profile for `studio.jelly.rubiksJelly`

### HarmonyOS spike facts

- Toolchain exists and works; `flutter doctor` recognizes the HarmonyOS toolchain and the OpenHarmony emulator.
- The official Flutter SDK does not support OHOS; the installed `flutter-ohos-3.41.9` fork adds `flutter build hap`.
- Startup failure without `DEVECO_SDK_HOME`; setting `DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk` fixes the build.
- Existing pubspec `sdk: ^3.13.5` is incompatible with the OHOS fork’s Dart 3.11.5. Lowering to `>=3.11.0 <4.0.0` in the temp copy allowed `pub get`, clean analyze and 22/22 tests.
- Generated HAP includes `flutter_assets/shaders/jelly_gloss.frag`, but **runtime FragmentProgram support is unverified**.
- Generated OHOS module requests `ohos.permission.INTERNET` by default and declares only `deviceTypes: ["phone"]`.
- No `ohos/` directory in the repo; no ArkTS audio implementation for `studio.jelly/rubiks_jelly_audio`; audio would currently fail silently on OHOS.
- HAP is unsigned. It cannot be installed on the emulator until a Rubik's-specific Harmony signing profile exists.
- Harmony runtime, haptics, shader, DPI, rotation, split-screen and performance are **not yet verified on device**.

## 3. Readiness matrix

| Workstream | Status | What exists | What is missing / blocking | Estimate |
| --- | --- | --- | --- | --- |
| Game code | Ready | 2×2/3×3/4×4, controller, 120 Hz physics, tests | No code blocker found | 0 |
| Brand / trademark | **Blocked** | Product works under working title | “Rubik's” in app, native labels, web, README; no legal clearance | 1–3 days decision + legal |
| iOS release | Partial | Unsigned xcarchive, dSYMs, deployment target | Signing profile, IPA, app privacy manifest, encryption key, icons, launch screen, App Store record, metadata | 4–6 days |
| Android release | Partial | Reproducible AAB, target 36, 16 KB OK, no INTERNET | Production keystore, Play signing, adaptive icon, Android 12 splash, Play record, Data Safety, closed testing | 3–5 days |
| HarmonyOS | Feasible / Partial | OHOS toolchain, emulator, HAP compile, tests pass | In-repo `ohos/`, ArkTS audio, permissions, tablet form factor, signing, runtime QA, store record | 1–2 weeks after decision |
| Store assets | Not ready | 9 documentation screenshots | Exact store sizes, icons, feature graphic, splash, EN/ZH copy, screenshots from release build | 2–3 days |
| Privacy / legal | Not ready | Offline app with no data APIs found | Privacy policy, terms, support page, in-app legal entry, App Store answers, Data Safety, AGC privacy | 2–4 days + legal review |
| CI/CD | Not ready | No Git repo; no workflows/scripts | Git init/remote, build-release.sh, verify-release.sh, tag workflow, secrets policy, artifact retention | 2–4 days |
| QA | Partial | 22 automated tests; simulator screenshots | Real iPhone/iPad, Android phone/tablet, Harmony phone/tablet, release-mode audio/haptics/accessibility/rotation | 3–5 days |
| China mainland | **Blocked / unknown** | Nothing | Software copyright, APP filing, game approval, Chinese legal docs, store qualifications | 4–12+ weeks, external |
| Submission | Not started | None | App Store Connect / Play Console / AGC records and final human approval | 1–2 days after assets |

## 4. Detailed findings

### 4.1 Brand and store identity

- `android:label="Rubik's Jelly"`.
- `CFBundleDisplayName="Rubik's Jelly"`; macOS `PRODUCT_NAME="Rubik's Jelly"`.
- Web title, manifest name, description and Apple web app title use “Rubik's”.
- In-app title is split as “Rubik's” + “Jelly”; the README and screenshots repeat it.
- Bundle identifiers are derived from the working title:
  - iOS/macOS: `studio.jelly.rubiksJelly`
  - Android: `studio.jelly.rubiks_jelly`
  - OHOS template: `studio.jelly.rubiks_jelly`
- There is no evidence that `studio.jelly` is an owned reverse-DNS domain.
- A rename is not a find/replace-only task: it touches native labels, bundle IDs, App Store/Play/AGC records, signing profiles, screenshots, store URLs, privacy docs and tests.

### 4.2 Icons and launch experience

- iOS: default Flutter 1024 icon, default AppIcon set, 1×1 transparent LaunchImage. Flutter’s own iOS archive validation reports both as placeholders.
- Android: default Flutter mipmap launcher icons; no adaptive icon XML, no monochrome layer, no Android 12 `values-v31` splash configuration.
- OHOS: generated template icon; no branded `app_icon`/start-window artwork.
- Web: default generated Flutter favicon/icons.
- This is a hard blocker for a polished store submission; store review may reject placeholder assets or the product may simply look unfinished.

### 4.3 Privacy and data

- Dart code contains no HTTP client, file I/O, shared preferences, analytics or ads.
- Android release contains no `INTERNET` permission.
- The app has no login, account, cloud sync, ads, IAP, or user-generated content.
- No app-level iOS privacy manifest; add `PrivacyInfo.xcprivacy` with no tracking and no collected data, plus required-reason API declarations if any are introduced.
- `ITSAppUsesNonExemptEncryption` is absent. For this offline build, declare `false` after confirming there is no non-exempt encryption.
- Harmony template currently requests `ohos.permission.INTERNET`; remove it unless a future feature truly needs network.
- No in-app privacy policy, terms or support entry exists.

### 4.4 Android release details

- AAB is fully functional but debug-signed. Play Console will reject/flag it for production without a production upload key.
- No `android:allowBackup="false"` and no explicit `android:usesCleartextTraffic="false"`.
- No `android:enableOnBackInvokedCallback` / predictive-back declaration; verify engine behavior on target 36.
- No adaptive icons, no monochrome icon, no Android 12 splash branding.
- No Play Console app record, Data Safety answers, content rating, ads declaration, app access declaration, or closed-testing plan.
- No 512×512 icon or 1024×500 feature graphic.

### 4.5 iOS release details

- No IPA; archive needs a valid distribution certificate and provisioning profile.
- No profile for this bundle was found locally.
- App Store Connect app record and bundle ID registration are unverified.
- No app-level privacy manifest, no encryption declaration, no localized `InfoPlist.strings`.
- Only English strings; no `CFBundleLocalizations` or in-app localization.
- iPhone screenshots 1206×2622 and iPad 1668×2420 are not the expected current App Store marketing sizes.
- No App Store review notes, age rating, category, privacy answers, or TestFlight plan.

### 4.6 HarmonyOS

The technical path is more promising than the initial brief assumed, but it is still a real port.

Recommended **Phase 2 spike conclusion**: use Flutter-OHOS first, with a runtime gate.

- Toolchain is installed; HAP release builds successfully after setting `DEVECO_SDK_HOME`.
- Dart 3.11 compatibility requires lowering `environment.sdk` (and re-running the official toolchain tests/builds).
- Need a Rubik's-specific bundle name, icon, label, version sync and signing profile.
- Need ArkTS MethodChannel host for the existing `studio.jelly/rubiks_jelly_audio` channel; otherwise audio silently degrades.
- Need `ohos.permission.VIBRATE` or platform haptics verification.
- Need tablet / 2-in-1 device types in `module.json5`.
- Need remove `ohos.permission.INTERNET` unless explicitly justified.
- Need verify `FragmentProgram.fromAsset`, CustomPainter performance, 60/120 Hz, split-screen, rotation and text rendering on a signed HAP.
- If shader or performance fails, the CustomPainter fallback must be forced for OHOS; this is acceptable but must be tested.
- Native ArkUI rewrite is the fallback if Flutter-OHOS cannot meet runtime quality; it is a separate 2–4 week workstream.

### 4.7 Store assets

Existing screenshots are useful for documentation but not compliant marketing assets:

| File | Size | Status |
| --- | --- | --- |
| `screenshots/phone.png` | 780×1688 | Not an App Store iPhone marketing size |
| `screenshots/iphone-native.png` | 1206×2622 | 6.3-inch capture; not the expected 6.9/6.5 set |
| `screenshots/ipad-portrait.png` | 1668×2420 | Not the expected 13-inch iPad size |
| `screenshots/tablet.png` | 2048×1536 | Landscape tablet documentation image |
| `screenshots/4x4.png` | 780×1688 | Documentation only |
| `screenshots/expanded-sheet.png` | 780×1688 | Documentation only |
| `screenshots/demo.png` | 780×1688 | Documentation only |
| `screenshots/puddle.png` | 780×1688 | Documentation only |
| `screenshots/twist.png` | 780×1688 | Documentation only |

Missing: Apple 6.9"/6.5"/13" sets, Play phone/tablet screenshots, feature graphic, 512 icon, AppGallery screenshots, localized copy, preview video (optional).

### 4.8 CI/CD and repository

- The directory is a local Git repository; GitHub Actions cannot run until a remote exists.
- No `.github/`, `scripts/`, `store/`, `docs/`, `release.env`, `key.properties`, or release checks.
- `.gitignore` does not currently exclude future release secrets such as `key.properties`, `release.env`, `*.jks`, `*.keystore`, `*.p12`, `*.p8`, `*.mobileprovision`.
- No artifact retention, checksum manifest, version-bump policy, or release checklist.

## 5. Signing / account inventory

This is local evidence only; console access and permissions must still be confirmed by the human.

| Platform | Evidence found | Assessment |
| --- | --- | --- |
| Apple | Team `2VA9TC6SG4`; 3 valid codesigning identities; profiles for Pindou and CortexTerminal | Team exists; no profile for this bundle; App Store Connect record unverified |
| Google | `~/workspace/keys/play-publisher-key.json` exists for another project | Service account may not have access to a new app; no Rubik's upload keystore |
| Huawei | DevEco Studio + OpenHarmony SDK/emulator; a debug signing cert for `dshpocket` exists | Toolchain exists; no Rubik's AppGallery signing profile |
| Secrets | No hardcoded tokens found in source | Good; future `.gitignore` and secret policy still missing |

Do **not** reuse another app’s production signing key. Create new app-specific keys/profiles for this product.

## 6. Risk register

| Risk | Severity | Impact | Mitigation |
| --- | --- | --- | --- |
| “Rubik's” trademark | Critical | Store rejection / takedown / legal | Rename or obtain written legal clearance before submission |
| China game/app licensing | Critical if mainland | Cannot publish in mainland; long lead time | Decide regions first; treat mainland as separate project |
| Harmony runtime quality | High | Port may not meet 120 Hz/gesture/audio quality | Signed-device spike; fallback to CustomPainter; native rewrite only if needed |
| Default icons/splash | High | Looks unfinished; Flutter validator flags | Branded icons/launch screens across iOS/Android/OHOS |
| Play App Signing | Medium | Uploaded AAB not enrollable until console setup | Enroll the app-specific upload key in Play Console |
| IAP not implemented | High | 5×5/6×6 cannot be sold | Implement StoreKit/Play Billing/Huawei IAP and restore |
| No App Store distribution profile | High | No IPA/upload | Create App Store Connect record + profile |
| Missing iOS privacy manifest | High | App Store rejection / compliance gap | Add app-level privacy manifest and encryption declaration |
| No store assets | High | Cannot submit | Exact-size screenshots, feature graphic, copy |
| No Git/CI | Medium | No auditable release | Initialize repo, tag workflow, checksums |
| China qualifications | Critical if mainland | No distribution | Legal/agency track; do not promise date |
| No localization | Medium | Weak AppGallery/China quality | EN + zh-CN metadata and UI audit |

## 7. Recommended execution order

1. Resolve the six decisions in `DECISIONS.md` (brand, regions, Harmony route, monetization, accounts, bundle ID).
2. Freeze the product name and package IDs; update all native labels, bundle IDs and signing profiles.
3. Add app-specific icons and launch screens; add privacy manifest and legal docs.
4. Create production signing assets and build scripts; add release verification.
5. Fix store metadata and capture exact-size screenshots from release builds.
6. Complete Harmony runtime spike and integrate the `ohos/` project.
7. Run real-device QA; then prepare console drafts.
8. Human review and manual submission only after all checks pass.

## 8. What can proceed before the decisions

Safe groundwork that does not require the final name or bundle ID:

- Draft privacy policy / terms / support content and review checklist.
- Design the icon/splash direction and export a draft 1024 icon.
- Add parameterized build/verify scripts.
- Add release secret ignore rules.
- Prepare exact-size screenshot capture tooling.
- Document store field mappings.
- Prepare a CI skeleton with placeholder identifiers.

Do not finalize bundle IDs, signing profiles, store records, icons with the working title, or any submission package until the name/IP and regional decisions are confirmed.

## 9. Definition of “audit closed”

This audit closes when:

- `DECISIONS.md` is signed off.
- The name/package decisions are recorded.
- Android signing assets exist and are app-specific; iOS distribution profile still missing.
- Default icon/launch placeholders are gone.
- App-level privacy manifest and legal pages exist.
- Exhibition-ready store asset set exists.
- Release builds are reproducible and verified.
- Harmony runtime is either verified on a signed device or explicitly deferred.

Until then, the repository remains **not submittable**.
