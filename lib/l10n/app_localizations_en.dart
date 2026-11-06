// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get softness => 'Softness';

  @override
  String get speed => 'Speed';

  @override
  String get sound => 'Sound';

  @override
  String get haptics => 'Haptics';

  @override
  String get hapticsSub => 'Snaps & squish';

  @override
  String get hapticsSubShort => 'Snaps';

  @override
  String get calmMode => 'Calm mode';

  @override
  String get calm => 'Calm';

  @override
  String get lessWobble => 'Less wobble';

  @override
  String get muted => 'MUTED';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get undo => 'Undo';

  @override
  String get reset => 'Reset';

  @override
  String get center => 'Center';

  @override
  String get scramble => 'Scramble';

  @override
  String get solve => 'Solve';

  @override
  String get close => 'Close';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacySupport => 'Privacy & support';

  @override
  String get restorePurchases => 'Restore Purchases';

  @override
  String get copySupportEmail => 'Copy support email';

  @override
  String get openSourceLicenses => 'Open source licenses';

  @override
  String get toolTwist => 'Twist';

  @override
  String get toolSpin => 'Spin';

  @override
  String get toolPoke => 'Poke';

  @override
  String get toolDrop => 'Drop';

  @override
  String get sectionFlavors => 'FLAVORS';

  @override
  String get sectionTexture => 'TEXTURE';

  @override
  String get sectionFaces => 'FACES';

  @override
  String get sectionMoves => 'MOVES';

  @override
  String get sectionState => 'STATE';

  @override
  String get controlStation => 'CONTROL STATION';

  @override
  String get jellyControls => 'JELLY CONTROLS';

  @override
  String get jellyLab => 'Jelly Lab';

  @override
  String get extraTypes => 'EXTRA TYPES';

  @override
  String get jellyPass => 'JELLY PASS';

  @override
  String get sectionPurchases => 'PURCHASES';

  @override
  String get sectionPrivacy => 'PRIVACY';

  @override
  String get sectionSupport => 'SUPPORT';

  @override
  String get statusReady => 'READY';

  @override
  String get statusSolved => 'SOLVED';

  @override
  String get statusInPlay => 'IN PLAY';

  @override
  String get statusMixing => 'MIXING';

  @override
  String get statusSolving => 'SOLVING';

  @override
  String get statusTwisting => 'TWISTING';

  @override
  String get statusDropping => 'DROPPING';

  @override
  String get statusPoking => 'POKING';

  @override
  String get statusOrbiting => 'ORBITING';

  @override
  String get statusScrambling => 'SCRAMBLING';

  @override
  String get statusMelting => 'MELTING';

  @override
  String get statusSolvedByHand => 'SOLVED BY HAND';

  @override
  String get demoBadge => 'DEMO';

  @override
  String get owned => 'OWNED';

  @override
  String solvingProgress(int index, int total) {
    return 'SOLVING $index / $total';
  }

  @override
  String scrambledToast(int count) {
    return 'Scrambled · $count moves';
  }

  @override
  String solvedToast(String time, int moves) {
    return 'Solved · $time · $moves moves';
  }

  @override
  String sizeToast(int n, int count) {
    return '$n×$n · $count jellylets';
  }

  @override
  String solvingDoneToast(String time, int moves) {
    return 'Solved · $time · $moves moves';
  }

  @override
  String get toastFirstTwist => 'First twist';

  @override
  String get toastFirstFace => 'First face!';

  @override
  String get toastFirstLayer => 'First layer!';

  @override
  String get toastTwoLayers => 'Two layers!';

  @override
  String get toastNothingToUndo => 'Nothing to undo';

  @override
  String get toastAlreadySolved => 'Already solved · poke it';

  @override
  String get toastSolvePaused => 'Solve paused · your move';

  @override
  String get toastReset => 'Reset · fresh from the fridge';

  @override
  String get hintDragPoke => 'DRAG A FACE  ·  TAP TO POKE';

  @override
  String get hintDragFull =>
      'DRAG A FACE TO TWIST  ·  TAP TO POKE  ·  TWO FINGERS TO ORBIT';

  @override
  String get specimenLabel => 'POKEABLE  ·  SPECIMEN 011';

  @override
  String get synthNote => 'SYNTHESIZED IN DART  ·  120 HZ';

  @override
  String get jellyImpressed => 'The jelly is impressed.';

  @override
  String get flavorCoconut => 'Coconut';

  @override
  String get flavorLemon => 'Lemon';

  @override
  String get flavorLime => 'Lime';

  @override
  String get flavorBlueberry => 'Blueberry';

  @override
  String get flavorCherry => 'Cherry';

  @override
  String get flavorTangerine => 'Tangerine';

  @override
  String get unlockTitle => 'Unlock 5×5 & 6×6';

  @override
  String unlockFor(String price) {
    return 'Unlock for $price';
  }

  @override
  String get unlockBody =>
      'Two bigger cubes, one small unlock. 5×5 and 6×6 join the free 2×2, 3×3 and 4×4 sizes, with future extra types included.';

  @override
  String get oneTimeNote =>
      'One-time purchase. Payment is handled by the store. No subscription.';

  @override
  String get restoreNote => 'Restore any time with the same store account.';

  @override
  String get unlockedMsg =>
      'Extra Cube Types is unlocked on this device. It restores on any device signed into the same store account.';

  @override
  String get storeUnavailable => 'Store unavailable';

  @override
  String get supportEmailCopied => 'Support email copied';

  @override
  String get moreCubeMoreWobble => 'More cube, more wobble.';

  @override
  String get aboutTagline => 'A small, glossy puzzle.';

  @override
  String get aboutDescription =>
      'A soft-body puzzle with a crisp, integer-perfect soul.';

  @override
  String get privacyBody =>
      'No account. No ads. No analytics. No personal data is collected by the app.';

  @override
  String get viewFullPolicy => 'View full privacy policy';
}
