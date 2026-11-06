import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import 'controller.dart';
import 'about.dart';
import 'painter.dart';
import 'purchase_ui.dart';
import 'palette.dart';

const double _kTabletBreakpoint = 600;

class JellyShell extends StatefulWidget {
  const JellyShell({super.key, required this.controller});

  final JellyCubeController controller;

  @override
  State<JellyShell> createState() => _JellyShellState();
}

class _JellyShellState extends State<JellyShell> {
  bool _sheetExpanded = false;

  JellyCubeController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final wide = size.width >= _kTabletBreakpoint;
        final padding = MediaQuery.paddingOf(context);
        if (wide) {
          return _TabletLayout(controller: c, size: size, padding: padding);
        }
        return _PhoneLayout(
          controller: c,
          size: size,
          padding: padding,
          expanded: _sheetExpanded,
          onExpandedChanged: (value) => setState(() => _sheetExpanded = value),
        );
      },
    );
  }
}

class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({
    required this.controller,
    required this.size,
    required this.padding,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final JellyCubeController controller;
  final Size size;
  final EdgeInsets padding;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final safeBottom = padding.bottom;
    final expandedHeight = math.min(470.0, size.height * 0.58);
    final targetHeight = (expanded ? expandedHeight : 72.0) + safeBottom;
    final top = padding.top + 68;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetHeight),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, sheetHeight, _) {
        final sceneBottom = size.height - sheetHeight - 14;
        final scene = Rect.fromLTRB(
          0,
          top,
          size.width,
          math.max(top + 180, sceneBottom),
        );
        controller.setViewport(size, scene);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(
              child: JellyStage(controller: controller, sceneRect: scene),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _BrandBar(
                controller: controller,
                compact: true,
                padding: padding,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: padding.top + 76,
              child: _ToastLayer(controller: controller),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: sheetHeight + 10,
              child: _MeltBadge(controller: controller, compact: true),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: sheetHeight + 12,
              child: _Hint(controller: controller, compact: true),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: sheetHeight,
                child: _PhoneSheet(
                  controller: controller,
                  expanded: expanded,
                  onExpandedChanged: onExpandedChanged,
                  bottomInset: safeBottom,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.controller,
    required this.size,
    required this.padding,
  });

  final JellyCubeController controller;
  final Size size;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scene = Rect.fromLTRB(
      0,
      padding.top + 78,
      size.width - 304,
      size.height - 24,
    );
    controller.setViewport(size, scene);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: JellyStage(controller: controller, sceneRect: scene),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: _BrandBar(
            controller: controller,
            compact: false,
            padding: padding,
          ),
        ),
        Positioned(
          right: 20,
          top: padding.top + 78,
          width: 280,
          height: math.min(900.0, size.height - padding.top - 102),
          child: _TabletCard(
            controller: controller,
            compact: size.height < 820,
          ),
        ),
        Positioned(
          left: 20,
          right: 0,
          top: padding.top + 78,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(right: 306),
              child: _ToastLayer(controller: controller),
            ),
          ),
        ),
        Positioned(
          left: 24,
          bottom: 24,
          child: _QuickCapsule(controller: controller),
        ),
        Positioned(
          left: 24,
          right: 304,
          bottom: 94,
          child: _MeltBadge(controller: controller, compact: false),
        ),
        Positioned(
          left: 24,
          right: 304,
          top: padding.top + 92,
          child: Align(
            alignment: Alignment.topLeft,
            child: _Hint(controller: controller, compact: false),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- stage
class JellyStage extends StatefulWidget {
  const JellyStage({
    super.key,
    required this.controller,
    required this.sceneRect,
  });

  final JellyCubeController controller;
  final Rect sceneRect;

  @override
  State<JellyStage> createState() => _JellyStageState();
}

class _JellyStageState extends State<JellyStage> {
  ui.FragmentShader? _gloss;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/jelly_gloss.frag',
      );
      if (!mounted) return;
      setState(() => _gloss = program.fragmentShader());
    } catch (_) {
      // The CustomPainter path is intentionally complete on its own.
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final sceneRect = widget.sceneRect;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        controller.setViewport(size, sceneRect);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => controller.pointerDown(
            event.pointer,
            event.localPosition,
            pressure: event.pressure,
            stylus:
                event.kind == PointerDeviceKind.stylus ||
                event.kind == PointerDeviceKind.invertedStylus,
          ),
          onPointerMove: (event) => controller.pointerMove(
            event.pointer,
            event.localPosition,
            pressure: event.pressure,
          ),
          onPointerUp: (event) => controller.pointerUp(
            event.pointer,
            event.localPosition,
            pressure: event.pressure,
          ),
          onPointerCancel: (event) => controller.pointerCancel(event.pointer),
          child: RepaintBoundary(
            child: CustomPaint(
              key: const ValueKey<String>('jelly-canvas'),
              painter: JellyPainter(controller, glossShader: _gloss),
              size: size,
            ),
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------- brand bar
class _BrandBar extends StatelessWidget {
  const _BrandBar({
    required this.controller,
    required this.compact,
    required this.padding,
  });

  final JellyCubeController controller;
  final bool compact;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 24,
          8,
          compact ? 10 : 18,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const _JellyMark(size: 32),
            SizedBox(width: compact ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    L.of(context).specimenLabel,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: jellyMonoSmall().copyWith(
                      fontSize: compact ? 7.8 : 9,
                      letterSpacing: compact ? 1.15 : 1.8,
                      color: jellyInkSoft().withValues(alpha: 0.82),
                    ),
                  ),
                  SizedBox(height: compact ? 4 : 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          "Jelly Cube",
                          style: JellyPalette.display.copyWith(
                            fontSize: compact ? 20 : 25,
                            letterSpacing: compact ? -0.8 : -1.0,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '3D',
                          style: JellyPalette.display.copyWith(
                            fontSize: compact ? 20 : 25,
                            fontStyle: FontStyle.italic,
                            color: JellyPalette.berry,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _StatusPill(controller: controller, compact: compact),
            SizedBox(width: compact ? 4 : 8),
            _GlassIconButton(
              key: const ValueKey<String>('mute-button'),
              icon: controller.muted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              label: controller.muted ? L.of(context).unmute : L.of(context).mute,
              onTap: controller.toggleMute,
              size: 48,
            ),
          ],
        ),
      ),
    );
  }
}

class _JellyMark extends StatelessWidget {
  const _JellyMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: JellyPalette.berry.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(painter: _JellyMarkPainter()),
    );
  }
}

