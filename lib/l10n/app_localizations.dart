import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
  ];

  /// No description provided for @softness.
  ///
  /// In en, this message translates to:
  /// **'Softness'**
  String get softness;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @sound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get sound;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptics'**
  String get haptics;

  /// No description provided for @hapticsSub.
  ///
  /// In en, this message translates to:
  /// **'Snaps & squish'**
  String get hapticsSub;

  /// No description provided for @hapticsSubShort.
  ///
  /// In en, this message translates to:
  /// **'Snaps'**
  String get hapticsSubShort;

  /// No description provided for @calmMode.
  ///
  /// In en, this message translates to:
  /// **'Calm mode'**
  String get calmMode;

  /// No description provided for @calm.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get calm;

  /// No description provided for @lessWobble.
  ///
  /// In en, this message translates to:
  /// **'Less wobble'**
  String get lessWobble;

  /// No description provided for @muted.
  ///
  /// In en, this message translates to:
  /// **'MUTED'**
  String get muted;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @center.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get center;

  /// No description provided for @scramble.
  ///
  /// In en, this message translates to:
  /// **'Scramble'**
  String get scramble;

  /// No description provided for @solve.
  ///
  /// In en, this message translates to:
  /// **'Solve'**
  String get solve;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @showControls.
  ///
  /// In en, this message translates to:
  /// **'Show controls'**
  String get showControls;

  /// No description provided for @hideControls.
  ///
  /// In en, this message translates to:
  /// **'Hide controls'**
  String get hideControls;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySupport.
  ///
  /// In en, this message translates to:
  /// **'Privacy & support'**
  String get privacySupport;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @copySupportEmail.
  ///
  /// In en, this message translates to:
  /// **'Copy support email'**
  String get copySupportEmail;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get openSourceLicenses;

  /// No description provided for @toolTwist.
  ///
  /// In en, this message translates to:
  /// **'Twist'**
  String get toolTwist;

  /// No description provided for @toolSpin.
  ///
  /// In en, this message translates to:
  /// **'Spin'**
  String get toolSpin;

  /// No description provided for @toolPoke.
  ///
  /// In en, this message translates to:
  /// **'Poke'**
  String get toolPoke;

  /// No description provided for @toolDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get toolDrop;

  /// No description provided for @sectionFlavors.
  ///
  /// In en, this message translates to:
  /// **'FLAVORS'**
  String get sectionFlavors;

  /// No description provided for @sectionTexture.
  ///
  /// In en, this message translates to:
  /// **'TEXTURE'**
  String get sectionTexture;

  /// No description provided for @sectionFaces.
  ///
  /// In en, this message translates to:
  /// **'FACES'**
  String get sectionFaces;

  /// No description provided for @sectionMoves.
  ///
  /// In en, this message translates to:
  /// **'MOVES'**
  String get sectionMoves;

  /// No description provided for @sectionState.
  ///
  /// In en, this message translates to:
  /// **'STATE'**
  String get sectionState;

  /// No description provided for @controlStation.
  ///
  /// In en, this message translates to:
  /// **'CONTROL STATION'**
  String get controlStation;

  /// No description provided for @jellyControls.
  ///
  /// In en, this message translates to:
  /// **'JELLY CONTROLS'**
  String get jellyControls;

  /// No description provided for @jellyLab.
  ///
  /// In en, this message translates to:
  /// **'Jelly Lab'**
  String get jellyLab;

  /// No description provided for @extraTypes.
  ///
  /// In en, this message translates to:
  /// **'EXTRA TYPES'**
  String get extraTypes;

  /// No description provided for @jellyPass.
  ///
  /// In en, this message translates to:
  /// **'JELLY PASS'**
  String get jellyPass;

  /// No description provided for @sectionPurchases.
  ///
  /// In en, this message translates to:
  /// **'PURCHASES'**
  String get sectionPurchases;

  /// No description provided for @sectionPrivacy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get sectionPrivacy;

  /// No description provided for @sectionSupport.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get sectionSupport;

  /// No description provided for @statusReady.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get statusReady;

  /// No description provided for @statusSolved.
  ///
  /// In en, this message translates to:
  /// **'SOLVED'**
  String get statusSolved;

  /// No description provided for @statusInPlay.
  ///
  /// In en, this message translates to:
  /// **'IN PLAY'**
  String get statusInPlay;

  /// No description provided for @statusMixing.
  ///
  /// In en, this message translates to:
  /// **'MIXING'**
  String get statusMixing;

  /// No description provided for @statusSolving.
  ///
  /// In en, this message translates to:
  /// **'SOLVING'**
  String get statusSolving;

  /// No description provided for @statusTwisting.
  ///
  /// In en, this message translates to:
  /// **'TWISTING'**
  String get statusTwisting;

  /// No description provided for @statusDropping.
  ///
  /// In en, this message translates to:
  /// **'DROPPING'**
  String get statusDropping;

  /// No description provided for @statusPoking.
  ///
  /// In en, this message translates to:
  /// **'POKING'**
  String get statusPoking;

  /// No description provided for @statusOrbiting.
  ///
  /// In en, this message translates to:
  /// **'ORBITING'**
  String get statusOrbiting;

  /// No description provided for @statusScrambling.
  ///
  /// In en, this message translates to:
  /// **'SCRAMBLING'**
  String get statusScrambling;

  /// No description provided for @statusMelting.
  ///
  /// In en, this message translates to:
  /// **'MELTING'**
  String get statusMelting;

  /// No description provided for @statusSolvedByHand.
  ///
  /// In en, this message translates to:
  /// **'SOLVED BY HAND'**
  String get statusSolvedByHand;

  /// No description provided for @demoBadge.
  ///
  /// In en, this message translates to:
  /// **'DEMO'**
  String get demoBadge;

  /// No description provided for @owned.
  ///
  /// In en, this message translates to:
  /// **'OWNED'**
  String get owned;

  /// No description provided for @solvingProgress.
  ///
  /// In en, this message translates to:
  /// **'SOLVING {index} / {total}'**
  String solvingProgress(int index, int total);

  /// No description provided for @scrambledToast.
  ///
  /// In en, this message translates to:
  /// **'Scrambled · {count} moves'**
  String scrambledToast(int count);

  /// No description provided for @solvedToast.
  ///
  /// In en, this message translates to:
  /// **'Solved · {time} · {moves} moves'**
  String solvedToast(String time, int moves);

  /// No description provided for @sizeToast.
  ///
  /// In en, this message translates to:
  /// **'{n}×{n} · {count} jellylets'**
  String sizeToast(int n, int count);

  /// No description provided for @solvingDoneToast.
  ///
  /// In en, this message translates to:
  /// **'Solved · {time} · {moves} moves'**
  String solvingDoneToast(String time, int moves);

  /// No description provided for @toastFirstTwist.
  ///
  /// In en, this message translates to:
  /// **'First twist'**
  String get toastFirstTwist;

  /// No description provided for @toastFirstFace.
  ///
  /// In en, this message translates to:
  /// **'First face!'**
  String get toastFirstFace;

  /// No description provided for @toastFirstLayer.
  ///
  /// In en, this message translates to:
  /// **'First layer!'**
  String get toastFirstLayer;

  /// No description provided for @toastTwoLayers.
  ///
  /// In en, this message translates to:
  /// **'Two layers!'**
  String get toastTwoLayers;

  /// No description provided for @toastNothingToUndo.
  ///
  /// In en, this message translates to:
  /// **'Nothing to undo'**
  String get toastNothingToUndo;

  /// No description provided for @toastAlreadySolved.
  ///
  /// In en, this message translates to:
  /// **'Already solved · poke it'**
  String get toastAlreadySolved;

  /// No description provided for @toastSolvePaused.
  ///
  /// In en, this message translates to:
  /// **'Solve paused · your move'**
  String get toastSolvePaused;

  /// No description provided for @toastReset.
  ///
  /// In en, this message translates to:
  /// **'Reset · fresh from the fridge'**
  String get toastReset;

  /// No description provided for @hintDragPoke.
  ///
  /// In en, this message translates to:
  /// **'DRAG A FACE  ·  TAP TO POKE'**
  String get hintDragPoke;

  /// No description provided for @hintDragFull.
  ///
  /// In en, this message translates to:
  /// **'DRAG A FACE TO TWIST  ·  TAP TO POKE  ·  TWO FINGERS TO ORBIT'**
  String get hintDragFull;

  /// No description provided for @specimenLabel.
  ///
  /// In en, this message translates to:
  /// **'POKEABLE  ·  SPECIMEN 011'**
  String get specimenLabel;

  /// No description provided for @synthNote.
  ///
  /// In en, this message translates to:
  /// **'SYNTHESIZED IN DART  ·  120 HZ'**
  String get synthNote;

  /// No description provided for @jellyImpressed.
  ///
  /// In en, this message translates to:
  /// **'The jelly is impressed.'**
  String get jellyImpressed;

  /// No description provided for @flavorCoconut.
  ///
  /// In en, this message translates to:
  /// **'Coconut'**
  String get flavorCoconut;

  /// No description provided for @flavorLemon.
  ///
  /// In en, this message translates to:
  /// **'Lemon'**
  String get flavorLemon;

  /// No description provided for @flavorLime.
  ///
  /// In en, this message translates to:
  /// **'Lime'**
  String get flavorLime;

  /// No description provided for @flavorBlueberry.
  ///
  /// In en, this message translates to:
  /// **'Blueberry'**
  String get flavorBlueberry;

  /// No description provided for @flavorCherry.
  ///
  /// In en, this message translates to:
  /// **'Cherry'**
  String get flavorCherry;

  /// No description provided for @flavorTangerine.
  ///
  /// In en, this message translates to:
  /// **'Tangerine'**
  String get flavorTangerine;

  /// No description provided for @unlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock 5×5 & 6×6'**
  String get unlockTitle;

  /// No description provided for @unlockFor.
  ///
  /// In en, this message translates to:
  /// **'Unlock for {price}'**
  String unlockFor(String price);

  /// No description provided for @unlockBody.
  ///
  /// In en, this message translates to:
  /// **'Two bigger cubes, one small unlock. 5×5 and 6×6 join the free 2×2, 3×3 and 4×4 sizes, with future extra types included.'**
  String get unlockBody;

  /// No description provided for @oneTimeNote.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. Payment is handled by the store. No subscription.'**
  String get oneTimeNote;

  /// No description provided for @restoreNote.
  ///
  /// In en, this message translates to:
  /// **'Restore any time with the same store account.'**
  String get restoreNote;

  /// No description provided for @unlockedMsg.
  ///
  /// In en, this message translates to:
  /// **'Extra Cube Types is unlocked on this device. It restores on any device signed into the same store account.'**
  String get unlockedMsg;

  /// No description provided for @storeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Store unavailable'**
  String get storeUnavailable;

  /// No description provided for @supportEmailCopied.
  ///
  /// In en, this message translates to:
  /// **'Support email copied'**
  String get supportEmailCopied;

  /// No description provided for @moreCubeMoreWobble.
  ///
  /// In en, this message translates to:
  /// **'More cube, more wobble.'**
  String get moreCubeMoreWobble;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'A small, glossy puzzle.'**
  String get aboutTagline;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'A soft-body puzzle with a crisp, integer-perfect soul.'**
  String get aboutDescription;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'No account. No ads. No analytics. No personal data is collected by the app.'**
  String get privacyBody;

  /// No description provided for @viewFullPolicy.
  ///
  /// In en, this message translates to:
  /// **'View full privacy policy'**
  String get viewFullPolicy;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'de',
    'en',
    'es',
    'fr',
    'ja',
    'ko',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return LDe();
    case 'en':
      return LEn();
    case 'es':
      return LEs();
    case 'fr':
      return LFr();
    case 'ja':
      return LJa();
    case 'ko':
      return LKo();
    case 'zh':
      return LZh();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
