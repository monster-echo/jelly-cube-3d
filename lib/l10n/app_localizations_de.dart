// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class LDe extends L {
  LDe([String locale = 'de']) : super(locale);

  @override
  String get softness => 'Weichheit';

  @override
  String get speed => 'Tempo';

  @override
  String get sound => 'Ton';

  @override
  String get haptics => 'Vibration';

  @override
  String get hapticsSub => 'Snaps & Quetschen';

  @override
  String get hapticsSubShort => 'Snaps';

  @override
  String get calmMode => 'Ruhiger Modus';

  @override
  String get calm => 'Ruhig';

  @override
  String get lessWobble => 'Weniger Wackeln';

  @override
  String get muted => 'STUMM';

  @override
  String get mute => 'Stumm';

  @override
  String get unmute => 'Ton an';

  @override
  String get undo => 'Zurück';

  @override
  String get reset => 'Neustart';

  @override
  String get center => 'Zentrieren';

  @override
  String get scramble => 'Mischen';

  @override
  String get solve => 'Lösen';

  @override
  String get close => 'Schließen';

  @override
  String get showControls => 'Steuerung einblenden';

  @override
  String get hideControls => 'Steuerung ausblenden';

  @override
  String get privacy => 'Datenschutz';

  @override
  String get privacySupport => 'Datenschutz & Hilfe';

  @override
  String get restorePurchases => 'Käufe wiederherstellen';

  @override
  String get copySupportEmail => 'Support-E-Mail kopieren';

  @override
  String get openSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get toolTwist => 'Drehen';

  @override
  String get toolSpin => 'Rotieren';

  @override
  String get toolPoke => 'Piekser';

  @override
  String get toolDrop => 'Fallen';

  @override
  String get sectionFlavors => 'SORTEN';

  @override
  String get sectionTexture => 'TEXTUR';

  @override
  String get sectionFaces => 'SEITEN';

  @override
  String get sectionMoves => 'ZÜGE';

  @override
  String get sectionState => 'STATUS';

  @override
  String get controlStation => 'KONTROLLSTATION';

  @override
  String get jellyControls => 'GELLY-STEUERUNG';

  @override
  String get jellyLab => 'Gelly-Labor';

  @override
  String get extraTypes => 'EXTRA-TYPEN';

  @override
  String get jellyPass => 'GELLY-PASS';

  @override
  String get sectionPurchases => 'KÄUFE';

  @override
  String get sectionPrivacy => 'DATENSCHUTZ';

  @override
  String get sectionSupport => 'HILFE';

  @override
  String get statusReady => 'BEREIT';

  @override
  String get statusSolved => 'GELÖST';

  @override
  String get statusInPlay => 'IM SPIEL';

  @override
  String get statusMixing => 'MISCHT';

  @override
  String get statusSolving => 'LÖST';

  @override
  String get statusTwisting => 'DREHT';

  @override
  String get statusDropping => 'FÄLLT';

  @override
  String get statusPoking => 'PIEKT';

  @override
  String get statusOrbiting => 'ORBITET';

  @override
  String get statusScrambling => 'MISCHT';

  @override
  String get statusMelting => 'SCHMILZT';

  @override
  String get statusSolvedByHand => 'VON HAND GELÖST';

  @override
  String get demoBadge => 'DEMO';

  @override
  String get owned => 'GEKAUFT';

  @override
  String solvingProgress(int index, int total) {
    return 'LÖST $index / $total';
  }

  @override
  String scrambledToast(int count) {
    return 'Gemischt · $count Züge';
  }

  @override
  String solvedToast(String time, int moves) {
    return 'Gelöst · $time · $moves Züge';
  }

  @override
  String sizeToast(int n, int count) {
    return '$n×$n · $count Gelly-Würfel';
  }

  @override
  String solvingDoneToast(String time, int moves) {
    return 'Gelöst · $time · $moves Züge';
  }

  @override
  String get toastFirstTwist => 'Erste Drehung';

  @override
  String get toastFirstFace => 'Erste Seite!';

  @override
  String get toastFirstLayer => 'Erste Ebene!';

  @override
  String get toastTwoLayers => 'Zwei Ebenen!';

  @override
  String get toastNothingToUndo => 'Nichts zurückzunehmen';

  @override
  String get toastAlreadySolved => 'Schon gelöst · pieksern!';

  @override
  String get toastSolvePaused => 'Lösung pausiert · dein Zug';

  @override
  String get toastReset => 'Zurückgesetzt · frisch aus dem Kühlschrank';

  @override
  String get hintDragPoke => 'SEITE ZIEHEN  ·  TIPPEN ZUM PIEKSEN';

  @override
  String get hintDragFull =>
      'SEITE ZIEHEN & DREHEN  ·  TIPPEN ZUM PIEKSEN  ·  ZWEI FINGER ZUM ORBITEN';

  @override
  String get specimenLabel => 'PIEKSBAR  ·  EXEMPLAR 011';

  @override
  String get synthNote => 'IN DART SYNTHETISIERT  ·  120 HZ';

  @override
  String get jellyImpressed => 'Das Gelly ist beeindruckt.';

  @override
  String get flavorCoconut => 'Kokos';

  @override
  String get flavorLemon => 'Zitrone';

  @override
  String get flavorLime => 'Limette';

  @override
  String get flavorBlueberry => 'Blaubeere';

  @override
  String get flavorCherry => 'Kirsche';

  @override
  String get flavorTangerine => 'Mandarine';

  @override
  String get unlockTitle => '5×5 & 6×6 freischalten';

  @override
  String unlockFor(String price) {
    return 'Freischalten für $price';
  }

  @override
  String get unlockBody =>
      'Zwei größere Würfel, eine kleine Freischaltung. 5×5 und 6×6 kommen zu den kostenlosen Größen 2×2, 3×3 und 4×4 dazu — künftige Extra-Typen inklusive.';

  @override
  String get oneTimeNote =>
      'Einmaliger Kauf. Die Zahlung läuft über den Store. Kein Abo.';

  @override
  String get restoreNote =>
      'Jederzeit mit demselben Store-Konto wiederherstellbar.';

  @override
  String get unlockedMsg =>
      'Extra-Typen sind auf diesem Gerät freigeschaltet und lassen sich auf jedem Gerät mit demselben Store-Konto wiederherstellen.';

  @override
  String get storeUnavailable => 'Store nicht verfügbar';

  @override
  String get supportEmailCopied => 'Support-E-Mail kopiert';

  @override
  String get moreCubeMoreWobble => 'Mehr Würfel, mehr Wackeln.';

  @override
  String get aboutTagline => 'Ein kleines, glänzendes Puzzle.';

  @override
  String get aboutDescription =>
      'Ein weiches Puzzle mit einer knackig präzisen Seele.';

  @override
  String get privacyBody =>
      'Kein Konto. Keine Werbung. Kein Tracking. Die App sammelt keine persönlichen Daten.';

  @override
  String get viewFullPolicy => 'Vollständige Datenschutzerklärung';
}
