# Jelly Cube 3D — Objective Status

**Status: BLOCKED ON EXTERNAL SIGNING / STORE ACCOUNTS — NOT STORE-SUBMITTED**

The repository has been taken from the runnable demo to signed iOS/Android
artifacts, a complete release audit, store assets/metadata, legal drafts, CI and
HarmonyOS runtime evidence. Store submission cannot proceed without credentials
and signing material that only the account owner can provide.

## Evidence (2026-11-02)

```text
flutter analyze                  clean
./tool/test.sh                   30/30 passed
tool/check_store_assets.py       PASS
scripts/verify-release.sh        iOS PASS / Android PASS / HarmonyOS FAIL (unsigned HAP)
```

Release artifacts:

| Artifact | Size | SHA-256 |
| --- | ---: | --- |
| `jelly-cube-3d.ipa` | 6.9 MB | `490dc786ceba4a9296bc36658a5698a7d74b55cbadcce7c0bc79a9a2d2ed417b` |
| `jelly-cube-3d.aab` | 45 MB | `e01078dbba8aacac91c2f99e6a18a6813de8907bcf5787d88566c2dd974f9adc` |
| `app-release.apk` | 48 MB | `491992eeb1d1d3b70fa6c831307a810345565dfa4c6d82516e5af115b88cf0c7` |
| `entry-default-unsigned.hap` | 21 MB | `b76f10f3ef1962bbcf3b76af0a2a2f6a9ffce779e070cab6a44c6d2e8d44e3ae` |

- iOS IPA: Apple Distribution signed, App Store provisioning profile,
  `get-task-allow=false`, app privacy manifest present.
- Android AAB/APK: app-specific upload key, target SDK 36, 16 KB aligned,
  Play-Billing-only INTERNET.
- HarmonyOS: unsigned HAP installs/runs; a local OpenHarmony-test-CA debug-signed
  HAP also installs/runs. **Not AppGallery-valid.**
- Store screenshots: Apple 6.9/6.5/iPad 13, Google phone/tablet, AppGallery
  emulator set. `tool/check_store_assets.py` passes.
- Legal/support: deployable pages under `store/site/jellycube3d/`; not hosted.
- Tag-driven GitHub Release: `.github/workflows/release.yml` + secret table in
  `RELEASE.md`.
- 30 automated tests, including IAP purchase/restore/cancel fakes and responsive
  320/390/834/1024 + 1.3× text-scale layouts.

## Exact blockers

1. **AppGallery signing** — Huawei-issued `.p12` / `.cer` / `.p7b` and profile
   password. The current HAP is unsigned; local test signing is not accepted by
   AppGallery.
2. **Store console access / IAP products** — App Store Connect, Play Console and
   AGC app records; Play App Signing enrollment; `extra_types` product creation;
   sandbox purchase/restore.
3. **Git remote / secrets** — no remote is configured, so the tag release
   workflow and CI have not actually run.
4. **Physical QA** — no physical iPhone/iPad, Android or HarmonyOS devices were
   available; simulator/emulator smoke only.
5. **Legal identity / hosting** — `[LEGAL ENTITY]` placeholder and final
   `https://zhongbei.tech/jellycube3d/...` hosting are not deployed.

## Required to unblock

- Huawei AppGallery signing certificate/profile and password.
- App Store Connect, Play Console and AGC access, plus the IAP price/display name.
- A Git remote and the Actions secrets listed in `RELEASE.md`.
- Physical test devices.
- Confirmed legal entity and hosted privacy/support URLs.

## What remains after unblocking

1. Build/sign the AppGallery HAP and install on a signed Harmony device.
2. Create products and run sandbox purchase/restore on all stores.
3. Verify console records, Play App Signing and App Store upload.
4. Run physical-device QA.
5. Human approval, then submit — never automatic.

**No App Store, Google Play or AppGallery submission was made.**
