// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get softness => 'Suavidad';

  @override
  String get speed => 'Velocidad';

  @override
  String get sound => 'Sonido';

  @override
  String get haptics => 'Vibración';

  @override
  String get hapticsSub => 'Chasquidos y apretones';

  @override
  String get hapticsSubShort => 'Chasquidos';

  @override
  String get calmMode => 'Modo tranquilo';

  @override
  String get calm => 'Tranquilo';

  @override
  String get lessWobble => 'Menos bamboleo';

  @override
  String get muted => 'SILENCIADO';

  @override
  String get mute => 'Silenciar';

  @override
  String get unmute => 'Activar sonido';

  @override
  String get undo => 'Deshacer';

  @override
  String get reset => 'Reiniciar';

  @override
  String get center => 'Centrar';

  @override
  String get scramble => 'Mezclar';

  @override
  String get solve => 'Resolver';

  @override
  String get close => 'Cerrar';

  @override
  String get privacy => 'Privacidad';

  @override
  String get privacySupport => 'Privacidad y soporte';

  @override
  String get restorePurchases => 'Restaurar compras';

  @override
  String get copySupportEmail => 'Copiar email de soporte';

  @override
  String get openSourceLicenses => 'Licencias de código abierto';

  @override
  String get toolTwist => 'Girar';

  @override
  String get toolSpin => 'Rotar';

  @override
  String get toolPoke => 'Pokear';

  @override
  String get toolDrop => 'Soltar';

  @override
  String get sectionFlavors => 'SABORES';

  @override
  String get sectionTexture => 'TEXTURA';

  @override
  String get sectionFaces => 'CARAS';

  @override
  String get sectionMoves => 'MOVIMIENTOS';

  @override
  String get sectionState => 'ESTADO';

  @override
  String get controlStation => 'ESTACIÓN DE CONTROL';

  @override
  String get jellyControls => 'CONTROLES GELLY';

  @override
  String get jellyLab => 'Laboratorio Gelly';

  @override
  String get extraTypes => 'TIPOS EXTRA';

  @override
  String get jellyPass => 'GELLY PASS';

  @override
  String get sectionPurchases => 'COMPRAS';

  @override
  String get sectionPrivacy => 'PRIVACIDAD';

  @override
  String get sectionSupport => 'SOPORTE';

  @override
  String get statusReady => 'LISTO';

  @override
  String get statusSolved => 'RESUELTO';

  @override
  String get statusInPlay => 'EN JUEGO';

  @override
  String get statusMixing => 'MEZCLANDO';

  @override
  String get statusSolving => 'RESOLVIENDO';

  @override
  String get statusTwisting => 'GIRANDO';

  @override
  String get statusDropping => 'CAYENDO';

  @override
  String get statusPoking => 'POKEANDO';

  @override
  String get statusOrbiting => 'ORBITANDO';

  @override
  String get statusScrambling => 'MEZCLANDO';

  @override
  String get statusMelting => 'DERRITIÉNDOSE';

  @override
  String get statusSolvedByHand => 'RESUELTO A MANO';

  @override
  String get demoBadge => 'DEMO';

  @override
  String get owned => 'COMPRADO';

  @override
  String solvingProgress(int index, int total) {
    return 'RESOLVIENDO $index / $total';
  }

  @override
  String scrambledToast(int count) {
    return 'Mezclado · $count movimientos';
  }

  @override
  String solvedToast(String time, int moves) {
    return 'Resuelto · $time · $moves movimientos';
  }

  @override
  String sizeToast(int n, int count) {
    return '$n×$n · $count cubos gelly';
  }

  @override
  String solvingDoneToast(String time, int moves) {
    return 'Resuelto · $time · $moves movimientos';
  }

  @override
  String get toastFirstTwist => 'Primer giro';

  @override
  String get toastFirstFace => '¡Primera cara!';

  @override
  String get toastFirstLayer => '¡Primera capa!';

  @override
  String get toastTwoLayers => '¡Dos capas!';

  @override
  String get toastNothingToUndo => 'Nada que deshacer';

  @override
  String get toastAlreadySolved => 'Ya resuelto · pokealo';

  @override
  String get toastSolvePaused => 'Resolución en pausa · tu turno';

  @override
  String get toastReset => 'Reiniciado · recién salido del frigo';

  @override
  String get hintDragPoke => 'ARRASTRA UNA CARA  ·  TOCA PARA POKEAR';

  @override
  String get hintDragFull =>
      'ARRASTRA PARA GIRAR  ·  TOCA PARA POKEAR  ·  DOS DEDOS PARA ORBITAR';

  @override
  String get specimenLabel => 'POKEABLE  ·  ESPÉCIMEN 011';

  @override
  String get synthNote => 'SINTETIZADO EN DART  ·  120 HZ';

  @override
  String get jellyImpressed => 'El gelly está impresionado.';

  @override
  String get flavorCoconut => 'Coco';

  @override
  String get flavorLemon => 'Limón';

  @override
  String get flavorLime => 'Lima';

  @override
  String get flavorBlueberry => 'Arándano';

  @override
  String get flavorCherry => 'Cereza';

  @override
  String get flavorTangerine => 'Mandarina';

  @override
  String get unlockTitle => 'Desbloquear 5×5 y 6×6';

  @override
  String unlockFor(String price) {
    return 'Desbloquear por $price';
  }

  @override
  String get unlockBody =>
      'Dos cubos más grandes, un pequeño desbloqueo. El 5×5 y el 6×6 se unen a los tamaños gratis 2×2, 3×3 y 4×4, con futuros tipos extra incluidos.';

  @override
  String get oneTimeNote =>
      'Pago único. La tienda gestiona el pago. Sin suscripción.';

  @override
  String get restoreNote =>
      'Restáuralo cuando quieras con la misma cuenta de la tienda.';

  @override
  String get unlockedMsg =>
      'Los tipos extra están desbloqueados en este dispositivo y se restauran en cualquier dispositivo con la misma cuenta de tienda.';

  @override
  String get storeUnavailable => 'Tienda no disponible';

  @override
  String get supportEmailCopied => 'Email de soporte copiado';

  @override
  String get moreCubeMoreWobble => 'Más cubo, más bamboleo.';

  @override
  String get aboutTagline => 'Un puzzle pequeño y brillante.';

  @override
  String get aboutDescription =>
      'Un puzzle de cuerpo blando con un alma de precisión entera.';

  @override
  String get privacyBody =>
      'Sin cuenta. Sin anuncios. Sin analíticas. La app no recoge datos personales.';

  @override
  String get viewFullPolicy => 'Ver la política de privacidad completa';
}
