# HarmonyOS local signed-HAP test

Status: **local runtime QA only — not an AppGallery signing profile**

The OpenHarmony SDK ships a test P12 (`OpenHarmony.p12`, default password
`123456`) and `hap-sign-tool.jar`. We used them to create a Jelly Cube 3D
debug profile, sign the HAP, and install it on the OpenHarmony 7 emulator.

## Evidence

- Emulator UDID: `454D5504D4143041524D03D240113A1CC4ECE9E3416FB61A5ACC100000000000`
- Signed HAP: `build/ohos/local/jelly-local-signed.hap` (22 MB)
- `hdc install -r` → `install bundle successfully`
- App launch → PASS
- This proves the packaging/signing pipeline and profile structure.

## Important

This uses the **OpenHarmony test CA**, not a Huawei-issued AppGallery
certificate. It is **not** acceptable for AppGallery submission. For store
release, replace the test P12/cert/profile with the AppGallery assets from AGC
and rebuild via `scripts/build-release.sh harmony`.

## Materials

- `DEVECO_SDK_HOME/default/openharmony/toolchains/lib/OpenHarmony.p12`
- `.../hap-sign-tool.jar`
- `.../UnsgnedDebugProfileTemplate.json`
- Emulator UDID from `hdc shell bm get --udid`

The local profile is debug type and includes the emulator UDID. A release
profile for AppGallery must be issued by Huawei and must not include a debug
device allow-list.
