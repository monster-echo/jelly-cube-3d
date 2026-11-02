import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'palette.dart';
import 'ui.dart';

/// The public root. In normal mode it presents the full instrument; in demo
/// mode (`?demo=true` or `?demo_t=1.7`) it presents only the specimen.
class JellyCubeApp extends StatefulWidget {
  const JellyCubeApp({
    super.key,
    this.controller,
    this.demo,
    this.demoTime,
    this.initialSize = 3,
  });

  final JellyCubeController? controller;
  final bool? demo;
  final double? demoTime;
  final int initialSize;

  static JellyCubeController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<JellyCubeScope>()
        ?.notifier;
  }

  @override
  State<JellyCubeApp> createState() => _JellyCubeAppState();
}

class JellyCubeScope extends InheritedNotifier<JellyCubeController> {
  const JellyCubeScope({
    super.key,
    required JellyCubeController controller,
    required super.child,
  }) : super(notifier: controller);
}

class _JellyCubeAppState extends State<JellyCubeApp>
    with SingleTickerProviderStateMixin {
  late final JellyCubeController _controller;
  late final Ticker _ticker;
  late final bool _demo;
  late final double? _demoTime;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    final params = Uri.base.queryParameters;
    final queryDemo =
        params.containsKey('demo') &&
        params['demo'] != '0' &&
        params['demo'] != 'false';
    final envDemo = const bool.fromEnvironment('DEMO');
    _demo = widget.demo ?? (queryDemo || envDemo);
    _demoTime = widget.demoTime ?? double.tryParse(params['demo_t'] ?? '');
    final querySize = int.tryParse(params['size'] ?? '');
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        JellyCubeController(
          size: (querySize ?? widget.initialSize).clamp(2, 4),
        );
    if (_demo) {
      _controller.startDemo(freezeAt: _demoTime);
    } else if (params['preview'] == 'melt') {
      final meltAt = double.tryParse(params['melt_t'] ?? '');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.previewMelt(freezeAt: meltAt);
      });
    }
    _ticker = createTicker(_controller.update)..start();
    _configureSystemChrome();
  }

  void _configureSystemChrome() {
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } catch (_) {
      // Web and embedded shells may not expose chrome controls.
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: JellyPalette.plum,
            brightness: Brightness.light,
          ).copyWith(
            primary: JellyPalette.plum,
            secondary: JellyPalette.berry,
            surface: Colors.white,
            onSurface: JellyPalette.ink,
          ),
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: JellyPalette.plum.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11),
        waitDuration: const Duration(milliseconds: 500),
      ),
    );

    return MaterialApp(
      title: "Jelly Cube 3D",
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.demoMode) {
            return _DemoShell(controller: _controller);
          }
          return JellyCubeScope(
            controller: _controller,
            child: Material(
              type: MaterialType.transparency,
              child: JellyShell(controller: _controller),
            ),
          );
        },
      ),
      builder: (context, child) {
        final content = CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyM):
                _controller.toggleMute,
            const SingleActivator(LogicalKeyboardKey.keyR): _controller.reset,
            const SingleActivator(LogicalKeyboardKey.space): () =>
                _controller.drop(),
          },
          child: child ?? const SizedBox.shrink(),
        );
        return DefaultTextStyle(
          style: const TextStyle(
            color: JellyPalette.ink,
            decoration: TextDecoration.none,
            decorationColor: Colors.transparent,
          ),
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.2,
            child: content,
          ),
        );
      },
    );
  }
}

class _DemoShell extends StatelessWidget {
  const _DemoShell({required this.controller});
  final JellyCubeController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JellyPalette.studioMid,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final scene = Rect.fromLTRB(
            0,
            size.height * 0.055,
            size.width,
            size.height * 0.965,
          );
          controller.setViewport(size, scene);
          return MouseRegion(
            cursor: SystemMouseCursors.none,
            child: IgnorePointer(
              child: JellyStage(controller: controller, sceneRect: scene),
            ),
          );
        },
      ),
    );
  }
}
