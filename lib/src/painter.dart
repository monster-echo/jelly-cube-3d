import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'controller.dart';
import 'engine.dart';
import 'geometry.dart';
import 'palette.dart';

class JellyPainter extends CustomPainter {
  JellyPainter(this.controller, {this.glossShader})
    : super(repaint: controller);

  final JellyCubeController controller;
  final ui.FragmentShader? glossShader;

  static final List<Offset> _grain = _makeGrain();

  static List<Offset> _makeGrain() {
    final rng = math.Random(11);
    return List<Offset>.generate(
      110,
      (_) => Offset(rng.nextDouble(), rng.nextDouble()),
      growable: false,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    controller.setViewport(size, controller.sceneRect);
    _paintBackdrop(canvas, size);
    final cube = controller.cube;
    final projection = JellyProjection(
      canvasSize: size,
      sceneRect: controller.sceneRect,
      cubeSize: cube.size,
      camera: controller.camera,
      lift: controller.lift,
      squashY: controller.squashY,
      squashXZ: controller.squashXZ,
    );
    final floor = JellyProjection(
      canvasSize: size,
      sceneRect: controller.sceneRect,
      cubeSize: cube.size,
      camera: controller.camera,
    );

    _paintPlate(canvas, size, floor, cube.size);
    _paintContactShadow(canvas, floor, cube.size);
    _paintGloss(canvas, size, projection, cube.size);
    _paintCore(canvas, projection, cube);
    _paintRainbowPuddle(canvas, floor, cube, controller.melt);
    _paintCube(canvas, projection, cube);
    _paintPokeTrail(canvas, projection, cube);
    _paintSparkles(canvas, floor, projection, cube.size);
  }

  // --------------------------------------------------------------- backdrop
  void _paintBackdrop(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final dark = JellySkin.dark;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          jellyStudioTop(),
          jellyStudioMid(),
          jellyStudioBottom(),
        ],
        stops: const <double>[0.0, 0.48, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final blush = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.72, -0.55),
        radius: 0.92,
        colors: <Color>[
          (dark ? JellyPalette.berry : JellyPalette.blush).withValues(
            alpha: dark ? 0.34 : 0.72,
          ),
          (dark ? JellyPalette.berry : JellyPalette.blush).withValues(
            alpha: 0.0,
          ),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, blush);

    final cream = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.62, -0.74),
        radius: 0.72,
        colors: <Color>[
          (dark ? JellyPalette.plum : JellyPalette.cream).withValues(
            alpha: dark ? 0.40 : 0.68,
          ),
          (dark ? JellyPalette.plum : JellyPalette.cream).withValues(
            alpha: 0.0,
          ),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, cream);

