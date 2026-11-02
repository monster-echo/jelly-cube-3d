# Huawei AppGallery — Jelly Cube 3D

Status: **PREPARATION / NOT SUBMITTED**

## Identifiers

- App name: Jelly Cube 3D
- Bundle name: `tech.zhongbei.jellycube3d`
- Distribution: global, excluding mainland China for v1
- IAP: Huawei IAP Kit only if 5×5/6×6 are sold on HarmonyOS; not implemented yet

## Inputs needed

- [ ] Huawei Developer account / AppGallery Connect app record
- [ ] Harmony signing certificate + profile + private key
- [ ] App icon (can reuse `branding/app_icon_1024.png`)
- [ ] Harmony phone/tablet screenshots
- [ ] Privacy policy and support URLs
- [ ] Age rating and content declarations
- [ ] AppGallery IAP Kit setup (if applicable)

## Build

```bash
# after signing config is present in ohos/build-profile.json5
./scripts/build-release.sh harmony
```

The local checkout path contains an apostrophe; the build script stages the
project into `/tmp` because hvigor rejects `'` in project paths.
