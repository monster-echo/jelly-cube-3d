// Jelly Cube 3D — discrete, drift-free puzzle engine.
//
// Integer lattice coordinates are stored in "doubled" units: for a 3x3 the
// centres are {-2, 0, 2}; for a 4x4 {-3, -1, 1, 3}.  Every position and every
// orientation coefficient is an int, so turns cannot accumulate float error.
import 'dart:math' as math;

const int faceU = 0;
const int faceD = 1;
const int faceF = 2;
const int faceB = 3;
const int faceR = 4;
const int faceL = 5;

const List<String> kFaceNames = <String>['U', 'D', 'F', 'B', 'R', 'L'];
const List<String> kFaceLetters = <String>['W', 'Y', 'G', 'B', 'R', 'O'];
const List<String> kFlavorNames = <String>[
  'Coconut milk',
  'Lemon',
  'Lime',
  'Blueberry',
  'Cherry',
  'Tangerine',
];

/// Flavor index is deliberately identical to the face index it starts on.
const List<int> kFaceFlavor = <int>[0, 1, 2, 3, 4, 5];

const List<Int3> kFaceNormals = <Int3>[
  Int3(0, 1, 0), // U
  Int3(0, -1, 0), // D
  Int3(0, 0, 1), // F
  Int3(0, 0, -1), // B
  Int3(1, 0, 0), // R
  Int3(-1, 0, 0), // L
];

class Int3 {
  const Int3(this.x, this.y, this.z);
  final int x;
  final int y;
  final int z;

  int operator [](int axis) => axis == 0 ? x : (axis == 1 ? y : z);
  Int3 operator +(Int3 o) => Int3(x + o.x, y + o.y, z + o.z);
  Int3 operator *(int s) => Int3(x * s, y * s, z * s);
  @override
  bool operator ==(Object other) =>
      other is Int3 && other.x == x && other.y == y && other.z == z;
  @override
  int get hashCode => Object.hash(x, y, z);
  @override
  String toString() => '($x,$y,$z)';
}

/// Row-major 3x3 integer orthogonal matrix.
class Mat3i {
  const Mat3i(this.m);
  final List<int> m;

  static const Mat3i identity = Mat3i(<int>[1, 0, 0, 0, 1, 0, 0, 0, 1]);

  Int3 apply(Int3 v) => Int3(
    m[0] * v.x + m[1] * v.y + m[2] * v.z,
    m[3] * v.x + m[4] * v.y + m[5] * v.z,
    m[6] * v.x + m[7] * v.y + m[8] * v.z,
  );

  Mat3i operator *(Mat3i o) {
    final out = List<int>.filled(9, 0);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        var s = 0;
        for (var k = 0; k < 3; k++) {
          s += m[r * 3 + k] * o.m[k * 3 + c];
        }
        out[r * 3 + c] = s;
      }
    }
    return Mat3i(out);
  }

  int get determinant =>
      m[0] * (m[4] * m[8] - m[5] * m[7]) -
      m[1] * (m[3] * m[8] - m[5] * m[6]) +
      m[2] * (m[3] * m[7] - m[4] * m[6]);

  bool get isOrthogonal {
    final p = this * transpose();
    for (var i = 0; i < 9; i++) {
      final want = (i % 4 == 0) ? 1 : 0;
      if (p.m[i] != want) return false;
    }
    return determinant == 1;
  }

  Mat3i transpose() =>
      Mat3i(<int>[m[0], m[3], m[6], m[1], m[4], m[7], m[2], m[5], m[8]]);

  @override
  String toString() => 'Mat3i($m)';
}

