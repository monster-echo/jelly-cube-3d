import 'dart:math' as math;
import 'dart:ui';

import 'engine.dart';

class V3 {
  const V3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  static const V3 zero = V3(0, 0, 0);
  static const V3 up = V3(0, 1, 0);

  V3 operator +(V3 o) => V3(x + o.x, y + o.y, z + o.z);
  V3 operator -(V3 o) => V3(x - o.x, y - o.y, z - o.z);
  V3 operator *(double s) => V3(x * s, y * s, z * s);
  V3 operator -() => V3(-x, -y, -z);
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get normalized {
    final l = length;
    return l < 1e-9 ? zero : V3(x / l, y / l, z / l);
  }

  V3 cross(V3 o) => V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  V3 rotateX(double a) {
    final c = math.cos(a), s = math.sin(a);
    return V3(x, y * c - z * s, y * s + z * c);
  }

  V3 rotateY(double a) {
    final c = math.cos(a), s = math.sin(a);
    return V3(x * c + z * s, y, -x * s + z * c);
  }

  V3 rotateZ(double a) {
    final c = math.cos(a), s = math.sin(a);
    return V3(x * c - y * s, x * s + y * c, z);
  }

  V3 rotateAxis(V3 axis, double angle) {
    final a = axis.normalized;
    final c = math.cos(angle), s = math.sin(angle);
    return this * c + a.cross(this) * s + a * (a.dot(this) * (1 - c));
  }

  Int3 toInt3() => Int3(x.round(), y.round(), z.round());

  @override
  String toString() => 'V3($x,$y,$z)';
}

class Mat3 {
  const Mat3(this.m);
  final List<double> m;

  static const Mat3 identity = Mat3(<double>[1, 0, 0, 0, 1, 0, 0, 0, 1]);

  factory Mat3.fromMat3i(Mat3i m) =>
      Mat3(<double>[for (final v in m.m) v.toDouble()]);

  V3 apply(V3 v) => V3(
    m[0] * v.x + m[1] * v.y + m[2] * v.z,
    m[3] * v.x + m[4] * v.y + m[5] * v.z,
    m[6] * v.x + m[7] * v.y + m[8] * v.z,
  );

  Mat3 operator *(Mat3 o) {
    final out = List<double>.filled(9, 0);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        var s = 0.0;
        for (var k = 0; k < 3; k++) {
          s += m[r * 3 + k] * o.m[k * 3 + c];
        }
        out[r * 3 + c] = s;
      }
    }
    return Mat3(out);
  }

  Mat3 transpose() =>
      Mat3(<double>[m[0], m[3], m[6], m[1], m[4], m[7], m[2], m[5], m[8]]);
}

class JellyCamera {
  const JellyCamera({
    this.yaw = 0.58,
    this.pitch = 0.43,
    this.zoom = 1.0,
    this.rock = 0.0,
  });

  final double yaw;
  final double pitch;
  final double zoom;

  /// Screen-space body rock in radians, driven by the soft-body spring.
  final double rock;

  JellyCamera copyWith({
    double? yaw,
    double? pitch,
    double? zoom,
    double? rock,
  }) => JellyCamera(
    yaw: yaw ?? this.yaw,
    pitch: pitch ?? this.pitch,
    zoom: zoom ?? this.zoom,
    rock: rock ?? this.rock,
  );
}

class JellyProjection {
  JellyProjection({
    required this.canvasSize,
    required this.sceneRect,
    required this.cubeSize,
    required this.camera,
    this.lift = 0,
    this.squashY = 1,
    this.squashXZ = 1,
    this.cubeScale = 0.96,
  }) {
    final minDim = math.min(sceneRect.width, sceneRect.height);
    _baseScale = minDim * 0.55 / cubeSize;
    _scale = _baseScale * camera.zoom;
    center = Offset(
      sceneRect.center.dx,
      sceneRect.center.dy - sceneRect.height * 0.015,
    );
    pivotY = -cubeSize / 2;
    _cy = math.cos(camera.yaw);
    _sy = math.sin(camera.yaw);
    _cp = math.cos(camera.pitch);
    _sp = math.sin(camera.pitch);
    _cr = math.cos(camera.rock);
    _sr = math.sin(camera.rock);
  }

  final Size canvasSize;
  final Rect sceneRect;
  final int cubeSize;
  final JellyCamera camera;
  final double lift;
  final double squashY;
  final double squashXZ;
  final double cubeScale;

  late final double _baseScale;
  late final double _scale;
  late final double _cy;
  late final double _sy;
  late final double _cp;
  late final double _sp;
  late final double _cr;
  late final double _sr;

  late final Offset center;
  late final double pivotY;

  static const double _cameraDistance = 17.0;

  double get baseScale => _baseScale;
  double get scale => _scale;

