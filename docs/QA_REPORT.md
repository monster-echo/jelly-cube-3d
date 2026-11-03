# QA Report — Jelly Cube 3D

Status: **AUTOMATED TESTS PASS; REAL-DEVICE RELEASE QA NOT RUN**

Audit date: 2026-11-02

## Automated

| Check | Result |
| --- | --- |
| `flutter analyze` | PASS |
| `./tool/test.sh` | 31/31 PASS |
| 10,000-turn engine integrity | PASS |
| 10,000 controller moves | PASS |
| `(R U R' U') × 6` solved | PASS |
| 2×2 through 6×6 drags/shell counts | PASS |
| Drop physics / multi-touch smoke | PASS |
| Manual hand-solve melt trigger | PASS |
| Audio PCM finite/bounded | PASS |
| CanvasKit web release build | PASS |
| Wasm web release build | PASS |
| Android release AAB build | PASS (app-specific upload signing) |
| iOS distribution IPA | PASS (Apple Distribution signed; not uploaded) |
| HarmonyOS HAP compile | PASS (unsigned, sanitized path, IAP dependencies included) |
| 5×5/6×6 shell/controller paths | PASS |
| IAP locked/unlocked UI compile | PASS |
| IAP fake-platform purchase/restore/cancel tests | PASS (5 tests) |
| Responsive layouts + 1.3× text scale | PASS (320/390/834/1024) |
| Opposite touch drags commit opposite turns | PASS |

## Runtime smoke results (simulators/emulators)

| Target | Result |
| --- | --- |
| iPhone 18 Pro simulator (iOS 27) | Launch PASS; responsive phone layout; 5-size locked selector renders |
| iPad Pro 11-inch simulator (iOS 27) | Launch PASS; tablet card and 5-size selector render |
| Android emulator 1080×2400 | Signed release APK installs and launches |
| OpenHarmony 7 emulator 1280×2832 | Unsigned HAP installs/launches; local debug-signed HAP installs/launches; drag/tool bar PASS; HARMONY build hides 5×5/6×6 PASS |

Not covered by this smoke test: physical devices, sandbox purchase, StoreKit sheet,
audio, haptics, rotation/split-screen, signed Harmony HAP.

## Required real-device matrix

- [ ] iPhone (ProMotion 120 Hz)
- [ ] iPhone (60 Hz / smaller screen)
- [ ] iPad (portrait, landscape, Split View / Slide Over)
- [ ] Android phone (60/120 Hz)
- [ ] Android tablet / foldable
- [x] HarmonyOS phone (OpenHarmony 7 emulator, unsigned HAP: launch + drag/tool bar)
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
- [ ] IAP sandbox: buy, cancel, pending, restore, reinstall (client UI and local StoreKit config exist; product/console pending)
- [ ] upgrade install over previous build
- [ ] store review screenshot audit

## Known blockers

- App Store TestFlight upload succeeded for `v1.0.1+3`; review submission and IAP product setup remain manual.
- Play App Signing enrollment / Play Console app record pending (local upload key exists).
- HarmonyOS unsigned HAP runs on the emulator; signed HAP still required for AppGallery.
- Store products and sandbox purchase/restore testing are still pending; Huawei IAP Kit is not implemented.
- AppGallery screenshots captured from the OpenHarmony 7 emulator; replace if the console requires a different resolution.
- No real-device QA executed in this audit.
