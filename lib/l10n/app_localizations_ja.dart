// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class LJa extends L {
  LJa([String locale = 'ja']) : super(locale);

  @override
  String get softness => 'やわらかさ';

  @override
  String get speed => '速度';

  @override
  String get sound => '音量';

  @override
  String get haptics => '振動';

  @override
  String get hapticsSub => 'クリック＆スクワッシュ';

  @override
  String get hapticsSubShort => 'クリック';

  @override
  String get calmMode => 'おだやかモード';

  @override
  String get calm => 'おだやか';

  @override
  String get lessWobble => '揺れを減らす';

  @override
  String get muted => 'ミュート中';

  @override
  String get mute => 'ミュート';

  @override
  String get unmute => 'ミュート解除';

  @override
  String get undo => '元に戻す';

  @override
  String get reset => 'リセット';

  @override
  String get center => 'センター';

  @override
  String get scramble => 'シャッフル';

  @override
  String get solve => '完成へ';

  @override
  String get close => '閉じる';

  @override
  String get privacy => 'プライバシー';

  @override
  String get privacySupport => 'プライバシーとサポート';

  @override
  String get restorePurchases => '購入を復元';

  @override
  String get copySupportEmail => 'サポートメールをコピー';

  @override
  String get openSourceLicenses => 'オープンソースライセンス';

  @override
  String get toolTwist => 'ひねる';

  @override
  String get toolSpin => '回す';

  @override
  String get toolPoke => 'つつく';

  @override
  String get toolDrop => '落とす';

  @override
  String get sectionFlavors => 'フレーバー';

  @override
  String get sectionTexture => 'テクスチャ';

  @override
  String get sectionFaces => '面';

  @override
  String get sectionMoves => '手数';

  @override
  String get sectionState => '状態';

  @override
  String get controlStation => 'コントロール';

  @override
  String get jellyControls => 'ゼリーコントロール';

  @override
  String get jellyLab => 'ゼリー研究所';

  @override
  String get extraTypes => '追加タイプ';

  @override
  String get jellyPass => 'ゼリーパス';

  @override
  String get sectionPurchases => '購入';

  @override
  String get sectionPrivacy => 'プライバシー';

  @override
  String get sectionSupport => 'サポート';

  @override
  String get statusReady => '準備完了';

  @override
  String get statusSolved => '完成';

  @override
  String get statusInPlay => 'プレイ中';

  @override
  String get statusMixing => '混合中';

  @override
  String get statusSolving => '解決中';

  @override
  String get statusTwisting => 'ひねり中';

  @override
  String get statusDropping => '落下中';

  @override
  String get statusPoking => 'つつき中';

  @override
  String get statusOrbiting => '回視中';

  @override
  String get statusScrambling => 'シャッフル中';

  @override
  String get statusMelting => '溶け中';

  @override
  String get statusSolvedByHand => '手で完成';

  @override
  String get demoBadge => 'デモ';

  @override
  String get owned => '購入済み';

  @override
  String solvingProgress(int index, int total) {
    return '解決中 $index / $total';
  }

  @override
  String scrambledToast(int count) {
    return 'シャッフル完了 · $count 手';
  }

  @override
  String solvedToast(String time, int moves) {
    return '完成 · $time · $moves 手';
  }

  @override
  String sizeToast(int n, int count) {
    return '$n×$n · ゼリー $count 個';
  }

  @override
  String solvingDoneToast(String time, int moves) {
    return '完成 · $time · $moves 手';
  }

  @override
  String get toastFirstTwist => '初めてのひねり';

  @override
  String get toastFirstFace => '初めての面！';

  @override
  String get toastFirstLayer => '最初のレイヤー！';

  @override
  String get toastTwoLayers => '2 レイヤー！';

  @override
  String get toastNothingToUndo => '元に戻すものがありません';

  @override
  String get toastAlreadySolved => '完成済み · つついてみて';

  @override
  String get toastSolvePaused => '自動解決を一時停止 · あなたの手番';

  @override
  String get toastReset => 'リセット · 冷蔵庫から出したて';

  @override
  String get hintDragPoke => '面をドラッグ  ·  タップでつつく';

  @override
  String get hintDragFull => '面をドラッグしてひねる  ·  タップでつつく  ·  2 本指で視点回転';

  @override
  String get specimenLabel => 'つつける  ·  標本 011';

  @override
  String get synthNote => 'DART 合成  ·  120 Hz';

  @override
  String get jellyImpressed => 'ゼリーが感心している。';

  @override
  String get flavorCoconut => 'ココナッツ';

  @override
  String get flavorLemon => 'レモン';

  @override
  String get flavorLime => 'ライム';

  @override
  String get flavorBlueberry => 'ブルーベリー';

  @override
  String get flavorCherry => 'チェリー';

  @override
  String get flavorTangerine => 'タンジェリン';

  @override
  String get unlockTitle => '5×5 と 6×6 を解放';

  @override
  String unlockFor(String price) {
    return '$price で解放';
  }

  @override
  String get unlockBody =>
      '大きなキューブ 2 種をワンサイズの解放で。5×5 と 6×6 が無料の 2×2・3×3・4×4 に加わり、今後の追加タイプも含まれます。';

  @override
  String get oneTimeNote => '買い切り。決済はストアが処理します。サブスクではありません。';

  @override
  String get restoreNote => '同じストアアカウントならいつでも復元できます。';

  @override
  String get unlockedMsg => '追加タイプはこの端末で解放済み。同じストアアカウントの端末なら復元できます。';

  @override
  String get storeUnavailable => 'ストアを利用できません';

  @override
  String get supportEmailCopied => 'サポートメールをコピーしました';

  @override
  String get moreCubeMoreWobble => '大きいキューブル、大きく揺れる。';

  @override
  String get aboutTagline => '小さくて、つややかなパズル。';

  @override
  String get aboutDescription => 'やわらかい体に、整数パーフェクトな魂。';

  @override
  String get privacyBody => 'アカウントなし。広告なし。解析なし。個人データは収集しません。';

  @override
  String get viewFullPolicy => 'プライバシーポリシー全文を見る';
}
