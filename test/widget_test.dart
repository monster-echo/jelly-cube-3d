import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_cube_3d/jelly_cube_3d.dart';

void main() {
  testWidgets('instrument boots and paints the specimen', (tester) async {
    await tester.pumpWidget(const JellyCubeApp());
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.byKey(const ValueKey<String>('jelly-canvas')), findsOneWidget);
    expect(find.text('Jelly Cube'), findsOneWidget);
    final controller = JellyCubeApp.of(
      tester.element(find.byKey(const ValueKey<String>('jelly-canvas'))),
    );
    expect(controller, isNotNull);
    expect(controller!.state()['size'], 3);
  });

  testWidgets('size switch reaches 4x4 through the phone sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(JellyCubeApp(controller: controller));
    await tester.pump();
    controller.setSize(4);
    await tester.pump(const Duration(milliseconds: 20));
    expect(controller.state()['size'], 4);
    await tester.pump(const Duration(seconds: 3));
    expect(controller.cube.cubies.length, 56);
  });

  testWidgets('a real stage drag turns a slice', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(JellyCubeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 50));
    expect(controller.hitTest(const Offset(195, 420)), isNotNull);
    final before = controller.moves;
    await tester.dragFrom(
      const Offset(195, 420),
      const Offset(0, -70),
      touchSlopX: 0,
      touchSlopY: 0,
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.moves, greaterThan(before));
    expect(controller.cube.isSolved, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('tool tiles select and the drop tool drops the cube', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(JellyCubeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Drop'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.tool, JellyTool.drop);
    await tester.tapAt(const Offset(195, 420));
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.lift, greaterThan(0.2));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('two fingers preempt a turn without throwing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(JellyCubeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 60));
    final first = await tester.startGesture(const Offset(180, 420));
    await first.moveBy(const Offset(0, -35));
    await tester.pump(const Duration(milliseconds: 30));
    final second = await tester.startGesture(const Offset(240, 420));
    await tester.pump(const Duration(milliseconds: 20));
    await first.moveBy(const Offset(-20, 0));
    await second.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await first.up();
    await second.up();
    await tester.pump(const Duration(seconds: 3));
    expect(controller.cube.isIntact, isTrue);
  });

  testWidgets('phone/tablet layouts and text scaling paint without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    for (final size in <Size>[
      const Size(320, 568),
      const Size(390, 844),
      const Size(834, 1210),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      final controller = JellyCubeController();
      await tester.pumpWidget(JellyCubeApp(controller: controller));
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        find.byKey(const ValueKey<String>('jelly-canvas')),
        findsOneWidget,
        reason: 'canvas at $size',
      );
      expect(tester.takeException(), isNull, reason: 'layout at $size');
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('tablet settings card starts hidden and toggles open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(JellyCubeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 400));

    Rect labRect() => tester.getRect(find.text('Jelly Lab'));

    // Hidden by default: the card rests fully off the right edge so the
    // specimen owns the whole stage.
    expect(labRect().left, greaterThanOrEqualTo(1024));

    // The brand-bar toggle docks the card.
    await tester.tap(find.byKey(const ValueKey<String>('panel-toggle')));
    await tester.pump(); // kick the tween (ticker starts on this frame)
    await tester.pump(const Duration(milliseconds: 400));
    expect(labRect().left, lessThan(1024 - 280));

    // The brand-bar toggle can send it away again.
    await tester.tap(find.byKey(const ValueKey<String>('panel-toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(labRect().left, greaterThanOrEqualTo(1024));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('controller.startDemo hides all chrome', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(JellyCubeApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 60));
    controller.startDemo(freezeAt: 1.7);
    await tester.pump(const Duration(milliseconds: 80));
    expect(controller.demoMode, isTrue);
    expect(find.text('Jelly Cube'), findsNothing);
    expect(find.byKey(const ValueKey<String>('jelly-canvas')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
