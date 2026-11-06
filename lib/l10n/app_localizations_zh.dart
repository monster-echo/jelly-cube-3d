// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class LZh extends L {
  LZh([String locale = 'zh']) : super(locale);

  @override
  String get softness => '软度';

  @override
  String get speed => '速度';

  @override
  String get sound => '音量';

  @override
  String get haptics => '震动';

  @override
  String get hapticsSub => '吸附与挤压';

  @override
  String get hapticsSubShort => '吸附';

  @override
  String get calmMode => '舒缓模式';

  @override
  String get calm => '舒缓';

  @override
  String get lessWobble => '减少晃动';

  @override
  String get muted => '已静音';

  @override
  String get mute => '静音';

  @override
  String get unmute => '取消静音';

  @override
  String get undo => '撤销';

  @override
  String get reset => '重置';

  @override
  String get center => '居中';

  @override
  String get scramble => '打乱';

  @override
  String get solve => '复原';

  @override
  String get close => '关闭';

  @override
  String get privacy => '隐私';

  @override
  String get privacySupport => '隐私与支持';

  @override
  String get restorePurchases => '恢复购买';

  @override
  String get copySupportEmail => '复制客服邮箱';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get toolTwist => '扭转';

  @override
  String get toolSpin => '旋转';

  @override
  String get toolPoke => '戳';

  @override
  String get toolDrop => '掉落';

  @override
  String get sectionFlavors => '口味';

  @override
  String get sectionTexture => '质感';

  @override
  String get sectionFaces => '面';

  @override
  String get sectionMoves => '步数';

  @override
  String get sectionState => '状态';

  @override
  String get controlStation => '控制台';

  @override
  String get jellyControls => '果冻控制';

  @override
  String get jellyLab => '果冻实验室';

  @override
  String get extraTypes => '扩展型号';

  @override
  String get jellyPass => '果冻通行证';

  @override
  String get sectionPurchases => '购买';

  @override
  String get sectionPrivacy => '隐私';

  @override
  String get sectionSupport => '支持';

  @override
  String get statusReady => '就绪';

  @override
  String get statusSolved => '已复原';

  @override
  String get statusInPlay => '进行中';

  @override
  String get statusMixing => '混合中';

  @override
  String get statusSolving => '复原中';

  @override
  String get statusTwisting => '扭转中';

  @override
  String get statusDropping => '掉落中';

  @override
  String get statusPoking => '戳动中';

  @override
  String get statusOrbiting => '环视中';

  @override
  String get statusScrambling => '打乱中';

  @override
  String get statusMelting => '融化中';

  @override
  String get statusSolvedByHand => '亲手复原';

  @override
  String get demoBadge => '演示';

  @override
  String get owned => '已拥有';

  @override
  String solvingProgress(int index, int total) {
    return '复原中 $index / $total';
  }

  @override
  String scrambledToast(int count) {
    return '已打乱 · $count 步';
  }

  @override
  String solvedToast(String time, int moves) {
    return '复原 · $time · $moves 步';
  }

  @override
  String sizeToast(int n, int count) {
    return '$n×$n · $count 颗果冻块';
  }

  @override
  String solvingDoneToast(String time, int moves) {
    return '复原 · $time · $moves 步';
  }

  @override
  String get toastFirstTwist => '第一次扭转';

  @override
  String get toastFirstFace => '第一面！';

  @override
  String get toastFirstLayer => '第一层！';

  @override
  String get toastTwoLayers => '两层了！';

  @override
  String get toastNothingToUndo => '没有可撤销的';

  @override
  String get toastAlreadySolved => '已经复原了 · 戳戳它';

  @override
  String get toastSolvePaused => '复原暂停 · 该你了';

  @override
  String get toastReset => '已重置 · 新鲜出炉';

  @override
  String get hintDragPoke => '拖动一面  ·  轻点戳一戳';

  @override
  String get hintDragFull => '拖动面扭转  ·  轻点戳  ·  双指旋转视角';

  @override
  String get specimenLabel => '可戳  ·  样本 011';

  @override
  String get synthNote => 'DART 合成  ·  120 赫兹';

  @override
  String get jellyImpressed => '果冻被你折服了。';

  @override
  String get flavorCoconut => '椰奶';

  @override
  String get flavorLemon => '柠檬';

  @override
  String get flavorLime => '青柠';

  @override
  String get flavorBlueberry => '蓝莓';

  @override
  String get flavorCherry => '樱桃';

  @override
  String get flavorTangerine => '柑橘';

  @override
  String get unlockTitle => '解锁 5×5 和 6×6';

  @override
  String unlockFor(String price) {
    return '$price 解锁';
  }

  @override
  String get unlockBody =>
      '两个更大的方块，一次小额解锁。5×5 和 6×6 加入免费的 2×2、3×3、4×4，未来扩展型号也包含在内。';

  @override
  String get oneTimeNote => '一次性买断，由商店处理付款，无订阅。';

  @override
  String get restoreNote => '同一商店账号可随时恢复。';

  @override
  String get unlockedMsg => '扩展型号已在此设备解锁，登录同一商店账号的设备均可恢复。';

  @override
  String get storeUnavailable => '商店不可用';

  @override
  String get supportEmailCopied => '客服邮箱已复制';

  @override
  String get moreCubeMoreWobble => '方块越大，晃得越欢。';

  @override
  String get aboutTagline => '一个小巧光亮的谜题。';

  @override
  String get aboutDescription => '软软的身体，一丝不苟的灵魂。';

  @override
  String get privacyBody => '无账号。无广告。无统计。应用不收集任何个人数据。';

  @override
  String get viewFullPolicy => '查看完整隐私政策';
}