class _JellyMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final top = Path()
      ..moveTo(w * 0.50, w * 0.14)
      ..lineTo(w * 0.84, w * 0.34)
      ..lineTo(w * 0.50, w * 0.53)
      ..lineTo(w * 0.16, w * 0.34)
      ..close();
    final left = Path()
      ..moveTo(w * 0.16, w * 0.36)
      ..lineTo(w * 0.48, w * 0.55)
      ..lineTo(w * 0.48, w * 0.88)
      ..lineTo(w * 0.16, w * 0.68)
      ..close();
    final right = Path()
      ..moveTo(w * 0.84, w * 0.36)
      ..lineTo(w * 0.52, w * 0.55)
      ..lineTo(w * 0.52, w * 0.88)
      ..lineTo(w * 0.84, w * 0.68)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFFFFFBEF), Color(0xFFFFEBC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      left,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFF8FE552), Color(0xFF4AAE27)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      right,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[Color(0xFFF14A62), Color(0xFFB90E2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = jellyGlass(0.65),
    );
    canvas.drawCircle(
      Offset(w * 0.42, w * 0.26),
      w * 0.035,
      Paint()..color = jellyGlass(0.72),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.controller, required this.compact});
  final JellyCubeController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final solved = controller.cube.isSolved;
    final busy = controller.busy;
    final color = busy
        ? JellyPalette.berry
        : (solved ? const Color(0xFF4D9A42) : const Color(0xFFD39B17));
    final label = controller.solving
        ? L.of(context).statusSolving
        : controller.scrambling
        ? L.of(context).statusMixing
        : controller.statusLabel;
    return Container(
      height: 30,
      constraints: BoxConstraints(maxWidth: compact ? 90 : 150),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: jellyGlass(0.48),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: jellyGlassEdge(0.56)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 5),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: jellyMonoSmall().copyWith(
                fontSize: compact ? 7.4 : 8.6,
                letterSpacing: compact ? 0.8 : 1.1,
                color: jellyInk().withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ toast
class _ToastLayer extends StatelessWidget {
  const _ToastLayer({required this.controller});

  final JellyCubeController controller;

  @override
  Widget build(BuildContext context) {
    final toast = controller.toast;
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        reverseDuration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.25),
                end: Offset.zero,
              ).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            ),
          );
        },
        child: toast == null
            ? const SizedBox.shrink(key: ValueKey<String>('no-toast'))
            : Container(
                key: ValueKey<int>(controller.toastSerial),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                constraints: const BoxConstraints(maxWidth: 360),
                decoration: BoxDecoration(
                  color: JellyPalette.plum.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: jellyGlass(0.20),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: JellyPalette.plumDeep.withValues(alpha: 0.22),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: Color(0xFFFFE7A8),
                    ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        toast,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MeltBadge extends StatelessWidget {
  const _MeltBadge({required this.controller, required this.compact});
  final JellyCubeController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      offset: controller.meltBadge ? Offset.zero : const Offset(0, 0.35),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 320),
        opacity: controller.meltBadge ? 1 : 0,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
              decoration: BoxDecoration(
                color: JellyPalette.plum.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: jellyGlassEdge(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    '✧',
                    style: TextStyle(color: Color(0xFFFFE7A8), fontSize: 14),
                  ),
                  const SizedBox(width: 9),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        L.of(context).statusSolvedByHand,
                        style: jellyMonoSmall().copyWith(
                          color: jellyGlass(0.72),
                          fontSize: 7,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        L.of(context).jellyImpressed,
                        style: JellyPalette.displaySmall.copyWith(
                          color: Colors.white,
                          fontSize: compact ? 13 : 15,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.controller, required this.compact});
  final JellyCubeController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final solving = controller.solving;
    final show =
        solving ||
        (controller.moves == 0 &&
            !controller.demoMode &&
            !controller.meltBadge);
    final message = solving
        ? L.of(context).solvingProgress(controller.solveIndex, controller.solveTotal)
        : (compact
              ? L.of(context).hintDragPoke
              : L.of(context).hintDragFull);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: show ? 1 : 0,
      child: IgnorePointer(
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: JellyPalette.berry.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  message,
                  style: jellyMonoSmall().copyWith(
                    fontSize: compact ? 7.4 : 8,
                    letterSpacing: compact ? 1.1 : 1.4,
                    color: solving
                        ? JellyPalette.berry.withValues(alpha: 0.92)
                        : jellyInkSoft().withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- phone sheet
class _PhoneSheet extends StatelessWidget {
  const _PhoneSheet({
    required this.controller,
    required this.expanded,
    required this.onExpandedChanged,
    required this.bottomInset,
  });

  final JellyCubeController controller;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                jellyGlass(0.84),
                jellyGlass(0.66),
              ],
            ),
            border: Border(
              top: BorderSide(color: jellyGlassEdge(0.86)),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: JellyPalette.plum.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onExpandedChanged(!expanded),
                onVerticalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v < -120) onExpandedChanged(true);
                  if (v > 120) onExpandedChanged(false);
                },
                child: SizedBox(
                  height: 14,
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: jellyInk().withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              ),
              if (expanded)
                Expanded(
                  child: _ExpandedPanel(
                    controller: controller,
                    bottomInset: bottomInset,
                    onCollapse: () => onExpandedChanged(false),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset + 6),
                  child: _CollapsedBar(controller: controller),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedBar extends StatelessWidget {
  const _CollapsedBar({required this.controller});
  final JellyCubeController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: <Widget>[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _ToolButton(
                    tool: JellyTool.twist,
                    selected: controller.tool == JellyTool.twist,
                    icon: Icons.rotate_right_rounded,
                    label: L.of(context).toolTwist,
                    onTap: () => controller.setTool(JellyTool.twist),
                  ),
                  _ToolButton(
                    tool: JellyTool.spin,
                    selected: controller.tool == JellyTool.spin,
                    icon: Icons.threesixty_rounded,
                    label: L.of(context).toolSpin,
                    onTap: () => controller.setTool(JellyTool.spin),
                  ),
                  _ToolButton(
                    tool: JellyTool.poke,
                    selected: controller.tool == JellyTool.poke,
                    icon: Icons.ads_click_rounded,
                    label: L.of(context).toolPoke,
                    onTap: () => controller.setTool(JellyTool.poke),
                  ),
                  _ToolButton(
                    tool: JellyTool.drop,
                    selected: controller.tool == JellyTool.drop,
                    icon: Icons.arrow_downward_rounded,
                    label: L.of(context).toolDrop,
                    onTap: () => controller.setTool(JellyTool.drop),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _ActionIcon(
              icon: Icons.shuffle_rounded,
              label: L.of(context).scramble,
              onTap: () => controller.scramble(),
            ),
            const SizedBox(width: 6),
            _ActionIcon(
              icon: Icons.auto_awesome_rounded,
              label: L.of(context).solve,
              filled: true,
              onTap: () => controller.solve(),
            ),
          ],
        );
      },
    );
  }
}

// --------------------------------------------------------------- expanded
class _ExpandedPanel extends StatelessWidget {
  const _ExpandedPanel({
    required this.controller,
    required this.bottomInset,
    required this.onCollapse,
  });

  final JellyCubeController controller;
  final double bottomInset;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 2, 20, bottomInset + 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                L.of(context).jellyControls,
                style: JellyPalette.mono.copyWith(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  color: jellyInkSoft(),
                ),
              ),
              const Spacer(),
              _SmallTextButton(
                icon: Icons.privacy_tip_outlined,
                label: L.of(context).privacy,
                onTap: () => showJellyAbout(context),
              ),
              const SizedBox(width: 4),
              _SmallTextButton(
                icon: Icons.close_rounded,
                label: L.of(context).close,
                onTap: onCollapse,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SizeSegment(
            size: controller.size,
            onChanged: controller.setSize,
            unlockedExtraTypes: controller.extraTypesUnlocked,
            showExtraTypes: controller.extraTypesVisible,
            onLockedTap: () => showJellyUnlockSheet(context, controller),
          ),
          const SizedBox(height: 14),
          _SliderRow(
            label: L.of(context).softness,
            valueLabel: '${(controller.softness * 100).round()}%',
            value: controller.softness,
            onChanged: controller.setSoftness,
            leftIcon: Icons.bubble_chart_rounded,
          ),
          _SliderRow(
            label: L.of(context).speed,
            valueLabel: '${controller.speed.toStringAsFixed(2)}×',
            value: (controller.speed - 0.45) / 1.35,
            onChanged: (v) => controller.setSpeed(0.45 + v * 1.35),
            leftIcon: Icons.speed_rounded,
          ),
          _SliderRow(
            label: L.of(context).sound,
            valueLabel: controller.muted
                ? L.of(context).muted
                : '${(controller.volume * 100).round()}%',
            value: controller.volume,
            onChanged: controller.setVolume,
            leftIcon: controller.muted
                ? Icons.volume_off_rounded
                : Icons.graphic_eq_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _ToggleTile(
                  label: L.of(context).haptics,
                  subtitle: L.of(context).hapticsSub,
                  value: controller.hapticsEnabled,
                  onChanged: controller.setHaptics,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToggleTile(
                  label: L.of(context).calmMode,
                  subtitle: L.of(context).lessWobble,
                  value: controller.reducedMotion,
                  onChanged: controller.setReducedMotion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _UtilityButton(
                  icon: Icons.undo_rounded,
                  label: L.of(context).undo,
                  onTap: controller.undo,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UtilityButton(
                  icon: Icons.restart_alt_rounded,
                  label: L.of(context).reset,
                  onTap: controller.reset,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UtilityButton(
                  icon: Icons.center_focus_strong_rounded,
                  label: L.of(context).center,
                  onTap: controller.centerCamera,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- tablet card
class _TabletCard extends StatelessWidget {
  const _TabletCard({required this.controller, required this.compact});
  final JellyCubeController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: jellyGlass(0.56),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: jellyGlassEdge(0.72)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: JellyPalette.plum.withValues(alpha: 0.12),
                blurRadius: 34,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      L.of(context).controlStation,
                      style: JellyPalette.mono.copyWith(
                        fontSize: 8,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const Spacer(),
                    _TinyDot(
                      color: controller.busy
                          ? JellyPalette.berry
                          : const Color(0xFF4D9A42),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  L.of(context).jellyLab,
                  style: JellyPalette.displaySmall.copyWith(fontSize: 26),
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    L.of(context).aboutDescription,
                    style: jellyBody().copyWith(
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
                SizedBox(height: compact ? 10 : 16),
                _StatStrip(controller: controller),
                const SizedBox(height: 16),
                _SizeSegment(
                  size: controller.size,
                  onChanged: controller.setSize,
                  unlockedExtraTypes: controller.extraTypesUnlocked,
                  showExtraTypes: controller.extraTypesVisible,
                  onLockedTap: () => showJellyUnlockSheet(context, controller),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _CardTool(
                          icon: Icons.rotate_right_rounded,
                          label: L.of(context).toolTwist,
                          selected: controller.tool == JellyTool.twist,
                          onTap: () => controller.setTool(JellyTool.twist),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _CardTool(
                          icon: Icons.threesixty_rounded,
                          label: L.of(context).toolSpin,
                          selected: controller.tool == JellyTool.spin,
                          onTap: () => controller.setTool(JellyTool.spin),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _CardTool(
                          icon: Icons.ads_click_rounded,
                          label: L.of(context).toolPoke,
                          selected: controller.tool == JellyTool.poke,
                          onTap: () => controller.setTool(JellyTool.poke),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _CardTool(
                          icon: Icons.arrow_downward_rounded,
                          label: L.of(context).toolDrop,
                          selected: controller.tool == JellyTool.drop,
                          onTap: () => controller.setTool(JellyTool.drop),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _CardAction(
                        icon: Icons.shuffle_rounded,
                        label: L.of(context).scramble,
                        onTap: () => controller.scramble(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CardAction(
                        icon: Icons.auto_awesome_rounded,
                        label: L.of(context).solve,
                        filled: true,
                        onTap: () => controller.solve(),
                      ),
                    ),
                  ],
                ),
                if (!compact) ...<Widget>[
                  const SizedBox(height: 9),
                  _MiniDivider(label: L.of(context).sectionFlavors),
                  const SizedBox(height: 4),
                  const _FlavorLegend(),
                ],
                const SizedBox(height: 8),
                _MiniDivider(label: L.of(context).sectionTexture),
                _SliderRow(
                  label: L.of(context).softness,
                  valueLabel: '${(controller.softness * 100).round()}%',
                  value: controller.softness,
                  onChanged: controller.setSoftness,
                  dense: true,
                ),
                _SliderRow(
                  label: L.of(context).speed,
                  valueLabel: '${controller.speed.toStringAsFixed(2)}×',
                  value: (controller.speed - 0.45) / 1.35,
                  onChanged: (v) => controller.setSpeed(0.45 + v * 1.35),
                  dense: true,
                ),
                _SliderRow(
                  label: L.of(context).sound,
                  valueLabel: controller.muted
                      ? L.of(context).muted
                      : '${(controller.volume * 100).round()}%',
                  value: controller.volume,
                  onChanged: controller.setVolume,
                  dense: true,
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ToggleTile(
                        label: L.of(context).haptics,
                        subtitle: L.of(context).hapticsSubShort,
                        value: controller.hapticsEnabled,
                        onChanged: controller.setHaptics,
                        dense: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ToggleTile(
                        label: L.of(context).calm,
                        subtitle: L.of(context).lessWobble,
                        value: controller.reducedMotion,
                        onChanged: controller.setReducedMotion,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _UtilityButton(
                        icon: Icons.undo_rounded,
                        label: L.of(context).undo,
                        onTap: controller.undo,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _UtilityButton(
                        icon: Icons.restart_alt_rounded,
                        label: L.of(context).reset,
                        onTap: controller.reset,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _UtilityButton(
                        icon: Icons.center_focus_strong_rounded,
                        label: L.of(context).center,
                        onTap: controller.centerCamera,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    L.of(context).synthNote,
                    style: jellyMonoSmall().copyWith(
                      fontSize: 6.4,
                      letterSpacing: 1.1,
                      color: jellyInkFaint().withValues(alpha: 0.65),
                    ),
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: () => showJellyAbout(context),
                    icon: const Icon(Icons.info_outline_rounded, size: 13),
                    label: Text(L.of(context).privacySupport),
                    style: TextButton.styleFrom(
                      foregroundColor: jellyInkSoft(),
                      textStyle: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FlavorLegend extends StatelessWidget {
  const _FlavorLegend();

  List<String> names(BuildContext context) => <String>[
    L.of(context).flavorCoconut,
    L.of(context).flavorLemon,
    L.of(context).flavorLime,
    L.of(context).flavorBlueberry,
    L.of(context).flavorCherry,
    L.of(context).flavorTangerine,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var row = 0; row < 2; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: <Widget>[
                for (var col = 0; col < 3; col++)
                  Expanded(
                    child: _FlavorDot(
                      index: row * 3 + col,
                      name: names(context)[row * 3 + col],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FlavorDot extends StatelessWidget {
  const _FlavorDot({required this.index, required this.name});

  final int index;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.4),
              colors: <Color>[
                jellyGlass(0.9),
                JellyPalette.flavor[index],
                JellyPalette.flavorDeep[index],
              ],
              stops: const <double>[0.0, 0.42, 1.0],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: JellyPalette.flavorDeep[index].withValues(alpha: 0.18),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: jellyMonoSmall().copyWith(
              fontSize: 7,
              letterSpacing: 0.1,
              color: jellyInkSoft(),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.controller});
  final JellyCubeController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: jellyInk().withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          _Stat(value: '${controller.cube.solvedFaceCount}/6', label: L.of(context).sectionFaces),
          Container(width: 1, height: 24, color: JellyPalette.hairline),
          _Stat(value: '${controller.moves}', label: L.of(context).sectionMoves),
          Container(width: 1, height: 24, color: JellyPalette.hairline),
          _Stat(
            value: controller.solving
                ? '${controller.solveIndex}/${controller.solveTotal}'
                : (controller.cube.isSolved ? L.of(context).statusReady : L.of(context).statusSolved),
            label: L.of(context).sectionState,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: jellyLabel().copyWith(
              fontSize: 14,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: jellyMonoSmall().copyWith(fontSize: 7)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- shared bits
class _SizeSegment extends StatelessWidget {
  const _SizeSegment({
    required this.size,
    required this.onChanged,
    required this.unlockedExtraTypes,
    required this.showExtraTypes,
    required this.onLockedTap,
  });
  final int size;
  final ValueChanged<int> onChanged;
  final bool unlockedExtraTypes;
  final bool showExtraTypes;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: jellyInk().withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          for (final n in <int>[
            2,
            3,
            4,
            if (showExtraTypes) 5,
            if (showExtraTypes) 6,
          ])
            Expanded(
              child: _SegmentButton(
                label: '$n×$n',
                selected: size == n,
                locked: n >= 5 && !unlockedExtraTypes,
                onTap: () {
                  if (n >= 5 && !unlockedExtraTypes) {
                    onLockedTap();
                  } else {
                    onChanged(n);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$label, locked' : label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected ? JellyPalette.plum : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: JellyPalette.plum.withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (locked) ...<Widget>[
                  Icon(
                    Icons.lock_rounded,
                    size: 9,
                    color: jellyInkFaint(),
                  ),
                  const SizedBox(width: 2),
                ],
                Text(
                  label,
                  style: jellyLabel().copyWith(
                    fontSize: 10.5,
                    color: selected
                        ? Colors.white
                        : locked
                        ? jellyInkFaint()
                        : jellyInkSoft(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
    this.leftIcon,
    this.dense = false,
  });

  final String label;
  final String valueLabel;
  final double value;
  final ValueChanged<double> onChanged;
  final IconData? leftIcon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 8,
        activeTrackColor: JellyPalette.plum,
        inactiveTrackColor: jellyInk().withValues(alpha: 0.08),
        thumbColor: Colors.white,
        overlayColor: JellyPalette.plum.withValues(alpha: 0.10),
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 13,
          elevation: 2,
          pressedElevation: 4,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
    );
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            if (leftIcon != null) ...<Widget>[
              Icon(leftIcon, size: 13, color: jellyInkSoft()),
              const SizedBox(width: 6),
            ],
            Text(label, style: jellyLabel().copyWith(fontSize: 11.5)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: jellyGlass(0.52),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: jellyGlassEdge(0.7)),
              ),
              child: Text(
                valueLabel,
                style: jellyMonoSmall().copyWith(
                  fontSize: 7.5,
                  color: jellyInkSoft(),
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: dense ? 34 : 40, child: slider),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.dense = false,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: value ? 0.62 : 0.34),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: value
                  ? JellyPalette.plum.withValues(alpha: 0.16)
                  : jellyGlass(0.55),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      label,
                      style: jellyLabel().copyWith(fontSize: 10.5),
                    ),
                    Text(
                      subtitle,
                      style: jellyMonoSmall().copyWith(
                        fontSize: 6.8,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              _TinySwitch(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinySwitch extends StatelessWidget {
  const _TinySwitch({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 30,
      height: 17,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value
            ? JellyPalette.plum
            : jellyInk().withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 13,
          height: 13,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  const _ToolButton({
    required this.tool,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final JellyTool tool;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 500),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.94 : 1,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: widget.selected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF5B3659), JellyPalette.plum],
                      )
                    : null,
                color: widget.selected
                    ? null
                    : jellyGlass(0.48),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : jellyGlass(0.66),
                ),
                boxShadow: widget.selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: JellyPalette.plum.withValues(alpha: 0.28),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    widget.icon,
                    size: 18,
                    color: widget.selected
                        ? Colors.white
                        : jellyInkSoft(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: jellyMonoSmall().copyWith(
                      fontSize: 6.4,
                      letterSpacing: 0.35,
                      color: widget.selected
                          ? Colors.white.withValues(alpha: 0.78)
                          : jellyInkFaint(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: filled
                  ? JellyPalette.plum
                  : jellyGlass(0.48),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: filled
                    ? Colors.white.withValues(alpha: 0.16)
                    : jellyGlass(0.66),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 17,
                  color: filled ? Colors.white : jellyInkSoft(),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: jellyMonoSmall().copyWith(
                    fontSize: 6.0,
                    letterSpacing: 0.15,
                    color: filled
                        ? Colors.white.withValues(alpha: 0.78)
                        : jellyInkFaint(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: jellyGlass(0.44),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: jellyGlassEdge(0.64)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 15, color: jellyInkSoft()),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: jellyLabel().copyWith(fontSize: 9.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTextButton extends StatelessWidget {
  const _SmallTextButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: jellyGlass(0.44),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: jellyGlassEdge(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 12, color: jellyInkSoft()),
            const SizedBox(width: 4),
            Text(label, style: jellyLabel().copyWith(fontSize: 8.5)),
          ],
        ),
      ),
    );
  }
}

class _CardTool extends StatelessWidget {
  const _CardTool({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected
              ? JellyPalette.plum
              : jellyGlass(0.44),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.16)
                : jellyGlass(0.62),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : jellyInkSoft(),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: jellyLabel().copyWith(
                fontSize: 8.2,
                color: selected ? Colors.white : jellyInkSoft(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled
              ? JellyPalette.plum
              : jellyGlass(0.46),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled
                ? Colors.white.withValues(alpha: 0.16)
                : jellyGlass(0.64),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 15,
              color: filled ? Colors.white : jellyInkSoft(),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: jellyLabel().copyWith(
                fontSize: 10,
                color: filled ? Colors.white : jellyInkSoft(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniDivider extends StatelessWidget {
  const _MiniDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Text(label, style: jellyMonoSmall().copyWith(fontSize: 7)),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: JellyPalette.hairline)),
        ],
      ),
    );
  }
}

class _TinyDot extends StatelessWidget {
  const _TinyDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 5),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatefulWidget {
  const _GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 48,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: Tooltip(
        message: widget.label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 90),
            scale: _down ? 0.92 : 1,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: jellyGlass(0.42),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: jellyGlassEdge(0.60)),
              ),
              child: Icon(widget.icon, size: 19, color: jellyInkSoft()),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickCapsule extends StatelessWidget {
  const _QuickCapsule({required this.controller});
  final JellyCubeController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: jellyGlass(0.44),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: jellyGlassEdge(0.64)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: JellyPalette.plum.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _QuickAction(
                icon: Icons.undo_rounded,
                label: L.of(context).undo,
                onTap: controller.undo,
              ),
              _QuickAction(
                icon: Icons.restart_alt_rounded,
                label: L.of(context).reset,
                onTap: controller.reset,
              ),
              _QuickAction(
                icon: Icons.center_focus_strong_rounded,
                label: L.of(context).center,
                onTap: controller.centerCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 58,
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 16, color: jellyInkSoft()),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  style: jellyMonoSmall().copyWith(
                    fontSize: 6.4,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