Mat3i rotationMatrix(int axis, int quarterTurns) {
  var q = quarterTurns % 4;
  if (q < 0) q += 4;
  switch (q) {
    case 0:
      return Mat3i.identity;
    case 1:
      // +90° about a right-handed axis.
      if (axis == 0) return const Mat3i(<int>[1, 0, 0, 0, 0, -1, 0, 1, 0]);
      if (axis == 1) return const Mat3i(<int>[0, 0, 1, 0, 1, 0, -1, 0, 0]);
      return const Mat3i(<int>[0, -1, 0, 1, 0, 0, 0, 0, 1]);
    case 2:
      if (axis == 0) return const Mat3i(<int>[1, 0, 0, 0, -1, 0, 0, 0, -1]);
      if (axis == 1) return const Mat3i(<int>[-1, 0, 0, 0, 1, 0, 0, 0, -1]);
      return const Mat3i(<int>[-1, 0, 0, 0, -1, 0, 0, 0, 1]);
    default:
      // -90° turns (including every prime move).
      if (axis == 0) return const Mat3i(<int>[1, 0, 0, 0, 0, 1, 0, -1, 0]);
      if (axis == 1) return const Mat3i(<int>[0, 0, -1, 0, 1, 0, 1, 0, 0]);
      return const Mat3i(<int>[0, 1, 0, -1, 0, 0, 0, 0, 1]);
  }
}

Int3 rotatePosition(Int3 p, int axis, int quarterTurns) =>
    rotationMatrix(axis, quarterTurns).apply(p);

class JellyCubelet {
  JellyCubelet({
    required this.pos,
    required this.orientation,
    required this.stickers,
    required this.id,
  });

  /// Doubled lattice coordinate.
  Int3 pos;

  /// Local -> world.
  Mat3i orientation;

  /// Local face indices that carry a colored flavor layer.
  final Set<int> stickers;
  final int id;
}

/// One logical slice move. `coordinates` contains doubled lattice coordinates
/// along `axis`; `quarterTurns` is signed and uses the right-hand rule.
class JellyMove {
  const JellyMove({
    required this.axis,
    required this.coordinates,
    required this.quarterTurns,
    required this.notation,
  });

  final int axis;
  final List<int> coordinates;
  final int quarterTurns;
  final String notation;

  int get layerKey {
    final c = List<int>.of(coordinates)..sort();
    return Object.hash(
      axis,
      Object.hashAll(c),
      quarterTurns.isNegative ? 1 : 0,
    );
  }

  String get sliceKey {
    final c = List<int>.of(coordinates)..sort();
    return '$axis:${c.join(',')}';
  }

  JellyMove inverse() => JellyMove(
    axis: axis,
    coordinates: coordinates,
    quarterTurns: -quarterTurns,
    notation: _inverseNotation(notation),
  );

  JellyMove withQuarterTurns(int turns) => JellyMove(
    axis: axis,
    coordinates: coordinates,
    quarterTurns: turns,
    notation: notation,
  );

  static String _inverseNotation(String n) {
    if (n.endsWith('2')) return n;
    if (n.endsWith("'")) return n.substring(0, n.length - 1);
    return "$n'";
  }

  @override
  String toString() => notation;
}

class JellyCube {
  JellyCube._(this.size, this.maxCoord, this.cubies);

  factory JellyCube.solved(int size) {
    if (size < 2 || size > 6) {
      throw ArgumentError.value(size, 'size', 'Jelly supports 2x2 through 6x6');
    }
    final maxCoord = size - 1;
    final coords = <int>[for (var c = -maxCoord; c <= maxCoord; c += 2) c];
    final cubies = <JellyCubelet>[];
    var id = 0;
    for (final x in coords) {
      for (final y in coords) {
        for (final z in coords) {
          final isShell =
              x.abs() == maxCoord || y.abs() == maxCoord || z.abs() == maxCoord;
          if (!isShell) continue;
          final pos = Int3(x, y, z);
          final stickers = <int>{};
          for (var f = 0; f < 6; f++) {
            final n = kFaceNormals[f];
            if (pos.x * n.x + pos.y * n.y + pos.z * n.z == maxCoord) {
              stickers.add(f);
            }
          }
          cubies.add(
            JellyCubelet(
              pos: pos,
              orientation: Mat3i.identity,
              stickers: stickers,
              id: id++,
            ),
          );
        }
      }
    }
    return JellyCube._(size, maxCoord, cubies);
  }

  final int size;
  final int maxCoord;
  final List<JellyCubelet> cubies;

  List<JellyCubelet> layer(int axis, List<int> coordinates) {
    final set = coordinates.toSet();
    return cubies
        .where((c) => set.contains(c.pos[axis]))
        .toList(growable: false);
  }

  void apply(JellyMove move) {
    final affected = layer(move.axis, move.coordinates);
    final rot = rotationMatrix(move.axis, move.quarterTurns);
    for (final cubie in affected) {
      cubie.pos = rot.apply(cubie.pos);
      cubie.orientation = rot * cubie.orientation;
    }
  }