  V3 view(V3 p) {
    final y = pivotY + (p.y - pivotY) * squashY + lift;
    final x = p.x * squashXZ;
    final z = p.z * squashXZ;
    final x1 = x * _cy - z * _sy;
    final z1 = x * _sy + z * _cy;
    final y2 = y * _cp - z1 * _sp;
    final z2 = y * _sp + z1 * _cp;
    return V3(x1, y2, z2);
  }

  Offset project(V3 p) {
    final v = view(p);
    final perspective = _cameraDistance / (_cameraDistance - v.z * 0.72);
    final px = center.dx + v.x * _scale * perspective;
    final py = center.dy - v.y * _scale * perspective;
    final dx = px - center.dx;
    final dy = py - center.dy;
    return Offset(
      center.dx + dx * _cr - dy * _sr,
      center.dy + dx * _sr + dy * _cr,
    );
  }

  double depthOf(V3 p) => view(p).z;

  /// Projects without the body-rock rotation; useful for UI labels.
  Offset projectStable(V3 p) {
    final v = view(p);
    final perspective = _cameraDistance / (_cameraDistance - v.z * 0.72);
    return Offset(
      center.dx + v.x * _scale * perspective,
      center.dy - v.y * _scale * perspective,
    );
  }

  double get screenPerUnit => _scale;

  V3 worldCubeletCenter(Int3 pos) => V3(pos.x / 2.0, pos.y / 2.0, pos.z / 2.0);

  V3 orientNormal(Mat3i orientation, int face) {
    final n = kFaceNormals[face];
    final w = orientation.apply(n);
    return V3(w.x.toDouble(), w.y.toDouble(), w.z.toDouble());
  }

  bool faceVisible(V3 worldNormal) {
    final v = view(worldNormal) - view(V3.zero);
    return v.z > -0.06;
  }

  /// The four world-space corners of a local face.
  List<V3> faceCorners(
    JellyCubelet cubie,
    int localFace, {
    double half = 0.48,
  }) {
    final normal = kFaceNormals[localFace];
    final centerWorld = worldCubeletCenter(cubie.pos);
    final orient = Mat3.fromMat3i(cubie.orientation);
    final n = V3(normal.x.toDouble(), normal.y.toDouble(), normal.z.toDouble());
    final wc = centerWorld + orient.apply(n * half);

    int axis = normal.x != 0 ? 0 : (normal.y != 0 ? 1 : 2);
    final tangents = <V3>[];
    for (var a = 0; a < 3; a++) {
      if (a == axis) continue;
      final t = <double>[0, 0, 0]..[a] = 1;
      tangents.add(orient.apply(V3(t[0], t[1], t[2])));
    }
    final t1 = tangents[0] * half;
    final t2 = tangents[1] * half;
    return <V3>[wc - t1 - t2, wc + t1 - t2, wc + t1 + t2, wc - t1 + t2];
  }

  JellyHit? pick(JellyCube cube, Offset point, {double tolerance = 12}) {
    JellyHit? exact;
    JellyHit? fuzzy;
    var bestExactDepth = -1e9;
    var bestFuzzyDistance = double.infinity;

    for (final cubie in cube.cubies) {
      final centerWorld = worldCubeletCenter(cubie.pos);
      for (var face = 0; face < 6; face++) {
        final normal = orientNormal(cubie.orientation, face);
        if (!faceVisible(normal)) continue;
        final corners = faceCorners(cubie, face);
        final poly = corners.map(project).toList(growable: false);
        if (_polygonArea(poly).abs() < 2) continue;
        final depth = depthOf(centerWorld);
        if (_containsPoint(poly, point)) {
          if (depth > bestExactDepth) {
            bestExactDepth = depth;
            exact = JellyHit(
              cubie: cubie,
              cubeletId: cubie.id,
              face: _worldFaceForNormal(normal),
              localFace: face,
              normal: normal,
              polygon: poly,
              depth: depth,
              screenCenter: _average(poly),
            );
          }
        } else {
          final d = _distanceToPolygon(poly, point);
          if (d <= tolerance && d < bestFuzzyDistance) {
            bestFuzzyDistance = d;
            fuzzy = JellyHit(
              cubie: cubie,
              cubeletId: cubie.id,
              face: _worldFaceForNormal(normal),
              localFace: face,
              normal: normal,
              polygon: poly,
              depth: depth,
              screenCenter: _average(poly),
            );
          }
        }
      }
    }
    return exact ?? fuzzy;
  }

