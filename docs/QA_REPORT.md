# QA Report — Jelly Cube 3D

Status: **AUTOMATED TESTS PASS; REAL-DEVICE RELEASE QA NOT RUN**

Audit date: 2026-11-02

## Automated

| Check | Result |
| --- | --- |
| `flutter analyze` | PASS |
| `./tool/test.sh` | 22/22 PASS |
| 10,000-turn engine integrity | PASS |
| 10,000 controller moves | PASS |
| `(R U R' U') × 6` solved | PASS |
| 2×2/3×3/4×4 drags | PASS |
| Drop physics / multi-touch smoke | PASS |
| Manual hand-solve melt trigger | PASS |
| Audio PCM finite/bounded | PASS |
| CanvasKit web release build | PASS |
| Wasm web release build | PASS |
| Android release AAB build | PASS (debug signed) |
| iOS unsigned archive | PASS (not signed/no IPA) |
| HarmonyOS HAP compile | PASS (unsigned, sanitized path) |

## Required real-device matrix

- [ ] iPhone (ProMotion 120 Hz)
- [ ] iPhone (60 Hz / smaller screen)
- [ ] iPad (portrait, landscape, Split View / Slide Over)
- [ ] Android phone (60/120 Hz)
- [ ] Android tablet / foldable
- [ ] HarmonyOS phone
- [ ] HarmonyOS tablet
- [ ] Low-memory / low-end Android

## Required scenarios

- [ ] release-mode cold launch
- [ ] app background/foreground during a turn
- [ ] audio interruption (call/route change) and mute
- [ ] device silent switch and system haptics settings
- [ ] pinch zoom + two-finger orbit while a slice is active
- [ ] edge back gesture / Android predictive back
- [ ] rotation during active play
- [ ] iPad Split View at <600 dp width
- [ ] VoiceOver / TalkBack pass
- [ ] text scaling at 1.2×/1.3×
- [ ] offline launch (gameplay)
- [ ] IAP sandbox: buy, cancel, pending, restore, reinstall
- [ ] upgrade install over previous build
- [ ] store review screenshot audit

## Known blockers

- No signed iOS IPA.
- No production Android signing.
- No signed HarmonyOS HAP.
- No IAP implementation yet.
- No exact store-size screenshot set.
- No real-device QA executed in this audit.