  /// Returns flavor indices in row-major order for a face. `-1` means empty.
  List<int> faceletFlavors(int face) {
    final n = size;
    final out = List<int>.filled(n * n, -1);
    final normal = kFaceNormals[face];
    final axis = normal.x != 0 ? 0 : (normal.y != 0 ? 1 : 2);
    final side = normal[axis];

    // Tangents chosen so the rendered grid reads naturally from the outside.
    final (uAxis, uSign, vAxis, vSign) = switch (face) {
      faceU => (0, 1, 2, 1),
      faceD => (0, 1, 2, -1),
      faceF => (0, 1, 1, 1),
      faceB => (0, -1, 1, 1),
      faceR => (2, -1, 1, 1),
      _ => (2, 1, 1, 1),
    };

    final values = <int>[for (var c = -maxCoord; c <= maxCoord; c += 2) c];
    final indexOf = <int, int>{
      for (var i = 0; i < values.length; i++) values[i]: i,
    };

    for (final cubie in cubies) {
      // A facelet only appears if this cubie's *current* world normal matches.
      for (final localFace in cubie.stickers) {
        final worldNormal = cubie.orientation.apply(kFaceNormals[localFace]);
        if (worldNormal != normal) continue;
        if (cubie.pos[axis] != side * maxCoord) continue;
        final u = indexOf[cubie.pos[uAxis] * uSign];
        final v = indexOf[cubie.pos[vAxis] * vSign];
        if (u == null || v == null) continue;
        out[v * n + u] = kFaceFlavor[localFace];
      }
    }
    return out;
  }

  bool get isSolved {
    for (var f = 0; f < 6; f++) {
      final flavors = faceletFlavors(f);
      final first = flavors.first;
      if (first < 0 || flavors.any((c) => c != first)) return false;
    }
    return true;
  }

  int get solvedFaceCount {
    var count = 0;
    for (var f = 0; f < 6; f++) {
      final flavors = faceletFlavors(f);
      final first = flavors.first;
      if (first >= 0 && flavors.every((c) => c == first)) count++;
    }
    return count;
  }

  /// Human-readable face strings, ordered U,R,F,D,L,B.
  List<String> faceStrings({bool includeName = true}) {
    const order = <int>[faceU, faceR, faceF, faceD, faceL, faceB];
    final out = <String>[];
    for (final f in order) {
      final flavors = faceletFlavors(f);
      final rows = <String>[];
      for (var r = 0; r < size; r++) {
        final buf = StringBuffer();
        for (var c = 0; c < size; c++) {
          final flavor = flavors[r * size + c];
          buf.write(flavor < 0 ? '?' : kFaceLetters[flavor]);
        }
        rows.add(buf.toString());
      }
      out.add(
        includeName ? '${kFaceNames[f]}:${rows.join('/')}' : rows.join('/'),
      );
    }
    return out;
  }

  /// Structural self-check used by the test hook.
  bool get isIntact {
    final seen = <String>{};
    for (final c in cubies) {
      if (c.pos.x.abs() > maxCoord ||
          c.pos.y.abs() > maxCoord ||
          c.pos.z.abs() > maxCoord) {
        return false;
      }
      if (!c.orientation.isOrthogonal) return false;
      final key = '${c.pos.x},${c.pos.y},${c.pos.z}';
      if (!seen.add(key)) return false;
      for (var i = 0; i < 9; i++) {
        if (c.orientation.m[i] < -1 || c.orientation.m[i] > 1) return false;
      }
    }
    return seen.length == cubies.length;
  }

  /// An unmodifiable view of the discrete state for debug/test screens.
  Map<String, dynamic> debugSnapshot() => <String, dynamic>{
    'size': size,
    'cubies': cubies.length,
    'intact': isIntact,
    'solved': isSolved,
    'solvedFaces': solvedFaceCount,
    'faces': faceStrings(),
  };
}