  /// Returns axis/sign/coordinate for a drag across a picked face.
  JellyDragIntent? dragIntent(JellyHit hit, Offset drag) {
    if (drag.distance < 0.001) return null;
    final centerWorld =
        worldCubeletCenter(hit.cubie.pos) + hit.normal * (cubeScale / 2);
    final axisNormal = _dominantAxis(hit.normal);
    final candidates = <V3>[];
    for (var a = 0; a < 3; a++) {
      final e = <double>[0, 0, 0]..[a] = 1;
      final v = V3(e[0], e[1], e[2]);
      if (v.dot(axisNormal).abs() > 0.5) continue;
      candidates.add(v);
    }

    var best = -1.0;
    int? bestAxis;
    int bestSign = 1;
    for (final candidate in candidates) {
      final surfaceVelocity = candidate.cross(centerWorld) * 0.22;
      final p0 = project(centerWorld);
      final p1 = project(centerWorld + surfaceVelocity);
      final screen = p1 - p0;
      final len = screen.distance;
      if (len < 1e-5) continue;
      final alignment = screen.dx * drag.dx + screen.dy * drag.dy;
      final score = alignment.abs() / len;
      if (score > best) {
        best = score;
        bestAxis = candidate.x.abs() > 0.5
            ? 0
            : (candidate.y.abs() > 0.5 ? 1 : 2);
        bestSign = alignment >= 0 ? 1 : -1;
      }
    }
    if (bestAxis == null) return null;
    final coord = hit.cubie.pos[bestAxis];
    return JellyDragIntent(
      axis: bestAxis,
      sign: bestSign,
      coordinate: coord,
      notation: _sliceNotation(cubeSize, bestAxis, coord, bestSign),
    );
  }

  static V3 _dominantAxis(V3 n) {
    final ax = n.x.abs();
    final ay = n.y.abs();
    final az = n.z.abs();
    if (ax >= ay && ax >= az) return V3(n.x.sign, 0, 0);
    if (ay >= az) return V3(0, n.y.sign, 0);
    return V3(0, 0, n.z.sign);
  }

  static int _worldFaceForNormal(V3 n) {
    if (n.y > 0.5) return faceU;
    if (n.y < -0.5) return faceD;
    if (n.z > 0.5) return faceF;
    if (n.z < -0.5) return faceB;
    if (n.x > 0.5) return faceR;
    return faceL;
  }

  static String _sliceNotation(int n, int axis, int coord, int sign) {
    final max = n - 1;
    final suffix = sign < 0 ? '' : "'";
    if (coord == max) return <String>['R', 'U', 'F'][axis] + suffix;
    if (coord == -max) return <String>['L', 'D', 'B'][axis] + suffix;
    final fromPositive = (max - coord) ~/ 2 + 1;
    final fromNegative = (coord + max) ~/ 2 + 1;
    if (fromPositive <= fromNegative) {
      return '${fromPositive}R$suffix';
    }
    return '${fromNegative}L$suffix';
  }
}

class JellyDragIntent {
  const JellyDragIntent({
    required this.axis,
    required this.sign,
    required this.coordinate,
    required this.notation,
  });

  final int axis;
  final int sign;
  final int coordinate;
  final String notation;
}

class JellyHit {
  const JellyHit({
    required this.cubie,
    required this.cubeletId,
    required this.face,
    required this.localFace,
    required this.normal,
    required this.polygon,
    required this.depth,
    required this.screenCenter,
  });

  final JellyCubelet cubie;
  final int cubeletId;
  final int face;
  final int localFace;
  final V3 normal;
  final List<Offset> polygon;
  final double depth;
  final Offset screenCenter;

  String get faceName => kFaceNames[face];
  int get flavor => kFaceFlavor[localFace];
  bool get isSticker => cubie.stickers.contains(localFace);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'cubelet': cubeletId,
    'position': <int>[cubie.pos.x, cubie.pos.y, cubie.pos.z],
    'face': face,
    'faceName': faceName,
    'sticker': isSticker,
    'flavor': flavor,
  };
}

double _polygonArea(List<Offset> p) {
  var a = 0.0;
  for (var i = 0; i < p.length; i++) {
    final q = p[(i + 1) % p.length];
    a += p[i].dx * q.dy - q.dx * p[i].dy;
  }
  return a / 2;
}

bool _containsPoint(List<Offset> poly, Offset p) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final pi = poly[i];
    final pj = poly[j];
    final intersects =
        ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
        (p.dx < (pj.dx - pi.dx) * (p.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx);
    if (intersects) inside = !inside;
  }
  return inside;
}

double _distanceToPolygon(List<Offset> poly, Offset p) {
  var best = double.infinity;
  for (var i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    best = math.min(best, _distanceToSegment(p, a, b));
  }
  return best;
}

double _distanceToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 < 1e-9) return (p - a).distance;
  var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  return (p - (a + ab * t)).distance;
}

Offset _average(List<Offset> points) {
  var x = 0.0, y = 0.0;
  for (final p in points) {
    x += p.dx;
    y += p.dy;
  }
  return Offset(x / points.length, y / points.length);
}
