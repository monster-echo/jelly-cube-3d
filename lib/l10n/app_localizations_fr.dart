// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class LFr extends L {
  LFr([String locale = 'fr']) : super(locale);

  @override
  String get softness => 'Douceur';

  @override
  String get speed => 'Vitesse';

  @override
  String get sound => 'Son';

  @override
  String get haptics => 'Vibrations';

  @override
  String get hapticsSub => 'Clics & écrasement';

  @override
  String get hapticsSubShort => 'Clics';

  @override
  String get calmMode => 'Mode calme';

  @override
  String get calm => 'Calme';

  @override
  String get lessWobble => 'Moins de tremblement';

  @override
  String get muted => 'MUET';

  @override
  String get mute => 'Muet';

  @override
  String get unmute => 'Réactiver';

  @override
  String get undo => 'Annuler';

  @override
  String get reset => 'Réinitialiser';

  @override
  String get center => 'Centrer';

  @override
  String get scramble => 'Mélanger';

  @override
  String get solve => 'Résoudre';

  @override
  String get close => 'Fermer';

  @override
  String get showControls => 'Afficher les commandes';

  @override
  String get hideControls => 'Masquer les commandes';

  @override
  String get privacy => 'Confidentialité';

  @override
  String get privacySupport => 'Confidentialité & aide';

  @override
  String get restorePurchases => 'Restaurer les achats';

  @override
  String get copySupportEmail => 'Copier l\'e-mail d\'assistance';

  @override
  String get openSourceLicenses => 'Licences open source';

  @override
  String get toolTwist => 'Tourner';

  @override
  String get toolSpin => 'Pivoter';

  @override
  String get toolPoke => 'Pousser';

  @override
  String get toolDrop => 'Lâcher';

  @override
  String get sectionFlavors => 'SAVEURS';

  @override
  String get sectionTexture => 'TEXTURE';

  @override
  String get sectionFaces => 'FACES';

  @override
  String get sectionMoves => 'COUPS';

  @override
  String get sectionState => 'ÉTAT';

  @override
  String get controlStation => 'POSTE DE CONTRÔLE';

  @override
  String get jellyControls => 'CONTRÔLES GELLY';

  @override
  String get jellyLab => 'Labo Gelly';

  @override
  String get extraTypes => 'TYPES EXTRA';

  @override
  String get jellyPass => 'GELLY PASS';

  @override
  String get sectionPurchases => 'ACHATS';

  @override
  String get sectionPrivacy => 'CONFIDENTIALITÉ';

  @override
  String get sectionSupport => 'AIDE';

  @override
  String get statusReady => 'PRÊT';

  @override
  String get statusSolved => 'RÉSOLU';

  @override
  String get statusInPlay => 'EN JEU';

  @override
  String get statusMixing => 'MÉLANGE';

  @override
  String get statusSolving => 'RÉSOUT';

  @override
  String get statusTwisting => 'TOURNE';

  @override
  String get statusDropping => 'TOMBE';

  @override
  String get statusPoking => 'POUSSE';

  @override
  String get statusOrbiting => 'ORBITE';

  @override
  String get statusScrambling => 'MÉLANGE';

  @override
  String get statusMelting => 'FOND';

  @override
  String get statusSolvedByHand => 'RÉSOLU À LA MAIN';

  @override
  String get demoBadge => 'DÉMO';

  @override
  String get owned => 'ACHETÉ';

  @override
  String solvingProgress(int index, int total) {
    return 'RÉSOUT $index / $total';
  }

  @override
  String scrambledToast(int count) {
    return 'Mélangé · $count coups';
  }

  @override
  String solvedToast(String time, int moves) {
    return 'Résolu · $time · $moves coups';
  }

  @override
  String sizeToast(int n, int count) {
    return '$n×$n · $count cubes gelly';
  }

  @override
  String solvingDoneToast(String time, int moves) {
    return 'Résolu · $time · $moves coups';
  }

  @override
  String get toastFirstTwist => 'Premier tour';

  @override
  String get toastFirstFace => 'Première face !';

  @override
  String get toastFirstLayer => 'Première couche !';

  @override
  String get toastTwoLayers => 'Deux couches !';

  @override
  String get toastNothingToUndo => 'Rien à annuler';

  @override
  String get toastAlreadySolved => 'Déjà résolu · poussez-le';

  @override
  String get toastSolvePaused => 'Résolution en pause · à vous';

  @override
  String get toastReset => 'Réinitialisé · frais du frigo';

  @override
  String get hintDragPoke => 'GLISSEZ UNE FACE  ·  TAPEZ POUR POUSSER';

  @override
  String get hintDragFull =>
      'GLISSEZ POUR TOURNER  ·  TAPEZ POUR POUSSER  ·  DEUX DOIGTS POUR ORBITER';

  @override
  String get specimenLabel => 'POUSSABLE  ·  SPÉCIMEN 011';

  @override
  String get synthNote => 'SYNTHÉTISÉ EN DART  ·  120 HZ';

  @override
  String get jellyImpressed => 'Le gelly est impressionné.';

  @override
  String get flavorCoconut => 'Noix de coco';

  @override
  String get flavorLemon => 'Citron';

  @override
  String get flavorLime => 'Citron vert';

  @override
  String get flavorBlueberry => 'Myrtille';

  @override
  String get flavorCherry => 'Cerise';

  @override
  String get flavorTangerine => 'Mandarine';

  @override
  String get unlockTitle => 'Débloquer 5×5 & 6×6';

  @override
  String unlockFor(String price) {
    return 'Débloquer pour $price';
  }

  @override
  String get unlockBody =>
      'Deux cubes plus grands, un petit déblocage. Le 5×5 et le 6×6 rejoignent les tailles gratuites 2×2, 3×3 et 4×4 — futurs types extra inclus.';

  @override
  String get oneTimeNote =>
      'Achat unique. Le paiement est géré par la boutique. Sans abonnement.';

  @override
  String get restoreNote =>
      'Restaurable à tout moment avec le même compte boutique.';

  @override
  String get unlockedMsg =>
      'Les types extra sont débloqués sur cet appareil et se restaurent sur tout appareil connecté au même compte boutique.';

  @override
  String get storeUnavailable => 'Boutique indisponible';

  @override
  String get supportEmailCopied => 'E-mail d\'assistance copié';

  @override
  String get moreCubeMoreWobble => 'Plus de cube, plus de tremblement.';

  @override
  String get aboutTagline => 'Un petit puzzle brillant.';

  @override
  String get aboutDescription =>
      'Un puzzle au corps mou et à l\'âme d\'une précision parfaite.';

  @override
  String get privacyBody =>
      'Sans compte. Sans pub. Sans traqueur. L\'app ne collecte aucune donnée personnelle.';

  @override
  String get viewFullPolicy => 'Voir la politique de confidentialité complète';
}