/// Parses standard 3x3 notation plus lowercase wide turns (r/u/f…) and M/E/S.
/// Whole-cube rotations x/y/z are accepted too.
JellyMove parseJellyMove(String input, int size) {
  var raw = input.trim();
  if (raw.isEmpty) throw FormatException('Empty move');
  raw = raw.replaceAll('’', "'").replaceAll('′', "'");

  var wide = false;
  if (raw.length >= 2 && raw[1] == 'w') {
    wide = true;
    raw = raw[0] + raw.substring(2);
  }
  var letter = raw[0];
  if (letter == letter.toLowerCase() && 'rludfb'.contains(letter)) {
    wide = true;
    letter = letter.toUpperCase();
  }

  var prime = false;
  var double = false;
  final suffix = raw.substring(1);
  if (suffix == "'") {
    prime = true;
  } else if (suffix == '2') {
    double = true;
  } else if (suffix == "2'") {
    double = true;
    prime = true;
  } else if (suffix.isNotEmpty) {
    throw FormatException('Unsupported move "$input"');
  }

  final max = size - 1;
  final outer = max;
  final inner = max - 2;

  int axis;
  int baseSign;
  bool whole = false;
  switch (letter) {
    case 'R':
      axis = 0;
      baseSign = -1;
      break;
    case 'L':
      axis = 0;
      baseSign = 1;
      break;
    case 'U':
      axis = 1;
      baseSign = -1;
      break;
    case 'D':
      axis = 1;
      baseSign = 1;
      break;
    case 'F':
      axis = 2;
      baseSign = -1;
      break;
    case 'B':
      axis = 2;
      baseSign = 1;
      break;
    case 'M':
      axis = 0;
      baseSign = 1;
      break;
    case 'E':
      axis = 1;
      baseSign = 1;
      break;
    case 'S':
      axis = 2;
      baseSign = -1;
      break;
    case 'x':
      axis = 0;
      baseSign = -1;
      whole = true;
      break;
    case 'y':
      axis = 1;
      baseSign = -1;
      whole = true;
      break;
    case 'z':
      axis = 2;
      baseSign = -1;
      whole = true;
      break;
    default:
      throw FormatException('Unknown move "$input"');
  }

  List<int> coords;
  if (whole || letter == 'x' || letter == 'y' || letter == 'z') {
    coords = <int>[for (var c = -max; c <= max; c += 2) c];
  } else if (letter == 'M' || letter == 'E' || letter == 'S') {
    coords = <int>[for (var c = -inner; c <= inner; c += 2) c];
  } else if (wide) {
    coords = letter == 'R' || letter == 'U' || letter == 'F'
        ? <int>[outer, if (inner >= -max) inner]
        : <int>[-outer, if (inner >= -max) -inner];
  } else {
    coords = <int>[
      (letter == 'R' || letter == 'U' || letter == 'F') ? outer : -outer,
    ];
  }

  final turns = baseSign * (double ? 2 : 1) * (prime ? -1 : 1);
  final canonical =
      '$letter${wide ? 'w' : ''}${double ? '2' : ''}${prime ? "'" : ''}';
  return JellyMove(
    axis: axis,
    coordinates: coords,
    quarterTurns: turns,
    notation: canonical,
  );
}

/// Random legal scramble. Avoids immediately repeating the same slice.
List<JellyMove> generateScramble(int size, math.Random rng) {
  final count = size == 2 ? 12 : (size == 3 ? 25 : 40);
  const faces = <String>['R', 'L', 'U', 'D', 'F', 'B'];
  const suffixes = <String>['', "'", '2'];
  final moves = <JellyMove>[];
  String? previous;
  while (moves.length < count) {
    final face = faces[rng.nextInt(faces.length)];
    if (face == previous) continue;
    previous = face;
    final notation = face + suffixes[rng.nextInt(suffixes.length)];
    moves.add(parseJellyMove(notation, size));
  }
  return moves;
}

/// Cancels adjacent turns on the same slice and combines repeated turns.
List<JellyMove> simplifyMoves(List<JellyMove> input) {
  final out = <JellyMove>[];
  for (final move in input) {
    if (out.isNotEmpty && out.last.sliceKey == move.sliceKey) {
      final sum = out.last.quarterTurns + move.quarterTurns;
      final normalized = ((sum % 4) + 4) % 4;
      out.removeLast();
      if (normalized != 0) {
        final turns = normalized == 3 ? -1 : normalized;
        out.add(move.withQuarterTurns(turns));
      }
    } else {
      out.add(move);
    }
  }
  return out;
}
