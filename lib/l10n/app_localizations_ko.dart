// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class LKo extends L {
  LKo([String locale = 'ko']) : super(locale);

  @override
  String get softness => '부드러움';

  @override
  String get speed => '속도';

  @override
  String get sound => '볼륨';

  @override
  String get haptics => '진동';

  @override
  String get hapticsSub => '흡착 & 스퀴시';

  @override
  String get hapticsSubShort => '흡착';

  @override
  String get calmMode => '차분한 모드';

  @override
  String get calm => '차분';

  @override
  String get lessWobble => '흔들림 줄이기';

  @override
  String get muted => '음소거';

  @override
  String get mute => '음소거';

  @override
  String get unmute => '음소거 해제';

  @override
  String get undo => '되돌리기';

  @override
  String get reset => '초기화';

  @override
  String get center => '가운데';

  @override
  String get scramble => '섞기';

  @override
  String get solve => '맞추기';

  @override
  String get close => '닫기';

  @override
  String get privacy => '개인정보';

  @override
  String get privacySupport => '개인정보 및 지원';

  @override
  String get restorePurchases => '구매 복원';

  @override
  String get copySupportEmail => '지원 이메일 복사';

  @override
  String get openSourceLicenses => '오픈소스 라이선스';

  @override
  String get toolTwist => '비틀기';

  @override
  String get toolSpin => '회전';

  @override
  String get toolPoke => '콕콕';

  @override
  String get toolDrop => '떨어뜨리기';

  @override
  String get sectionFlavors => '맛';

  @override
  String get sectionTexture => '질감';

  @override
  String get sectionFaces => '면';

  @override
  String get sectionMoves => '무브';

  @override
  String get sectionState => '상태';

  @override
  String get controlStation => '컨트롤 스테이션';

  @override
  String get jellyControls => '젤리 컨트롤';

  @override
  String get jellyLab => '젤리 연구소';

  @override
  String get extraTypes => '추가 타입';

  @override
  String get jellyPass => '젤리 패스';

  @override
  String get sectionPurchases => '구매';

  @override
  String get sectionPrivacy => '개인정보';

  @override
  String get sectionSupport => '지원';

  @override
  String get statusReady => '준비';

  @override
  String get statusSolved => '완성';

  @override
  String get statusInPlay => '진행 중';

  @override
  String get statusMixing => '섞는 중';

  @override
  String get statusSolving => '맞추는 중';

  @override
  String get statusTwisting => '비트는 중';

  @override
  String get statusDropping => '떨어지는 중';

  @override
  String get statusPoking => '콕콕 중';

  @override
  String get statusOrbiting => '회전 중';

  @override
  String get statusScrambling => '섞는 중';

  @override
  String get statusMelting => '녹는 중';

  @override
  String get statusSolvedByHand => '직접 완성';

  @override
  String get demoBadge => '데모';

  @override
  String get owned => '보유함';

  @override
  String solvingProgress(int index, int total) {
    return '맞추는 중 $index / $total';
  }

  @override
  String scrambledToast(int count) {
    return '섞기 완료 · $count무브';
  }

  @override
  String solvedToast(String time, int moves) {
    return '완성 · $time · $moves무브';
  }

  @override
  String sizeToast(int n, int count) {
    return '$n×$n · 젤리 $count개';
  }

  @override
  String solvingDoneToast(String time, int moves) {
    return '완성 · $time · $moves무브';
  }

  @override
  String get toastFirstTwist => '첫 비틀기';

  @override
  String get toastFirstFace => '첫 번째 면!';

  @override
  String get toastFirstLayer => '첫 레이어!';

  @override
  String get toastTwoLayers => '두 레이어!';

  @override
  String get toastNothingToUndo => '되돌릴 것이 없습니다';

  @override
  String get toastAlreadySolved => '이미 완성 · 콕콕 찔러보세요';

  @override
  String get toastSolvePaused => '자동 해결 일시정지 · 당서의 차례';

  @override
  String get toastReset => '초기화 · 갓 꺼낸 젤리';

  @override
  String get hintDragPoke => '면을 드래그  ·  탭하여 콕콕';

  @override
  String get hintDragFull => '면을 드래그해 비틀기  ·  탭으로 콕콕  ·  두 손가락으로 시점 회전';

  @override
  String get specimenLabel => '콕콕 가능  ·  표본 011';

  @override
  String get synthNote => 'DART 합성  ·  120 Hz';

  @override
  String get jellyImpressed => '젤리가 감탄했습니다.';

  @override
  String get flavorCoconut => '코코넛';

  @override
  String get flavorLemon => '레몬';

  @override
  String get flavorLime => '라임';

  @override
  String get flavorBlueberry => '블루베리';

  @override
  String get flavorCherry => '체리';

  @override
  String get flavorTangerine => '귤';

  @override
  String get unlockTitle => '5×5 & 6×6 해금';

  @override
  String unlockFor(String price) {
    return '$price에 해금';
  }

  @override
  String get unlockBody =>
      '더 큰 큐브 두 종을 한 번의 해금으로. 5×5와 6×6이 무료 2×2, 3×3, 4×4에 더해지고 향후 추가 타입도 포함됩니다.';

  @override
  String get oneTimeNote => '일회성 구매. 결제는 스토어가 처리합니다. 구독이 아닙니다.';

  @override
  String get restoreNote => '같은 스토어 계정이라면 언제든 복원할 수 있습니다.';

  @override
  String get unlockedMsg => '추가 타입이 이 기기에서 해금되었습니다. 같은 스토어 계정의 기기에서 복원됩니다.';

  @override
  String get storeUnavailable => '스토어를 사용할 수 없습니다';

  @override
  String get supportEmailCopied => '지원 이메일을 복사했습니다';

  @override
  String get moreCubeMoreWobble => '큐브가 커지면 흔들림도 커진다.';

  @override
  String get aboutTagline => '작고 반짝이는 퍼즐.';

  @override
  String get aboutDescription => '부드러운 몸, 완벽한 정수의 영혼.';

  @override
  String get privacyBody => '계정 없음. 광고 없음. 분석 없음. 앱은 어떤 개인 데이터도 수집하지 않습니다.';

  @override
  String get viewFullPolicy => '전체 개인정보 처리방침 보기';
}
