import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_cube_3d/jelly_cube_3d.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('controller survives 10,000 automated moves and stays intact', () {
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    controller.setViewport(
      const Size(390, 844),
      const Rect.fromLTRB(0, 68, 390, 812),
    );
    final rng = math.Random(44);
    const moves = <String>[
      'R',
      "R'",
      'R2',
      'L',
      "L'",
      'U',
      "U'",
      'U2',
      'D',
      "D'",
      'F',
      "F'",
      'F2',
      'B',
      "B'",
    ];
    for (var i = 0; i < 10000; i++) {
      controller.move(moves[rng.nextInt(moves.length)]);
      if (i % 1000 == 0) {
        expect(controller.state()['intact'], isTrue);
      }
    }
    final state = controller.state();
    expect(state['intact'], isTrue);
    expect(state['moves'], 10000);
  });

  test('R U R-prime U-prime six times is solved through the controller', () {
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    for (var i = 0; i < 6; i++) {
      for (final m in <String>['R', 'U', "R'", "U'"]) {
        controller.move(m);
      }
    }
    expect(controller.cube.isSolved, isTrue);
    expect(controller.state()['history'], hasLength(24));
  });

  test('undo, reset and size switching restore strict state', () {
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    controller.move('R');
    expect(controller.cube.isSolved, isFalse);
    controller.undo();
    expect(controller.cube.isSolved, isTrue);
    controller.setSize(4);
    expect(controller.state()['size'], 4);
    expect(controller.cube.cubies.length, 56);
    expect(controller.state()['solved'], isTrue);
    controller.reset();
    expect(controller.state()['moves'], 0);
    controller.setSize(5);
    expect(controller.cube.cubies.length, 98);
    expect(controller.state()['solved'], isTrue);
    controller.setSize(6);
    expect(controller.cube.cubies.length, 152);
    expect(controller.state()['solved'], isTrue);
  });

  test('extra cube types unlock state is exposed without a store in tests', () {
    final locked = JellyCubeController();
    addTearDown(locked.dispose);
    expect(locked.extraTypesUnlocked, isFalse);
    final unlocked = JellyCubeController(debugUnlockExtraTypes: true);
    addTearDown(unlocked.dispose);
    expect(unlocked.extraTypesUnlocked, isTrue);
    unlocked.setSize(6);
    expect(unlocked.state()['size'], 6);
  });

  test('a screen drag commits a slice turn', () {
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    controller.setViewport(
      const Size(390, 844),
      const Rect.fromLTRB(0, 68, 390, 812),
    );
    final p = const Offset(195, 390);
    final hit = controller.hitTest(p);
    expect(hit, isNotNull);
    expect(controller.pick(p)?['face'], isA<int>());
    controller.drag(p, p + const Offset(55, -35));
    expect(controller.state()['moves'], greaterThan(0));
    expect(controller.state()['solved'], isFalse);
  });

  test('2x2, 3x3 and 4x4 all accept a stage drag', () {
    for (final n in <int>[2, 3, 4]) {
      final controller = JellyCubeController(size: n);
      addTearDown(controller.dispose);
      controller.setViewport(
        const Size(390, 844),
        const Rect.fromLTRB(0, 68, 390, 812),
      );
      expect(controller.hitTest(const Offset(195, 400)), isNotNull);
      controller.drag(const Offset(195, 400), const Offset(240, 360));
      expect(controller.cube.isSolved, isFalse, reason: 'size $n');
      expect(controller.cube.isIntact, isTrue, reason: 'size $n');
    }
  });

  test('melt preview raises the discreet badge', () {
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    controller.previewMelt();
    expect(controller.meltBadge, isTrue);
    expect(controller.meltPlaying, isTrue);
  });

  test('frozen demo builds an exact frame without exceptions', () {
    final controller = JellyCubeController();
    addTearDown(controller.dispose);
    controller.setViewport(
      const Size(390, 844),
      const Rect.fromLTRB(0, 0, 390, 844),
    );
    controller.startDemo(freezeAt: 1.7);
    expect(controller.demoMode, isTrue);
    expect(controller.demoFrozen, isTrue);
    expect(controller.size, 3);
    expect(controller.demoTime, closeTo(1.7, 0.01));
  });

  test('a manual hand-solve triggers the melt easter egg', () async {
    final controller = JellyCubeController(size: 2);
    addTearDown(controller.dispose);
    await controller.scramble(23);
    final scramble = List<String>.of(
      controller.state()['history'] as List<String>,
    );
    for (final move in scramble.reversed) {
      controller.move(_inverse(move));
    }
    expect(controller.cube.isSolved, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(controller.meltBadge, isTrue);
    expect(controller.meltPlaying, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('2x2 scramble then solve returns to solved', () async {
    final controller = JellyCubeController(size: 2);
    addTearDown(controller.dispose);
    await controller.scramble(11);
    expect(controller.cube.isSolved, isFalse);
    await controller.solve();
    expect(controller.cube.isSolved, isTrue);
    expect(controller.state()['solved'], isTrue);
    expect(controller.state()['history'], isEmpty);
  }, timeout: const Timeout(Duration(seconds: 30)));
}

String _inverse(String notation) {
  if (notation.endsWith('2')) return notation;
  if (notation.endsWith("'")) {
    return notation.substring(0, notation.length - 1);
  }
  return "$notation'";
}
