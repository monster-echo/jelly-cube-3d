# Jelly Cube 3D — working memory

Cocos Creator 3.8.6 puzzle game (iOS, Android later). Repo: `CocosGames/JellyCube3D`.
TS gameplay + code-drawn UI; native iOS template lives in `native/ios/` and is injected by
`tools/build_ios.sh` (the `native/engine/ios/` copy is generated, never edit it directly).

## Build / install

- Store IPA: `STAGE=ipa ./tools/build_ios.sh` → `export/ios/jellycube3d-<version>.ipa`.
- `STAGE=ipa` re-runs `cocos_build`, which **regenerates the iOS template**, so every durable
  native change must live in `native/ios/` and be copied by the script after the build
  (bridges, launch image, plist patches, CMake patches).
- Dev install (Ad Hoc): archive with `xcodebuild -workspace build-ios-native/ios/proj/jellycube3d.xcworkspace
  -scheme jellycube3d-mobile ... CODE_SIGN_IDENTITY='Apple Development'`, export with
  `/tmp/jelly-dev-export.plist`, then before installing:
  1. `CFBundleShortVersionString` / `CFBundleVersion` from `release/version.json`.
  2. Force portrait: replace both `UISupportedInterfaceOrientations` arrays with
     `UIInterfaceOrientationPortrait`, set `UIRequiresFullScreen` (the CMake plist is landscape).
  3. Rebuild `Assets.car` + `AppIcon*` with `actool` from `.tmp/appicon` (dev exports otherwise
     ship the Cocos default flame icon), set `CFBundleIcons`.
  4. `codesign --force --sign "Apple Development: Zhenwei Ruan (45R65RT6JP)" --preserve-metadata=...`
- Export must run with `PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"` (Homebrew rsync lacks
  `--extended-attributes`); `pod install` needs `LANG/LC_ALL=en_US.UTF-8`.
- iPhone 12 UDID `00008101-001661183E40001E`. Install: `xcrun devicectl device install app
  --device <udid> <app>`; launch with `--terminate-existing`.
- Screenshot the phone: `xcrun devicectl device capture screenshot --device <udid> --destination x.png`.
- Crash logs: `xcrun devicectl device copy from --device <udid> --domain-type systemCrashLogs
  --source / --destination <dir>`.

## Launch-argument QA hooks (native, via NSUserDefaults)

- `-jellyAutoLevel 7` boots straight into a level.
- `-jellyAutoScreen menu|skins|levels|leaderboard|pause|hint|tutorial` opens a sheet.
- `-jellyAutoAd 1` triggers a rewarded ad at +4 s and +10 s (verifies the ad bridge).
- Pass args after `--`: `devicectl ... launch <bundle> -- -jellyAutoLevel 7` (occasionally the
  first launch races; retry without `--terminate-existing`).

## Crashes already fixed (do not regress)

- App Review 2.1(a) crash: iOS 26+ requires `UIApplicationSceneManifest` + SceneDelegate
  (`UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`).
- ATT crash: `AdMobBridge` must not call `requestTrackingAuthorization` without
  `NSUserTrackingUsageDescription`; the bridge no longer requests it (non-personalized ads).
- "Watch Ad" crash: `AdMobBridge.mm` is ARC-style but the CMake project compiles without ARC,
  so `_rewardedAd`/`_interstitialAd` were stale pointers (`doesNotRecognizeSelector` / PAC
  SIGSEGV). `build_ios.sh` sets `-fobjc-arc` for that one file.
- Progress reset every launch: `window.localStorage` does not exist in the native runtime;
  `JellyStorage` must use `cc.sys.localStorage`.
- Silent phone: Web Audio does not exist on native; SFX/music are bundled WAVs in
  `assets/resources/audio/` played through pooled `cc.AudioSource`s (no `playOneShot` churn),
  `AVAudioSessionCategoryPlayback`. The synth path is only for desktop preview.
- HUD Graphics not drawing in-game: native keeps a stale mesh when a HUD root is activated
  after the first frame; `_redrawGraphics` replays the stored draw commands on activation.
- Ad banner over the dock: banner is home-only and never under a modal; the home card reserves
  its 50pt strip. It is hidden while a level is running.

## UI conventions

- Design tokens came from the deleted web build (`web/style.css`): purple `#7448f5`,
  ink `#34223e`, gold `#ffe8a8`, card `#f2eaf8`, radii 26/18/14, CSS px scaled by `W / logicalWidth`.
- Home: top-left `☰ Menu`, coins top-right, hero title, then Play / Daily / Global Ranks.
  Skins, share, rate, sugar ad, legal links live in the Menu sheet.
- In-game: top bar `Level ▾ | ⟳ | 🍬 | ❚❚`; move count + timer on a second row; bottom dock
  Undo / Hint / Tutorial. The pause pill is a fixed 40pt circle.
- Camera: play mode ignores drags that miss the cube; the `⟳` toggle switches to orbit-only
  mode (button turns purple, toast, resets when a level starts).
- Keep layouts inside the safe area (`sys.getSafeAreaRect(false)`); never hardcode y offsets
  from the screen top.

## Repo hygiene

- `release/version.json` is the single source of version/build numbers (2.0.3 / 263120106 at
  the time of writing). The store IPA is rebuilt by `tools/build_ios.sh`.
- Another session/agent may edit this repo concurrently. Check `git status` and `git log`
  before committing; never `git checkout`/reset files you did not touch, and don't run
  `git add -A` over unknown modifications.
- Assets with .meta files must be committed together (UUIDs are referenced by scenes/scripts).
- `.tmp/appicon` (real 1024 icon) is generated by the packaging step; brand source icon:
  `/Users/echo/workspace/Rubik's Jelly/branding/app_icon_1024.png`.
- Old Flutter app (1.x) lives at `/Users/echo/workspace/Rubik's Jelly`; it is not shipped anymore.
