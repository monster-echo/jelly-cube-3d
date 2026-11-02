/// Jelly Cube 3D — a zero-asset, soft-body twisty puzzle for Flutter.
///
/// The public surface is intentionally small:
///  * [JellyCubeApp] — the app / instrument.
///  * [JellyCubeController] — the full automation and test hook.
///  * [JellyTool] — twist, spin, poke, drop.
library;

export 'src/controller.dart';
export 'src/engine.dart' show JellyCube, JellyMove, JellyCubelet;
export 'src/app.dart' show JellyCubeApp;
export 'src/ui.dart' show JellyStage;
export 'src/purchases.dart'
    show JellyPurchaseService, JellyStoreStatus, kExtraTypesProductId;
