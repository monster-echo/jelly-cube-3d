# Accounts and Signing Checklist — Jelly Cube 3D

Status: **OPEN**
Purpose: collect the minimum accounts, legal identity and signing material required for App Store, Google Play and AppGallery.

Do not commit any private key, keystore, certificate, provisioning profile, API key or password. Store them in a password manager / CI secret store.

## 1. Apple App Store

### Account

- [ ] Apple Developer Program membership active (organization or individual)
- [ ] Legal entity / seller name matches tax records
- [ ] App Store Connect access for the release owner
- [ ] Agreements, tax and banking completed
- [ ] App Store Connect app record created for `tech.zhongbei.jellycube3d`
- [ ] IAP product created and approved in App Store Connect

### Signing

- [x] Apple Distribution identity exists in the keychain
- [x] App Store distribution provisioning profile for `tech.zhongbei.jellycube3d` (created by Xcode automatic signing)
- [x] Distribution-signed IPA built locally
- [ ] App Store Connect app record / upload verified in the console
- [ ] App Store Connect API key for CI (Issuer ID + Key ID + `.p8`)
- [ ] Team ID confirmed: `2VA9TC6SG4`
- [ ] Xcode archive + export tested with the production profile
- [ ] TestFlight internal tester group ready

### Product

- [ ] Non-consumable IAP: `tech.zhongbei.jellycube3d.extra_types`
- [ ] Price tier chosen
- [ ] Localized display name/description for the IAP
- [ ] Review screenshot showing the locked 5×5 / 6×6 content and unlock screen
- [ ] Restore Purchases implemented and tested

## 2. Google Play

### Account

- [ ] Google Play Console developer account active
- [ ] Identity verification completed
- [ ] App record created for `tech.zhongbei.jellycube3d`
- [ ] Play App Signing enrolled
- [ ] In-app product created for the extra cube types
- [ ] Closed testing track configured (current policy for new personal accounts applies)

### Signing

- [x] New upload keystore generated specifically for Jelly Cube 3D
  - Path: `~/workspace/keys/jelly-cube-3d-upload.jks` (outside repo)
  - Alias: `jelly-cube-3d`
  - Certificate SHA-256: `348812004cde1844965c85cd60d8f62e57d3ecb15513088125fa515ab7877a96`
  - Password: `~/workspace/keys/jelly-cube-3d-upload-password.txt` (600)
- [x] `android/key.properties` configured locally (gitignored)
- [x] Signed AAB/APK verified with `apksigner`
- [ ] Back up the keystore + password in a secure password manager
- [ ] Register the upload key in Play Console / enroll Play App Signing
- [ ] Store keystore + passwords in CI secrets

Do **not** reuse the Pindou upload key. Create a new key for this product.

### Product

- [ ] Billing permission only from Play Billing library
- [ ] Product ID: `tech.zhongbei.jellycube3d.extra_types`
- [ ] Price and country availability set
- [ ] Restore purchases tested after reinstall and on a second device
- [ ] Data Safety and IAP declarations completed

## 3. Huawei AppGallery / HarmonyOS

### Account

- [ ] Huawei Developer account with real-name verification
- [ ] AppGallery Connect organization/team access
- [ ] App record created for `tech.zhongbei.jellycube3d`
- [ ] AppGallery region list configured (mainland China excluded for v1)
- [ ] HarmonyOS IAP Kit product if extra types are sold on HarmonyOS

### Signing

- [ ] Harmony app signing certificate (`.cer`)
- [ ] Harmony signing profile (`.p7b`)
- [ ] Private key (`.p12`) with password
- [ ] `DEVECO_SDK_HOME` configured for CI
- [ ] Signed `.app`/`.hap` tested on a HarmonyOS device
- [ ] `hdc install` verification

### Technical

- [ ] `ohos/` project committed
- [ ] ArkTS audio channel implemented
- [ ] `ohos.permission.INTERNET` removed unless a future feature needs it
- [ ] `deviceTypes` includes phone + tablet/2-in-1
- [ ] Shader fallback verified
- [ ] Haptics permission/behavior verified
- [ ] App icon, start window, app label replaced

## 4. Shared secrets policy

Local:

```text
android/key.properties
release.env
*.jks
*.keystore
*.p12
*.p8
*.cer
*.mobileprovision
*.provisionprofile
```

CI secrets:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
APPLE_TEAM_ID
APPLE_API_KEY_ID
APPLE_API_ISSUER_ID
APPLE_API_PRIVATE_KEY
APPLE_DISTRIBUTION_CERT_P12
APPLE_DISTRIBUTION_CERT_PASSWORD
APPLE_PROVISIONING_PROFILE
HARMONY_SIGNING_CERT
HARMONY_SIGNING_PROFILE
HARMONY_SIGNING_KEY
HARMONY_SIGNING_KEY_PASSWORD
```

## 5. Current local evidence (not proof of account access)

- Apple team ID `2VA9TC6SG4` is present in the Xcode project.
- 3 valid codesigning identities were found.
- Provisioning profiles found locally belong to other products; none match `tech.zhongbei.jellycube3d`.
- A Google Play publisher key exists for another project; access to a new app is unverified.
- DevEco Studio 26 and an OpenHarmony 7 emulator are installed.
- A Harmony debug certificate exists for another bundle; do not reuse it.
- No Jelly Cube 3D release keystore, App Store profile, or Harmony signing profile exists in the repo.

## 6. Order of operations

1. Create the final app records in all three consoles.
2. Create app-specific signing material.
3. Register the IAP product.
4. Store secrets in local keychain / CI.
5. Build signed artifacts with `scripts/build-release.sh`.
6. Verify with `scripts/verify-release.sh`.
7. Upload to internal testing tracks only.
8. Human approval before production release.
