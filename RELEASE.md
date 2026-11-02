# Release Runbook — Jelly Cube 3D

Status: **DRAFT / NOT READY TO SUBMIT**
No command in this repository uploads or publishes to a store. The final submission is a human action.

## 0. Preconditions

- [ ] `DECISIONS.md` signed off
- [ ] final name and identifiers frozen
- [ ] app-specific signing assets obtained (see `ACCOUNTS_AND_SIGNING.md`)
- [ ] IAP product created and tested in sandbox
- [ ] `./tool/test.sh` passes
- [ ] `flutter analyze` is clean
- [ ] `scripts/verify-release.sh` passes
- [ ] exact-size store screenshots captured from release builds
- [ ] privacy/support URLs deployed
- [ ] store app records created

## 1. Build artifacts

```bash
cp release.env.example release.env   # fill non-secret values
# signing files must be outside the repo / in keychain / CI secrets

# Xcode 27.1 note: Flutter's IPA export can fail at
# IDEDistributionCreateIPAStep because openrsync rejects
# --extended-attributes. build-release.sh recovers the
# already-distribution-signed pipeline payload and zips the IPA.

./scripts/build-release.sh android
./scripts/build-release.sh ios
./scripts/build-release.sh harmony
# or: ./scripts/build-release.sh all

./scripts/verify-release.sh
```

Artifacts land under `build/release/<version>+<build>/`:

- `jelly-cube-3d.aab`
- `jelly-cube-3d.ipa`
- `jelly-cube-3d.hap`
- SHA-256 files and symbol directories

## 1a. Deploy legal/support pages

Publish `store/site/jellycube3d/` at the final `https://zhongbei.tech/jellycube3d/` paths, replace `[LEGAL ENTITY]`, and verify the URLs before store submission. See `store/site/README.md`.

## 2. Apple App Store

1. Create the App Store Connect app record for `tech.zhongbei.jellycube3d`.
2. Create the non-consumable IAP `tech.zhongbei.jellycube3d.extra_types`; set price and localization.
3. Upload the signed IPA with Transporter or `xcrun altool`.
4. Wait for processing; add the build to TestFlight.
5. Fill:
   - App Privacy: Data Not Collected; no tracking.
   - Age rating: 4+.
   - Category: Games > Puzzle.
   - Screenshots: 6.9", 6.5", iPad 13" sets.
   - Review notes: no login; offline gameplay; IAP details; restore instructions.
6. Test the IAP and Restore Purchases in TestFlight sandbox.
7. Submit for review only after human sign-off.

Reference copy: `store/listing-en.md`, `store/listing-zh-Hans.md`; fastlane-style drafts are under `store/apple/metadata/` and `store/google/metadata/`.

## 3. Google Play

1. Create the Play Console app record for `tech.zhongbei.jellycube3d`.
2. Enroll in Play App Signing with a fresh upload key for this app.
3. Upload the signed AAB to Internal testing.
4. Create the in-app product and activate it.
5. Complete:
   - Data Safety: no developer collection/sharing.
   - Content rating questionnaire.
   - Ads declaration: no ads.
   - App access: no login.
   - Target audience: general audience; not child-directed.
6. Run closed testing under the current account policy, then production.
7. Roll out in stages; human approves each stage.

## 4. Huawei AppGallery

1. Create the AGC app `tech.zhongbei.jellycube3d`.
2. Add the Harmony signing certificate/profile and update `ohos/build-profile.json5`.
3. Build a signed HAP via `scripts/build-release.sh harmony`.
4. Upload to AppGallery Connect testing.
5. Complete privacy, age rating, screenshots, device support and region settings.
6. If selling 5×5/6×6 on HarmonyOS, configure Huawei IAP Kit and test restore.
7. Submit only after human sign-off.

Local note: hvigor rejects an apostrophe in the project path. Build Harmony from CI or use the staging logic in `scripts/build-release.sh`.

## 5. Versioning

- Source of truth: `pubspec.yaml` `version: x.y.z+build`.
- Every store upload needs a new build number, even for identical marketing versions.
- Tag releases as `vX.Y.Z+N` after the store build is verified.
- Do not reuse a build number after upload, even if the build was rejected.

## 6. Rollback

- Apple: stop the phased release; use App Store Connect to select the previous version for sale if necessary.
- Google Play: halt rollout; previous production release remains available to users who have not updated.
- AppGallery: withdraw the release / restore the previous version in AGC.
- Never attempt to rollback by uploading a package with a lower version code; publish a new higher build.

## 7. Submission approval

Before pressing Submit/Publish:

- [ ] store listing reviewed by a human
- [ ] screenshots show the current build and brand
- [ ] IAP product/price and restore flow verified
- [ ] no placeholder icon, name, URL or email
- [ ] no debug symbols/debug signing
- [ ] support inbox monitored
- [ ] privacy policy matches actual data behavior
- [ ] regional list confirmed (mainland China excluded for v1)
