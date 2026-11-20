# Jelly Cube 3D (Cocos Creator 3.8.6)

由原 Flutter 版（`Rubik's Jelly`）重构升级为 **Cocos Creator 3.8.6 真 3D GPU 果冻魔方**，首发目标 **iOS / Android（AdMob + 原生震动）**，次之 **微信小游戏 / Web**。

## 目录结构

- `assets/effects/jelly-cubelet.effect` — 自定义 GPU 果冻着色器（顶点按压凹陷、切片晃动、落地挤压变形、菲涅尔边缘光、次表面散射）。
- `assets/scripts/core/` — 纯 TypeScript 核心逻辑（零引擎依赖，可通过 `npm test` 独立单测）：
  - `JellyEngine.ts`：离散整数晶格魔方引擎（2×2 / 3×3 / 4×4、Undo、智能 Hint、图案校验）。
  - `JellyLevels.ts`：30 关残局渐进关卡（1~2 步新手引导 → 图案挑战 → 4×4 试炼）+ 每日甜品挑战。
  - `JellySkins.ts`：6 套可解锁甜品果冻材质图鉴（经典水果冻、水晶琉璃冻、焦糖奶盖布丁、宇治抹茶红豆、气泡霓虹苏打、星空夜光冻）。
  - `JellyStorage.ts`：跨平台本地存档。
- `assets/scripts/view/` — 3D 渲染与弹簧阻尼物理（`JellyCubeView.ts`、`JellyCameraRig.ts`、`JellyMeshFactory.ts`）。
- `assets/scripts/platform/` — 跨平台桥接（`PlatformBridge.ts` 对接 iOS/Android AdMob、微信 `wx`、Web；`JellyAudio.ts` 零资源 WebAudio 合成音效）。
- `assets/scripts/ui/` — 游戏主控与响应式 HUD（`JellyGameController.ts`、`JellyHUD.ts`）。

## 在 Cocos Creator 3.8.6 中运行

1. 用 **Cocos Creator 3.8.6** 打开 `/Users/echo/workspace/CocosGames/JellyCube3D`。
2. 在主场景的 `Canvas` 节点上挂载 `JellyBootstrap` 组件，并将 `assets/effects/jelly-cubelet.effect` 拖入其 `jellyEffect` 属性槽。
3. 点击预览即可在浏览器中直接试玩（支持拧方块、转视角、戳果冻、弹一下、关卡残局、每日挑战、图鉴解锁）。

## 校验与单测

```bash
npm test
```

## iOS / Android 上架与 AdMob 信息（同步自 Flutter 原版）

- **Bundle ID / Application ID**：`tech.zhongbei.jellycube3d`（Apple Team ID：`2VA9TC6SG4`）
- **AdMob App ID**：
  - iOS (`GADApplicationIdentifier`)：`ca-app-pub-2271052258925299~4315636529`
  - Android (`APPLICATION_ID`)：`ca-app-pub-2271052258925299~2443463295`
- **AdMob Unit ID**：
  - iOS Banner：`ca-app-pub-2271052258925299/9110787308`（已写入 `native/ios/AdMobBridge.mm`）
  - iOS Rewarded：`ca-app-pub-2271052258925299/2302936450`（已写入 `native/ios/AdMobBridge.mm`）
  - iOS Interstitial：`ca-app-pub-2271052258925299/7327585319`（已写入 `native/ios/AdMobBridge.mm`，带 60s 冷却）
  - Android Banner：`ca-app-pub-2271052258925299/4611149991`（已写入 `native/android/AdMobBridge.java`）
  - Android Rewarded：`ca-app-pub-2271052258925299/9079650680`（已写入 `native/android/AdMobBridge.java`）
  - Android Interstitial：`ca-app-pub-2271052258925299/9929697921`（已写入 `native/android/AdMobBridge.java`，带 60s 冷却）
- **隐私政策 URL**：`https://auth.zhongbei.tech/legal/privacy?app=jellycube3d&locale=en-US`
- **客服邮箱**：`support@zhongbei.tech`
- `PlatformBridge.ts` 已预留 `native.reflection.callStaticMethod` 调用协议：
  - **iOS**：`native/ios/AdMobBridge.mm`（含 AdMob + `SKStoreReviewController` 商店评价）与 `native/ios/HapticsBridge.mm`。
  - **Android**：`native/android/AdMobBridge.java`（含 AdMob + Google Play 商店评价跳转）与 `native/android/HapticsBridge.java`。