    // A quiet pool of light behind the specimen.
    final halo = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.10),
        radius: 0.60,
        colors: <Color>[
          Colors.white.withValues(alpha: dark ? 0.10 : 0.34),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, halo);

    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.82,
        colors: <Color>[
          Colors.transparent,
          JellyPalette.plum.withValues(alpha: dark ? 0.34 : 0.09),
        ],
        stops: const <double>[0.55, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);

    final grain = Paint()..color = JellyPalette.ink.withValues(alpha: 0.024);
    for (final p in _grain) {
      canvas.drawCircle(
        Offset(p.dx * size.width, p.dy * size.height),
        0.6,
        grain,
      );
    }
  }

  // ------------------------------------------------------------------ plate
  void _paintPlate(
    Canvas canvas,
    Size size,
    JellyProjection floor,
    int cubeSize,
  ) {
    final center = floor.projectStable(V3(0, -cubeSize / 2 - 0.055, 0));
    final extraMargin = math.max(0, cubeSize - 3) * 0.72;
    final width = floor.scale * (cubeSize * 0.79 + 1.2 + extraMargin) * 1.28;
    final height = width * (0.34 + floor.camera.pitch * 0.16);
    final plateRect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    // Cast shadow onto the studio table.
    final shadowRect = plateRect.shift(const Offset(0, 22)).inflate(18);
    final shadow = Paint()
      ..color = JellyPalette.plum.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28);
    canvas.drawOval(shadowRect, shadow);
    canvas.drawOval(
      plateRect.shift(const Offset(0, 12)).inflate(4),
      Paint()
        ..color = JellyPalette.plum.withValues(alpha: 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Thick ceramic side.
    final sideRect = plateRect.shift(Offset(0, height * 0.075));
    final sidePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          JellyPalette.ceramic,
          JellyPalette.ceramicShade,
          JellyPalette.ceramic,
        ],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(sideRect);
    canvas.drawOval(sideRect, sidePaint);

    // Top surface.
    final top = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.white,
          const Color(0xFFFFFCF7),
          const Color(0xFFEFE7F2),
        ],
        stops: const <double>[0.0, 0.62, 1.0],
      ).createShader(plateRect);
    canvas.drawOval(plateRect, top);

    // Glazed rim.
    canvas.drawOval(
      plateRect.deflate(1.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawOval(
      plateRect.deflate(width * 0.075),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = JellyPalette.ceramicShade.withValues(alpha: 0.8),
    );

    // Soft glaze reflection.
    final glazeRect = Rect.fromCenter(
      center: Offset(center.dx - width * 0.17, center.dy - height * 0.18),
      width: width * 0.48,
      height: height * 0.34,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(plateRect));
    canvas.drawOval(
      glazeRect,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.78),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(glazeRect),
    );
    canvas.restore();

    // Discreet ceramic stamp.
    final stamp = TextPainter(
      text: TextSpan(
        text: 'JELLY  ·  011',
        style: JellyPalette.monoSmall.copyWith(
          color: JellyPalette.ink.withValues(alpha: 0.28),
          fontSize: 7.4,
          letterSpacing: 2.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    stamp.paint(
      canvas,
      Offset(center.dx - stamp.width / 2, center.dy + height * 0.34),
    );
  }

  void _paintContactShadow(Canvas canvas, JellyProjection floor, int cubeSize) {
    final center = floor.projectStable(V3(0, -cubeSize / 2 - 0.02, 0));
    final hover = 1 / (1 + controller.lift * 0.75);
    final width =
        floor.scale *
        cubeSize *
        1.25 *
        hover *
        (1 + (controller.squashXZ - 1) * 0.8);
    final height = width * (0.25 + floor.camera.pitch * 0.17);
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final a = 0.23 * hover + controller.squash * 0.30;
    canvas.drawOval(
      rect.inflate(width * 0.16),
      Paint()
        ..color = JellyPalette.plum.withValues(alpha: a.clamp(0.0, 0.38))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = JellyPalette.plum.withValues(
          alpha: (a * 0.55).clamp(0.0, 0.28),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  void _paintGloss(
    Canvas canvas,
    Size size,
    JellyProjection projection,
    int cubeSize,
  ) {
    final shader = glossShader;
    if (shader == null || controller.melt > 0.04) return;
    try {
      shader
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, projection.center.dx)
        ..setFloat(3, projection.center.dy)
        ..setFloat(4, projection.scale * cubeSize * 0.78)
        ..setFloat(5, controller.visualTime)
        ..setFloat(6, 0.82)
        ..setFloat(7, 0.74)
        ..setFloat(8, 0.96)
        ..setFloat(9, 0.095);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.screen,
      );
    } catch (_) {
      // A missing/unsupported shader never affects the material fallback.
    }
  }

  void _paintCore(Canvas canvas, JellyProjection projection, JellyCube cube) {
    final center = projection.project(const V3(0, 0, 0));
    final radius = projection.scale * cube.size * 0.34;
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 2,
      height: radius * 2,
    );
    final fade = (1 - controller.melt * 0.95).clamp(0.0, 1.0);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 0.9,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.68 * fade),
          const Color(0xFFF3EAF8).withValues(alpha: 0.48 * fade),
          const Color(0xFFD9C8EA).withValues(alpha: 0.16 * fade),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 0.78, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      center,
      radius * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.22 * fade),
    );
  }

  // ------------------------------------------------------------------ puddle
  void _paintCube(Canvas canvas, JellyProjection projection, JellyCube cube) {
    final visuals = <_CubieVisual>[];
    for (final cubie in cube.cubies) {
      visuals.add(_buildCubie(projection, cube, cubie));
    }
    visuals.sort((a, b) => a.depth.compareTo(b.depth));

    for (final visual in visuals) {
      _paintCubie(canvas, projection, cube, visual);
    }
  }

  _CubieVisual _buildCubie(
    JellyProjection projection,
    JellyCube cube,
    JellyCubelet cubie,
  ) {
    var center = projection.worldCubeletCenter(cubie.pos);
    var orientation = Mat3.fromMat3i(cubie.orientation);
    var scale = const V3(1, 1, 1);
    var extra = V3.zero;

    // Residual turns are rendered newest first so an in-flight scramble reads
    // as a stack of elastic slices rather than a single rigid body.
    for (final turn in controller.turns.reversed) {
      if (!turn.coordinates.contains(cubie.pos[turn.axis])) continue;
      final rad = turn.angle * math.pi / 180;
      final axis = _axisVector(turn.axis);
      center = center.rotateAxis(axis, rad);
      orientation = _rotationMat(axis, rad) * orientation;
      final velocity = turn.velocity * math.pi / 180;
      if (velocity.abs() > 0.01) {
        final tangent = axis.cross(center) * (velocity * 0.0021);
        extra += tangent;
        final wobble = (velocity.abs() * 0.00035).clamp(0.0, 0.038);
        scale = V3(
          scale.x * (1 + wobble),
          scale.y * (1 + wobble * 0.55),
          scale.z * (1 + wobble),
        );
      }
    }

    // Squish from neighbouring slices: volume moves out of the way.
    for (final turn in controller.turns) {
      if (turn.coordinates.contains(cubie.pos[turn.axis])) continue;
      final gap = (cubie.pos[turn.axis] - turn.coordinates.first).abs();
      if (gap <= 2) {
        final closeness = (1 - gap / 4.0).clamp(0.0, 1.0);
        final amount = (turn.angle.abs() / 90 * closeness * 0.016).clamp(
          0.0,
          0.018,
        );
        extra += _axisVector(turn.axis) * (turn.angle.sign * amount);
        scale = V3(
          scale.x * (1 + amount * 0.4),
          scale.y * (1 + amount * 0.15),
          scale.z * (1 + amount * 0.4),
        );
      }
    }

    final interactive = controller.interactiveTurn;
    if (interactive != null &&
        cubie.pos[interactive.axis] == interactive.coordinate) {
      // visualAngle stays continuous across the 45-degree commit detent, so
      // the slice keeps tracking the finger even after the engine state has
      // absorbed the quarter turn.
      final rad = interactive.visualAngle * math.pi / 180;
      final axis = _axisVector(interactive.axis);
      center = center.rotateAxis(axis, rad);
      orientation = _rotationMat(axis, rad) * orientation;
    }

    // Poke: local volume preserving dent.
    var pokeDent = 0.0;
    var pokeLocalAxis = -1;
    final effect = controller.pokeEffect;
    if (effect != null) {
      if (effect.cubeletId == cubie.id) {
        pokeDent = effect.dent.clamp(-0.20, 0.30);
        pokeLocalAxis = _axisOf(kFaceNormals[effect.localFace]);
        scale = _applyAxisScale(scale, pokeLocalAxis, 1 - pokeDent * 0.60);
        for (var a = 0; a < 3; a++) {
          if (a == pokeLocalAxis) continue;
          scale = _applyAxisScale(scale, a, 1 + pokeDent * 0.20);
        }
      } else {
        final poked = cube.cubies.firstWhere(
          (c) => c.id == effect.cubeletId,
          orElse: () => cubie,
        );
        final pokedCenter = projection.worldCubeletCenter(poked.pos);
        final distance = (center - pokedCenter).length;
        final ripple =
            math.sin(effect.elapsed * 18 - distance * 5.2) *
            math.exp(-effect.elapsed * 3.2) *
            math.exp(-distance * 0.55) *
            effect.strength *
            0.028;
        final outward = (center - pokedCenter).normalized;
        extra += outward * ripple;
        scale = V3(
          scale.x * (1 + ripple.abs() * 0.55),
          scale.y * (1 + ripple.abs() * 0.55),
          scale.z * (1 + ripple.abs() * 0.55),
        );
      }
    }

    // The melt phase lets each jellylet find its own way to the plate.
    final melt = _cubieMelt(cubie, cube);
    if (melt > 0.001) {
      final floorY = -cube.size / 2 + 0.10;
      final dir = V3(center.x, 0, center.z);
      final outward = dir.length < 0.001 ? V3.zero : dir.normalized;
      final target =
          center + outward * (0.23 * melt) + V3(0, floorY - center.y, 0);
      center = V3(
        center.x + (target.x - center.x) * melt,
        center.y + (target.y - center.y) * melt,
        center.z + (target.z - center.z) * melt,
      );
      scale = V3(
        scale.x * (1 + 0.25 * melt),
        scale.y * (1 - 0.78 * melt),
        scale.z * (1 + 0.25 * melt),
      );
    }

    center += extra;
    return _CubieVisual(
      cubie: cubie,
      center: center,
      orientation: orientation,
      scale: scale,
      depth: projection.depthOf(center),
      melt: melt,
      pokeDent: pokeDent,
      pokeAxis: pokeLocalAxis,
    );
  }

  double _cubieMelt(JellyCubelet cubie, JellyCube cube) {
    if (!controller.meltPlaying && controller.melt <= 0.001) return 0;
    final t = controller.meltTime;
    if (t < 1.85) {
      final stagger = (cubie.id % 9) * 0.035;
      final p = ((t - stagger) / (1.15 - stagger)).clamp(0.0, 1.0);
      return _smooth(p) * controller.melt.clamp(0.0, 1.0);
    }
    final count = cube.cubies.length;
    final rank = cubie.id / math.max(1, count);
    final start = 1.85 + rank * 0.85;
    final p = ((t - start) / 0.82).clamp(0.0, 1.0);
    return 1 - _smooth(p);
  }

  void _paintCubie(
    Canvas canvas,
    JellyProjection projection,
    JellyCube cube,
    _CubieVisual visual,
  ) {
    if (visual.melt > 0.78) return;
    final faces = <_FaceVisual>[];
    for (var localFace = 0; localFace < 6; localFace++) {
      final localNormal = kFaceNormals[localFace];
      final worldNormal = visual.orientation.apply(
        V3(
          localNormal.x.toDouble(),
          localNormal.y.toDouble(),
          localNormal.z.toDouble(),
        ),
      );
      final visible = projection.faceVisible(worldNormal);
      final face = _buildFace(
        projection,
        visual,
        localFace,
        worldNormal,
        visible,
      );
      faces.add(face);
    }
    _drawCubieHull(canvas, projection, visual);
    faces.sort((a, b) => a.depth.compareTo(b.depth));
    for (final face in faces) {
      _drawFace(canvas, visual, face);
    }
  }

  void _drawCubieHull(
    Canvas canvas,
    JellyProjection projection,
    _CubieVisual visual,
  ) {
    final points = <V3>[];
    for (final sy in <double>[-1, 1]) {
      for (final sx in <double>[-1, 1]) {
        for (final sz in <double>[-1, 1]) {
          final local = V3(
            0.485 * sx * visual.scale.x,
            0.485 * sy * visual.scale.y,
            0.485 * sz * visual.scale.z,
          );
          points.add(visual.center + visual.orientation.apply(local));
        }
      }
    }
    final project = points.map(projection.project).toList();
    final hull = _convexHull(project);
    if (hull.length < 3) return;
    final path = Path()..moveTo(hull.first.dx, hull.first.dy);
    for (var i = 1; i < hull.length; i++) {
      path.lineTo(hull[i].dx, hull[i].dy);
    }
    path.close();
    final rect = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.3),
          radius: 0.9,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.15),
            const Color(0xFFF2E9F8).withValues(alpha: 0.10),
            const Color(0xFFD7C5E8).withValues(alpha: 0.055),
          ],
        ).createShader(rect),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  _FaceVisual _buildFace(
    JellyProjection projection,
    _CubieVisual visual,
    int localFace,
    V3 worldNormal,
    bool visible,
  ) {
    final normal = kFaceNormals[localFace];
    final axis = _axisOf(normal);
    final localCenter = V3(normal.x * 0.5, normal.y * 0.5, normal.z * 0.5);
    final worldCenter =
        visual.center +
        visual.orientation.apply(
          V3(
            localCenter.x * visual.scale.x,
            localCenter.y * visual.scale.y,
            localCenter.z * visual.scale.z,
          ),
        );

    final tangents = <V3>[];
    for (var a = 0; a < 3; a++) {
      if (a == axis) continue;
      final unit = _axisVector(a);
      tangents.add(unit);
    }
    final half = 0.482;
    final pokeHere =
        visual.pokeDent.abs() > 0.01 && visual.pokeAxis == _axisOf(normal);
    final tangentHalf = pokeHere
        ? half * (1 - visual.pokeDent.abs() * 0.28)
        : half;
    final corners = <V3>[];
    for (final sy in <double>[-1, 1]) {
      for (final sx in <double>[-1, 1]) {
        final local = V3(
          normal.x * half +
              tangents[0].x * tangentHalf * sx +
              tangents[1].x * tangentHalf * sy,
          normal.y * half +
              tangents[0].y * tangentHalf * sx +
              tangents[1].y * tangentHalf * sy,
          normal.z * half +
              tangents[0].z * tangentHalf * sx +
              tangents[1].z * tangentHalf * sy,
        );
        final scaled = V3(
          local.x * visual.scale.x,
          local.y * visual.scale.y,
          local.z * visual.scale.z,
        );
        var world = visual.center + visual.orientation.apply(scaled);
        // A breath of outward bulge so faces read as soft pillows.
        final bulge = 0.006 + (visible ? 0.006 : 0.0);
        world += worldNormal * bulge;
        corners.add(world);
      }
    }

    // Order the four corners around the face, not in a Z.
    final screen = corners.map(projection.project).toList();
    final centerScreen = _avg(screen);
    // Sort by polar angle for a stable winding after perspective.
    final ordered = List<Offset>.of(screen);
    final baseAngle = math.atan2(
      ordered.first.dy - centerScreen.dy,
      ordered.first.dx - centerScreen.dx,
    );
    ordered.sort((a, b) {
      final aa = math.atan2(a.dy - centerScreen.dy, a.dx - centerScreen.dx);
      final bb = math.atan2(b.dy - centerScreen.dy, b.dx - centerScreen.dx);
      final da = _angleDelta(aa, baseAngle);
      final db = _angleDelta(bb, baseAngle);
      return da.compareTo(db);
    });

    final path = _roundedQuadPath(ordered);
    final sticker = visual.cubie.stickers.contains(localFace);
    final flavor = kFaceFlavor[localFace];
    final depth = projection.depthOf(worldCenter);
    return _FaceVisual(
      localFace: localFace,
      visible: visible,
      sticker: sticker,
      flavor: flavor,
      path: path,
      corners: ordered,
      center: centerScreen,
      depth: depth,
      normal: worldNormal,
    );
  }

  void _drawFace(Canvas canvas, _CubieVisual visual, _FaceVisual face) {
    if (face.path.getBounds().isEmpty) return;
    final melt = visual.melt;
    final hiddenAlpha = face.visible ? 1.0 : 0.13;
    final opacity = (1 - melt * 0.62) * hiddenAlpha;
    if (opacity <= 0.012) return;

    final flavor = face.flavor;
    final isCoconut = flavor == 0;
    final deep = isCoconut
        ? const Color(0xFFF1DFB9)
        : JellyPalette.flavorDeep[flavor];
    final base = isCoconut
        ? const Color(0xFFFFF7E5)
        : JellyPalette.flavor[flavor];
    final light = isCoconut
        ? const Color(0xFFFFFFFF)
        : JellyPalette.flavorLight[flavor];
    final rect = face.path.getBounds();
    final dot = face.normal
        .dot(const V3(-0.34, 0.79, 0.51).normalized)
        .clamp(-1.0, 1.0);
    final lit = 0.88 + 0.18 * dot;

    if (face.sticker && face.visible) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = isCoconut
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _lift(light, 1.01).withValues(alpha: opacity),
                  _lift(base, lit).withValues(alpha: opacity),
                  _lift(deep, 0.98).withValues(alpha: opacity),
                ],
                stops: const <double>[0.0, 0.55, 1.0],
              ).createShader(rect)
            : RadialGradient(
                center: const Alignment(-0.08, -0.12),
                radius: 1.02,
                colors: <Color>[
                  _lift(deep, lit * 0.96).withValues(alpha: opacity),
                  _lift(base, lit).withValues(alpha: opacity),
                  _lift(light, 1.02).withValues(alpha: opacity * 0.98),
                ],
                stops: const <double>[0.0, 0.58, 1.0],
              ).createShader(rect);
      canvas.drawPath(face.path, paint);

      canvas.save();
      canvas.clipPath(face.path);
      // Directional glaze.
      final glaze = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.22 * opacity),
            Colors.white.withValues(alpha: 0.015 * opacity),
            JellyPalette.plum.withValues(alpha: 0.09 * opacity),
          ],
          stops: const <double>[0.0, 0.54, 1.0],
        ).createShader(rect);
      canvas.drawPath(face.path, glaze);
      _drawSpecular(canvas, face, opacity);
      _drawRimLight(canvas, face, opacity);
      canvas.restore();

      // Inner flavor seam.
      final inner = _scalePath(face.path, face.center, 0.86);
      canvas.drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = deep.withValues(alpha: 0.18 * opacity),
      );
      canvas.drawPath(
        face.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.35
          ..color = Colors.white.withValues(alpha: 0.66 * opacity),
      );
      canvas.drawPath(
        face.path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = JellyPalette.plum.withValues(alpha: 0.10 * opacity),
      );
    } else {
      // Clear, frosted jelly.
      final alpha = face.visible ? 0.56 : 0.14;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          center: const Alignment(-0.15, -0.22),
          radius: 1.0,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.62 * alpha * 2.4 * opacity),
            const Color(
              0xFFF4EBFA,
            ).withValues(alpha: 0.40 * alpha * 2 * opacity),
            const Color(
              0xFFD7C7E8,
            ).withValues(alpha: 0.20 * alpha * 2 * opacity),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.42, 0.82, 1.0],
        ).createShader(rect);
      canvas.drawPath(face.path, paint);
      if (face.visible) {
        canvas.save();
        canvas.clipPath(face.path);
        _drawSpecular(canvas, face, 0.36 * opacity);
        canvas.restore();
        canvas.drawPath(
          face.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Colors.white.withValues(alpha: 0.44 * opacity),
        );
      }
    }

    if (face.visible &&
        visual.pokeDent.abs() > 0.01 &&
        visual.pokeAxis == _axisOf(kFaceNormals[face.localFace])) {
      _drawDentShade(canvas, face, visual.pokeDent);
    }
  }

  void _drawSpecular(Canvas canvas, _FaceVisual face, double opacity) {
    final rect = face.path.getBounds();
    if (rect.width < 4 || rect.height < 4) return;
    final size = math.min(rect.width, rect.height);
    final spot = Rect.fromCenter(
      center: Offset(
        rect.left + rect.width * 0.28,
        rect.top + rect.height * 0.20,
      ),
      width: rect.width * 0.42,
      height: size * 0.34,
    );
    canvas.drawOval(
      spot,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.56 * opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(spot),
    );
    canvas.drawCircle(
      Offset(rect.left + rect.width * 0.21, rect.top + rect.height * 0.15),
      math.max(0.7, size * 0.027),
      Paint()..color = Colors.white.withValues(alpha: 0.68 * opacity),
    );
  }

  void _drawRimLight(Canvas canvas, _FaceVisual face, double opacity) {
    final rect = face.path.getBounds();
    final edge = Rect.fromLTWH(
      rect.left + rect.width * 0.08,
      rect.top + rect.height * 0.04,
      rect.width * 0.84,
      rect.height * 0.24,
    );
    canvas.drawOval(
      edge,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.22 * opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(edge),
    );
  }

  void _drawDentShade(Canvas canvas, _FaceVisual face, double dent) {
    final rect = face.path.getBounds();
    final strength = dent.abs().clamp(0.0, 0.32);
    final r = Rect.fromCenter(
      center: face.center,
      width: rect.width * 0.42,
      height: rect.height * 0.42,
    );
    canvas.save();
    canvas.clipPath(face.path);
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            JellyPalette.ink.withValues(alpha: 0.20 * strength * 3),
            JellyPalette.ink.withValues(alpha: 0.0),
          ],
        ).createShader(r),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: face.center,
        width: rect.width * 0.23,
        height: rect.height * 0.23,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.35 * strength * 3),
    );
    canvas.restore();
  }

  void _paintRainbowPuddle(
    Canvas canvas,
    JellyProjection floor,
    JellyCube cube,
    double melt,
  ) {
    if (melt < 0.02) return;
    final visibility = _smooth(((melt - 0.58) / 0.36).clamp(0.0, 1.0));
    if (visibility < 0.01) return;
    final center = floor.projectStable(V3(0, -cube.size / 2 - 0.004, 0));
    final rx = floor.scale * cube.size * 0.48;
    final ry = rx * (0.30 + floor.camera.pitch * 0.19);
    final path = _puddlePath(center, rx, ry, 0.7 + floor.camera.yaw);
    final bounds = path.getBounds();

    // Pooled shadow, then the jelly itself.
    canvas.drawPath(
      path.shift(const Offset(0, 7)),
      Paint()
        ..color = JellyPalette.plum.withValues(alpha: 0.18 * visibility)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(
      path.shift(const Offset(0, 5)),
      Paint()
        ..color = JellyPalette.plum.withValues(alpha: 0.26 * visibility)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const SweepGradient(
          startAngle: 0.0,
          endAngle: math.pi * 2,
          colors: <Color>[
            Color(0xFFFFF9EC),
            Color(0xFFFFD42E),
            Color(0xFF77D83C),
            Color(0xFF3157D8),
            Color(0xFFD51F3D),
            Color(0xFFFF7A12),
            Color(0xFFFFF9EC),
          ],
          stops: <double>[0.0, 0.15, 0.32, 0.49, 0.66, 0.83, 1.0],
        ).createShader(bounds),
    );
    // Deepen the edges, lift the middle.
    canvas.drawPath(
      path,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.12, -0.26),
          radius: 0.92,
          colors: <Color>[
            Colors.white.withValues(alpha: 0.25 * visibility),
            Colors.white.withValues(alpha: 0.0),
            JellyPalette.plum.withValues(alpha: 0.14 * visibility),
          ],
          stops: const <double>[0.0, 0.58, 1.0],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(path);
    _drawPuddleSheen(canvas, bounds, visibility);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = Colors.white.withValues(alpha: 0.52 * visibility),
    );
  }

  void _drawPuddleSheen(Canvas canvas, Rect bounds, double opacity) {
    final sheen = Rect.fromCenter(
      center: Offset(
        bounds.left + bounds.width * 0.36,
        bounds.top + bounds.height * 0.35,
      ),
      width: bounds.width * 0.55,
      height: bounds.height * 0.36,
    );
    canvas.drawOval(
      sheen,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.78 * opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(sheen),
    );
    final arc = Path()
      ..moveTo(
        bounds.left + bounds.width * 0.16,
        bounds.top + bounds.height * 0.50,
      )
      ..quadraticBezierTo(
        bounds.left + bounds.width * 0.38,
        bounds.top + bounds.height * 0.40,
        bounds.left + bounds.width * 0.58,
        bounds.top + bounds.height * 0.48,
      );
    canvas.drawPath(
      arc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.44 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
    final streak = Rect.fromCenter(
      center: Offset(
        bounds.left + bounds.width * 0.34,
        bounds.top + bounds.height * 0.52,
      ),
      width: bounds.width * 0.32,
      height: bounds.height * 0.08,
    );
    canvas.drawOval(
      streak,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    for (var i = 0; i < 9; i++) {
      final dx = bounds.left + bounds.width * (0.18 + ((i * 0.37) % 0.66));
      final dy = bounds.top + bounds.height * (0.24 + ((i * 0.21) % 0.56));
      canvas.drawCircle(
        Offset(dx, dy),
        (0.8 + (i % 3) * 0.7) * opacity,
        Paint()..color = Colors.white.withValues(alpha: 0.40 * opacity),
      );
    }
  }

  static Path _puddlePath(Offset center, double rx, double ry, double phase) {
    const count = 16;
    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final a = i * math.pi * 2 / count;
      final wobble =
          1 + 0.075 * math.sin(3 * a + phase) + 0.045 * math.cos(5 * a - phase);
      points.add(
        Offset(
          center.dx + math.cos(a) * rx * wobble,
          center.dy + math.sin(a) * ry * wobble,
        ),
      );
    }
    final path = Path();
    final mid0 = (points.last + points.first) * 0.5;
    path.moveTo(mid0.dx, mid0.dy);
    for (var i = 0; i < count; i++) {
      final cur = points[i];
      final next = points[(i + 1) % count];
      final mid = (cur + next) * 0.5;
      path.quadraticBezierTo(cur.dx, cur.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  // ------------------------------------------------------------------- poke
  void _paintPokeTrail(
    Canvas canvas,
    JellyProjection projection,
    JellyCube cube,
  ) {
    for (final effect in controller.pokeTrail) {
      final cubie = cube.cubies.firstWhere(
        (c) => c.id == effect.cubeletId,
        orElse: () => cube.cubies.first,
      );
      final normal = cubie.orientation.apply(kFaceNormals[effect.localFace]);
      final worldNormal = V3(
        normal.x.toDouble(),
        normal.y.toDouble(),
        normal.z.toDouble(),
      );
      final center =
          projection.worldCubeletCenter(cubie.pos) + worldNormal * 0.49;
      final s = projection.project(center);
      final progress = effect.progress;
      final alpha = (1 - progress) * effect.strength;
      final radius = projection.scale * (0.18 + progress * 0.55);
      for (var ring = 0; ring < 2; ring++) {
        final p = (progress - ring * 0.16).clamp(0.0, 1.0);
        if (p <= 0) continue;
        final rr = projection.scale * (0.12 + p * 0.52);
        canvas.drawCircle(
          s,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.white.withValues(
              alpha: alpha * (0.55 - ring * 0.2),
            ),
        );
      }
      canvas.drawCircle(
        s,
        math.max(0.5, radius * 0.10),
        Paint()..color = Colors.white.withValues(alpha: alpha * 0.7),
      );
    }
  }

  // ---------------------------------------------------------------- sparkles
  void _paintSparkles(
    Canvas canvas,
    JellyProjection floor,
    JellyProjection projection,
    int cubeSize,
  ) {
    if (controller.lift > 0.02) return;
    final center = floor.projectStable(V3(0, -cubeSize / 2 - 0.015, 0));
    final width = floor.scale * cubeSize * 1.15;
    final sparklePaint = Paint()..color = Colors.white.withValues(alpha: 0.75);
    final points = <Offset>[
      center.translate(-width * 0.62, -width * 0.03),
      center.translate(width * 0.57, width * 0.03),
      projection
          .project(V3(-cubeSize / 2, cubeSize / 2, cubeSize / 2))
          .translate(-8, -6),
    ];
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final r = i == 2 ? 3.0 : 2.1;
      canvas.drawCircle(p, r * 0.30, sparklePaint);
      canvas.drawLine(
        p.translate(-r, 0),
        p.translate(r, 0),
        Paint()
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.45),
      );
      canvas.drawLine(
        p.translate(0, -r),
        p.translate(0, r),
        Paint()
          ..strokeWidth = 0.8
          ..color = Colors.white.withValues(alpha: 0.45),
      );
    }
  }

  // ----------------------------------------------------------------- helpers
  static double _smooth(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  static Color _lift(Color c, double factor) {
    if (factor >= 1) {
      return Color.lerp(c, Colors.white, (factor - 1).clamp(0.0, 0.6))!;
    }
    return Color.lerp(c, JellyPalette.plum, (1 - factor).clamp(0.0, 0.35))!;
  }

  static Offset _avg(List<Offset> points) {
    var x = 0.0;
    var y = 0.0;
    for (final p in points) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / points.length, y / points.length);
  }

  static double _angleDelta(double a, double b) {
    var d = a - b;
    while (d < 0) {
      d += math.pi * 2;
    }
    while (d >= math.pi * 2) {
      d -= math.pi * 2;
    }
    return d;
  }

  static Path _roundedQuadPath(List<Offset> pts) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final prev = pts[(i + pts.length - 1) % pts.length];
      final cur = pts[i];
      final next = pts[(i + 1) % pts.length];
      final toPrev = prev - cur;
      final toNext = next - cur;
      final prevLen = toPrev.distance;
      final nextLen = toNext.distance;
      if (prevLen < 0.001 || nextLen < 0.001) continue;
      final radius = math.min(prevLen, nextLen) * 0.17;
      final startPoint = cur + toPrev / prevLen * radius;
      final endPoint = cur + toNext / nextLen * radius;
      if (i == 0) {
        path.moveTo(startPoint.dx, startPoint.dy);
      } else {
        path.lineTo(startPoint.dx, startPoint.dy);
      }
      path.quadraticBezierTo(cur.dx, cur.dy, endPoint.dx, endPoint.dy);
    }
    path.close();
    return path;
  }

  static List<Offset> _convexHull(List<Offset> input) {
    if (input.length < 3) return input;
    final pts = List<Offset>.of(input)
      ..sort(
        (a, b) => a.dx == b.dx ? a.dy.compareTo(b.dy) : a.dx.compareTo(b.dx),
      );
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[];
    for (final p in pts) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    final upper = <Offset>[];
    for (final p in pts.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    lower.removeLast();
    upper.removeLast();
    return <Offset>[...lower, ...upper];
  }

  static Path _scalePath(Path source, Offset center, double scale) {
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, center.dx * (1 - scale))
      ..setEntry(1, 3, center.dy * (1 - scale));
    return source.transform(matrix.storage);
  }

  static V3 _axisVector(int axis) => axis == 0
      ? const V3(1, 0, 0)
      : (axis == 1 ? const V3(0, 1, 0) : const V3(0, 0, 1));

  static int _axisOf(Int3 v) => v.x != 0 ? 0 : (v.y != 0 ? 1 : 2);

  static V3 _applyAxisScale(V3 v, int axis, double scale) {
    if (axis == 0) return V3(v.x * scale, v.y, v.z);
    if (axis == 1) return V3(v.x, v.y * scale, v.z);
    return V3(v.x, v.y, v.z * scale);
  }

  static Mat3 _rotationMat(V3 axis, double radians) {
    final a = axis.normalized;
    final c = math.cos(radians);
    final s = math.sin(radians);
    final t = 1 - c;
    return Mat3(<double>[
      t * a.x * a.x + c,
      t * a.x * a.y - s * a.z,
      t * a.x * a.z + s * a.y,
      t * a.x * a.y + s * a.z,
      t * a.y * a.y + c,
      t * a.y * a.z - s * a.x,
      t * a.x * a.z - s * a.y,
      t * a.y * a.z + s * a.x,
      t * a.z * a.z + c,
    ]);
  }

  @override
  bool shouldRepaint(covariant JellyPainter oldDelegate) => true;
}

class _CubieVisual {
  _CubieVisual({
    required this.cubie,
    required this.center,
    required this.orientation,
    required this.scale,
    required this.depth,
    required this.melt,
    required this.pokeDent,
    required this.pokeAxis,
  });

  final JellyCubelet cubie;
  final V3 center;
  final Mat3 orientation;
  final V3 scale;
  final double depth;
  final double melt;
  final double pokeDent;
  final int pokeAxis;
}

class _FaceVisual {
  _FaceVisual({
    required this.localFace,
    required this.visible,
    required this.sticker,
    required this.flavor,
    required this.path,
    required this.corners,
    required this.center,
    required this.depth,
    required this.normal,
  });

  final int localFace;
  final bool visible;
  final bool sticker;
  final int flavor;
  final Path path;
  final List<Offset> corners;
  final Offset center;
  final double depth;
  final V3 normal;
}
