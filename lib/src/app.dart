import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import '../l10n/app_localizations.dart';
import 'palette.dart';
import 'purchase_ui.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final JellyCubeController _controller;
  late final Ticker _ticker;
  late final bool _demo;
  late final double? _demoTime;
  late final bool _ownsController;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

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
    final debugUnlock = params['unlock'] == '1';
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        JellyCubeController(
          size: (querySize ?? widget.initialSize).clamp(2, 6),
          debugUnlockExtraTypes: debugUnlock,
        );
    if (_demo) {
      _controller.startDemo(freezeAt: _demoTime);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Entitlement first: the settings restore gates saved 4x4-6x6 sizes
        // on the extra-types unlock.
        _controller.loadCachedEntitlement().then((_) {
          _controller.loadSettings();
        });
        if (const bool.fromEnvironment('OPEN_PAYWALL')) {
          Timer(const Duration(milliseconds: 700), () {
            final nav = _navigatorKey.currentContext;
            if (mounted && nav != null) {
              showJellyUnlockSheet(nav, _controller);
            }
          });
        }
      });
    }
    if (!_demo && params['preview'] == 'melt') {
      final meltAt = double.tryParse(params['melt_t'] ?? '');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.previewMelt(freezeAt: meltAt);
      });
    }
    _ticker = createTicker(_controller.update)..start();
    WidgetsBinding.instance.addObserver(this);
    JellySkin.brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _configureSystemChrome();
  }

  @override
  void didChangePlatformBrightness() {
    final next = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (next != JellySkin.brightness) {
      setState(() {
        JellySkin.brightness = next;
        _configureSystemChrome();
      });
    }
  }

  void _configureSystemChrome() {
    final dark = JellySkin.dark;
    try {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
      );
    } catch (_) {
      // Web and embedded shells may not expose chrome controls.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData buildTheme(Brightness brightness) {
      final dark = brightness == Brightness.dark;
      return ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: JellyPalette.plum,
              brightness: brightness,
            ).copyWith(
              primary: JellyPalette.plum,
              secondary: JellyPalette.berry,
              surface: dark ? const Color(0xFF2E1A32) : Colors.white,
              onSurface: dark ? const Color(0xFFF3E9F5) : JellyPalette.ink,
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
    }

    return MaterialApp(
      title: "Jelly Cube 3D",
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
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
        _controller.updateTexts(
          statusSolving: L.of(context).solvingProgress,
          statusScrambling: L.of(context).statusScrambling,
          statusMelting: L.of(context).statusMelting,
          statusTwisting: L.of(context).statusTwisting,
          statusDropping: L.of(context).statusDropping,
          statusPoking: L.of(context).statusPoking,
          statusOrbiting: L.of(context).statusOrbiting,
          statusSolved: L.of(context).statusSolved,
          statusInPlay: L.of(context).statusInPlay,
          toastFirstTwist: L.of(context).toastFirstTwist,
          toastFirstFace: L.of(context).toastFirstFace,
          toastFirstLayer: L.of(context).toastFirstLayer,
          toastTwoLayers: L.of(context).toastTwoLayers,
          toastNothingToUndo: L.of(context).toastNothingToUndo,
          toastAlreadySolved: L.of(context).toastAlreadySolved,
          toastSolvePaused: L.of(context).toastSolvePaused,
          toastReset: L.of(context).toastReset,
          scrambledToast: L.of(context).scrambledToast,
          solvedToast: L.of(context).solvedToast,
          sizeToast: L.of(context).sizeToast,
        );
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
          style: TextStyle(
            color: jellyInk(),
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
      backgroundColor: jellyStudioMid(),
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
