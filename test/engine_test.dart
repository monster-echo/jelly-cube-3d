import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_cube_3d/src/engine.dart';

void main() {
  group('discrete engine', () {
    test('3x3 starts solved with 26 shell cubelets', () {
      final cube = JellyCube.solved(3);
      expect(cube.cubies.length, 26);
      expect(cube.isSolved, isTrue);
      expect(cube.solvedFaceCount, 6);
      expect(cube.isIntact, isTrue);
    });

    test('2x2 through 6x6 shell counts', () {
      expect(JellyCube.solved(2).cubies.length, 8);
      expect(JellyCube.solved(3).cubies.length, 26);
      expect(JellyCube.solved(4).cubies.length, 56);
      expect(JellyCube.solved(5).cubies.length, 98);
      expect(JellyCube.solved(6).cubies.length, 152);
    });

    test('6x6 accepts outer and wide turns', () {
      final cube = JellyCube.solved(6);
      cube.apply(parseJellyMove('R', 6));
      cube.apply(parseJellyMove('Uw', 6));
      expect(cube.isSolved, isFalse);
      expect(cube.isIntact, isTrue);
    });

    test('R U R prime U prime six times returns to solved', () {
      final cube = JellyCube.solved(3);
      final moves = <String>['R', 'U', "R'", "U'"];
      for (var i = 0; i < 6; i++) {
        for (final text in moves) {
          cube.apply(parseJellyMove(text, 3));
        }
      }
      expect(cube.isSolved, isTrue);
      expect(cube.isIntact, isTrue);
    });

    test('10,000 random quarter turns leave integer state intact', () {
      for (final n in <int>[2, 3, 4]) {
        final cube = JellyCube.solved(n);
        final rng = math.Random(9127 + n);
        const letters = <String>['R', 'L', 'U', 'D', 'F', 'B'];
        const suffixes = <String>['', "'", '2'];
        for (var i = 0; i < 10000; i++) {
          final notation =
              letters[rng.nextInt(6)] + suffixes[rng.nextInt(suffixes.length)];
          cube.apply(parseJellyMove(notation, n));
          if (i % 997 == 0) expect(cube.isIntact, isTrue, reason: 'n=$n i=$i');
        }
        expect(cube.isIntact, isTrue, reason: 'n=$n final');
        expect(cube.cubies.length, n == 2 ? 8 : (n == 3 ? 26 : 56));
      }
    });

    test('wide and inner slice moves parse on 4x4', () {
      final cube = JellyCube.solved(4);
      cube.apply(parseJellyMove('r', 4));
      cube.apply(parseJellyMove("r'", 4));
      expect(cube.isSolved, isTrue);
      final wide = parseJellyMove('Rw', 4);
      expect(wide.coordinates.length, 2);
    });

    test('simplify preserves the net transform', () {
      final moves = <JellyMove>[
        parseJellyMove('R', 3),
        parseJellyMove('U', 3),
        parseJellyMove("U'", 3),
        parseJellyMove('R', 3),
      ];
      final simplified = simplifyMoves(moves);
      expect(simplified.length, 1);
      expect(simplified.first.notation, 'R');
      final a = JellyCube.solved(3);
      final b = JellyCube.solved(3);
      for (final m in moves) {
        a.apply(m);
      }
      for (final m in simplified) {
        b.apply(m);
      }
      expect(_flavors(a), _flavors(b));
    });
  });
}

List<List<int>> _flavors(JellyCube cube) =>
    List<List<int>>.generate(6, cube.faceletFlavors);
