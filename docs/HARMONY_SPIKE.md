# HarmonyOS Spike Report — Flutter-OHOS

Date: 2026-11-02
Status: **Host integrated; compile/tests pass; runtime verified on the OpenHarmony emulator; store signing pending**
Target: HarmonyOS NEXT / OpenHarmony 7 (API 26)

## Toolchain found on this machine

| Tool | Version / path |
| --- | --- |
| Flutter-OHOS | 3.41.10-ohos-0.0.4-dev at `/Users/echo/flutter-ohos-3.41.9` |
| Dart | 3.11.5 |
| DevEco Studio | 26.0.0 |
| OpenHarmony SDK | `/Applications/DevEco-Studio.app/Contents/sdk` |
| Emulator | `127.0.0.1:5557`, OpenHarmony 7.0.0.105 (API 26) |
| hvigor / ohpm | 6.26.8 / 26.0.0.630 |

## Commands that worked

The spike was performed in `/tmp/rj_ohos_spike`. A branded `ohos/` host is now committed under `ohos/`, and the release build was verified again from a sanitized path.

```bash
# with Dart 3.11 compatibility in the temp copy
sdk: ">=3.11.0 <4.0.0"

flutter-ohos pub get
flutter-ohos analyze          # clean
flutter-ohos test             # 29/29 passed

export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk
flutter-ohos build hap --debug --no-codesign
# → entry-default-unsigned.hap (92 MB)

flutter-ohos build hap --release --no-codesign
# → entry-default-unsigned.hap (21.2 MB)
```

Important: without `DEVECO_SDK_HOME`, hvigor fails with:
`Invalid value of 'DEVECO_SDK_HOME' in the system environment path`.

## Findings

- The current `environment.sdk: ^3.13.5` is incompatible with Flutter-OHOS/Dart 3.11.5. Lowering to `>=3.11.0 <4.0.0` allows analyze and tests to pass.
- The generated OHOS project compiles the `jelly_gloss.frag` shader asset, but **runtime FragmentProgram support is not yet verified**.
- The generated template requested `ohos.permission.INTERNET`; it has been removed from the committed host.
- Device types are now `phone`, `tablet`, and `2in1`.
- No ArkTS host exists yet for `tech.zhongbei/jellycube3d_audio`; audio will silently degrade on OHOS until implemented.
- The AppGallery release build uses `--dart-define=HARMONY=true` to hide the paid 5×5/6×6 selector, because Huawei IAP Kit is not implemented. v1 AppGallery is 2×2–4×4 only.
- Haptics require verification against the OHOS platform channel / vibrator.
- The unsigned HAP installs and launches on the OpenHarmony 7 emulator (`hdc install`), which is useful for runtime QA. A signed HAP is still required for AppGallery.
- Runtime verified: launch, custom icon/launch window, 3×3 jelly render, drag turn, tool bar, hint/toast and responsive phone layout. Screenshots are in `store/huawei/screenshots/phone`.
- Verified on the free-only HARMONY build: only 2×2/3×3/4×4 are shown; no dead paid lock.
- Not yet verified: signed install, audio, haptics, shader path, tablet/split-screen, IAP.
- **Local path restriction:** hvigor rejects an apostrophe in the project path. This checkout is `/Users/echo/workspace/Rubik's Jelly`; use `scripts/build-release.sh harmony` (which stages to `/tmp`) or a CI checkout path without `'`.
- A signed runtime test is still required for:
  - app launch and rendering
  - shader support / fallback
  - 60/120 Hz and frame pacing
  - touch gestures / multi-touch
  - audio and haptics
  - rotation / split-screen / tablet layout
  - app icon and launch window
  - memory and release size

## Recommendation

Use **Flutter-OHOS first**. The test and compile results are strong enough to proceed.

Blockers before AppGallery submission:

1. ~~Add `ohos/` to the real repo.~~ Done (`ohos/`).
2. ~~Remove `ohos.permission.INTERNET`; add the correct device types.~~ Done.
3. Add ArkTS audio host for the existing PCM channel.
4. Add Harmony signing profile and signed HAP build.
5. Verify on a signed device/emulator (unsigned emulator launch already passes).
6. Add AppGallery IAP Kit support if 5×5/6×6 are sold on HarmonyOS.
7. Run AppGallery QA and prepare store metadata.

If runtime quality fails, force the CustomPainter fallback for OHOS. A native ArkUI rewrite is a separate project, not a packaging shortcut.
