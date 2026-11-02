import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'audio.dart';
import 'engine.dart';
import 'geometry.dart';
import 'purchases.dart';

enum JellyTool { twist, spin, poke, drop }

enum JellyPhase {
  ready,
  twisting,
  spinning,
  poking,
  dropping,
  scrambling,
  solving,
  melting,
}

/// A committed slice animation. State is already discrete-correct; [angle] is
/// a visual residual around the slice axis, 0 means perfectly aligned.
class JellyTurnAnimation {
  JellyTurnAnimation({
    required this.axis,
    required this.coordinates,
    required this.angle,
    required this.velocity,
    this.notation = '',
  }) : previousVelocity = velocity,
       previousAngle = angle;

  final int axis;
  final List<int> coordinates;
  double angle;
  double velocity;
  double previousVelocity;
  double previousAngle;
  final String notation;
  bool snapped = false;
  bool overshootFired = false;
  bool finished = false;
}

class JellyInteractiveTurn {
  JellyInteractiveTurn({
    required this.axis,
    required this.coordinate,
    required this.sign,
    required this.notation,
    required this.screenDirection,
    required this.degreesPerPixel,
    required this.hit,
    required this.dragOrigin,
  }) : angle = 0;

  final int axis;
  final int coordinate;
  final int sign;
  final String notation;
  final Offset screenDirection;
  final double degreesPerPixel;
  final JellyHit hit;
  final Offset dragOrigin;
  double angle;
  bool committed = false;
  int committedSign = 0;
  double angularVelocity = 0;
  DateTime lastUpdate = DateTime.now();
}

class JellyPokeEffect {
  JellyPokeEffect({
    required this.cubeletId,
    required this.localFace,
    required this.worldFace,
    required this.strength,
  });

  final int cubeletId;
  final int localFace;
  final int worldFace;
  final double strength;
  double elapsed = 0;
  double duration = 1.05;

  double get progress => (elapsed / duration).clamp(0.0, 1.0);
  double get dent {
    final t = elapsed;
    if (t < 0.075) {
      return strength * math.sin((t / 0.075) * math.pi / 2);
    }
    final local = t - 0.075;
    return strength *
        math.exp(-local * 5.4) *
        math.cos(2 * math.pi * 2.15 * local).clamp(-0.45, 1.0);
  }
}

class _PointerSeat {
  _PointerSeat(this.down, this.last);
  Offset down;
  Offset last;
  final DateTime started = DateTime.now();
  bool ignored = false;
  bool slopPassed = false;
  String mode = 'pending';
}

class JellyCubeController extends ChangeNotifier {
  JellyCubeController({int size = 3, bool debugUnlockExtraTypes = false})
    : _size = size.clamp(2, 6),
      _purchases = JellyPurchaseService(debugUnlocked: debugUnlockExtraTypes) {
    _cube = JellyCube.solved(_size);
    _purchases.addListener(_onPurchasesChanged);
  }

  final JellyPurchaseService _purchases;

  void _onPurchasesChanged() {
    _dirty = true;
    notifyListeners();
  }

  // ------------------------------------------------------------------ state
  late JellyCube _cube;
  int _size;
  final JellyAudioEngine _audio = JellyAudioEngine();

  JellyTool _tool = JellyTool.twist;
  double _softness = 0.68;
  double _speed = 1.0;
  bool _muted = false;
  bool _haptics = true;
  bool _reducedMotion = false;

  final List<JellyMove> _history = <JellyMove>[];
  final List<JellyTurnAnimation> _turns = <JellyTurnAnimation>[];
  JellyInteractiveTurn? _interactive;
  JellyPokeEffect? _pokeEffect;
  final List<JellyPokeEffect> _pokeTrail = <JellyPokeEffect>[];

  Rect _sceneRect = const Rect.fromLTWH(0, 0, 390, 844);
  Size _viewportSize = const Size(390, 844);

  // Camera.
  double _yaw = 0.58;
  double _pitch = 0.43;
  double _zoom = 1.0;
  double _camVelYaw = 0;
  double _camVelPitch = 0;
  double _targetYaw = 0.58;
  double _targetPitch = 0.43;
  double _targetZoom = 1.0;
  bool _cameraHoming = false;
  bool _orbiting = false;

  // Soft body.
  double _rock = 0; // degrees
  double _rockVel = 0;
  double _squash = 0;
  double _squashVel = 0;
  double _lift = 0;
  double _fallVelocity = 0;
  bool _airborne = false;
  int _bounceCount = 0;

  // Stats / toasts.
  int _moveCount = 0;
  int _manualMoves = 0;
  int _clockStartMs = 0;
  bool _scrambled = false;
  bool _usedUndo = false;
  bool _usedSolve = false;
  bool _wasSolved = true;
  bool _meltPlayed = false;
  bool _meltPlaying = false;
  bool _meltBadge = false;
  double _melt = 0;
  double _meltTime = 0;
  double _visualTime = 0;

  bool _firstTwistMilestone = false;
  bool _firstFaceMilestone = false;
  bool _firstLayerMilestone = false;
  bool _twoLayerMilestone = false;

  String? _toast;
  int _toastSerial = 0;
  Timer? _toastTimer;

  // Automation.
  int _automationSerial = 0;
  bool _scrambling = false;
  bool _solving = false;
  int _solveIndex = 0;
  int _solveTotal = 0;

  // Demo.
  bool _demoMode = false;
  bool _demoFrozen = false;
  double _demoTime = 0;
  int _demoEventIndex = 0;

  // Pointer / gesture.
  final Map<int, _PointerSeat> _pointers = <int, _PointerSeat>{};
  final List<int> _pointerOrder = <int>[];
  JellyHit? _pendingHit;
  bool _pinching = false;
  double _pinchStartDistance = 1;
  Offset _pinchLastCenter = Offset.zero;
  double _lastInteractiveAngle = 0;
  DateTime _lastInteractiveTime = DateTime.now();
  int _lastSpinSoundMs = 0;
  double _turnVelocity = 0;
  int? _turnPointer;

  // Ticker.
  Duration _lastElapsed = Duration.zero;
  double _accumulator = 0;
  bool _hasTick = false;
  bool _dirty = false;
  bool _disposed = false;

  static const double _fixedStep = 1 / 120;

  // ----------------------------------------------------------------- getters
  JellyCube get cube => _cube;
  int get size => _size;
  JellyTool get tool => _tool;
  double get softness => _softness;
  double get speed => _speed;
  bool get muted => _muted;
  bool get hapticsEnabled => _haptics;
  bool get reducedMotion => _reducedMotion;
  bool get demoMode => _demoMode;
  bool get demoFrozen => _demoFrozen;
  double get demoTime => _demoTime;
  bool get meltBadge => _meltBadge;
  bool get meltPlaying => _meltPlaying;
  double get squash => _squash;
  double get melt => _melt;
  int get moves => _moveCount;
  double get meltTime => _meltTime;
  double get visualTime => _visualTime;
  bool get solving => _solving;
  bool get scrambling => _scrambling;
  int get solveIndex => _solveIndex;
  int get solveTotal => _solveTotal;
  String? get toast => _toast;
  int get toastSerial => _toastSerial;
  List<String> get history =>
      _history.map((m) => m.notation).toList(growable: false);
  List<JellyTurnAnimation> get turns =>
      List<JellyTurnAnimation>.unmodifiable(_turns);
  JellyInteractiveTurn? get interactiveTurn => _interactive;
  JellyPokeEffect? get pokeEffect => _pokeEffect;
  List<JellyPokeEffect> get pokeTrail =>
      List<JellyPokeEffect>.unmodifiable(_pokeTrail);
  double get lift => _lift;
  double get squashY => (1 - _squash).clamp(0.82, 1.10);
  double get squashXZ => (1 + _squash * 0.52).clamp(0.94, 1.12);
  double get bodyRockRadians => _rock * math.pi / 180;
  String get audioBackend => _audio.backendName;
  bool get extraTypesUnlocked => _purchases.unlocked;
  String get extraTypesPrice => _purchases.price;
  String get extraTypesTitle => _purchases.title;
  String get extraTypesDescription => _purchases.description;
  JellyStoreStatus get storeStatus => _purchases.status;
  String? get storeMessage => _purchases.message;

  Future<void> loadCachedEntitlement() => _purchases.loadCached();
  Future<void> initializeStore() => _purchases.init();
  Future<void> buyExtraTypes() => _purchases.buy();
  Future<void> restorePurchases() => _purchases.restore();
  Size get viewportSize => _viewportSize;
  Rect get sceneRect => _sceneRect;

  JellyCamera get camera =>
      JellyCamera(yaw: _yaw, pitch: _pitch, zoom: _zoom, rock: bodyRockRadians);

  bool get busy =>
      _scrambling ||
      _solving ||
      _turns.isNotEmpty ||
      _interactive != null ||
      _airborne ||
      _meltPlaying;

  JellyPhase get phase {
    if (_solving) return JellyPhase.solving;
    if (_scrambling) return JellyPhase.scrambling;
    if (_meltPlaying) return JellyPhase.melting;
    if (_interactive != null || _turns.isNotEmpty) return JellyPhase.twisting;
    if (_airborne || _squash.abs() > 0.01) return JellyPhase.dropping;
    if (_pokeEffect != null) return JellyPhase.poking;
    if (_orbiting) return JellyPhase.spinning;
    return JellyPhase.ready;
  }

  String get statusLabel {
    switch (phase) {
      case JellyPhase.solving:
        return 'SOLVING $_solveIndex / $_solveTotal';
      case JellyPhase.scrambling:
        return 'SCRAMBLING';
      case JellyPhase.melting:
        return 'MELTING';
      case JellyPhase.twisting:
        return 'TWISTING';
      case JellyPhase.dropping:
        return 'DROPPING';
      case JellyPhase.poking:
        return 'POKING';
      case JellyPhase.spinning:
        return 'ORBITING';
      case JellyPhase.ready:
        return _cube.isSolved ? 'SOLVED' : 'IN PLAY';
    }
  }

  // ------------------------------------------------------------------ setup
  void setViewport(Size size, Rect scene) {
    _viewportSize = size;
    _sceneRect = scene;
  }

  void setSceneRect(Rect scene) {
    _sceneRect = scene;
  }

  void primeAudio() {
    if (_muted || _demoMode) return;
    unawaited(_audio.init());
  }

  void setReducedMotion(bool value) {
    if (_reducedMotion == value) return;
    _reducedMotion = value;
    notifyListeners();
  }

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    _audio.enabled = !value && !_demoMode;
    if (!value) {
      unawaited(_audio.init());
      _play(JellySfx.snap, gain: 0.4);
    }
    notifyListeners();
  }

  void toggleMute() => setMuted(!_muted);

  void setSoftness(double value) {
    _softness = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSpeed(double value) {
    _speed = value.clamp(0.45, 1.8);
    notifyListeners();
  }

  void setVolume(double value) {
    _audio.volume = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  double get volume => _audio.volume;

  void setHaptics(bool value) {
    _haptics = value;
    notifyListeners();
  }

  void setTool(JellyTool value) {
    if (_tool == value) return;
    _settleInteractive(preempt: true);
    _tool = value;
    _play(JellySfx.snap, gain: 0.28);
    notifyListeners();
  }

  void setSize(int value) {
    final next = value.clamp(2, 6);
    if (next == _size) return;
    _cancelAutomation(silent: true);
    _size = next;
    reset(announce: false);
    _showToast('${next}x$next · ${_cube.cubies.length} jellylets');
  }

  void reset({bool announce = true}) {
    _cancelAutomation(silent: true);
    _cube = JellyCube.solved(_size);
    _history.clear();
    _turns.clear();
    _interactive = null;
    _pokeEffect = null;
    _pokeTrail.clear();
    _moveCount = 0;
    _manualMoves = 0;
    _clockStartMs = 0;
    _scrambled = false;
    _usedUndo = false;
    _usedSolve = false;
    _wasSolved = true;
    _meltPlayed = false;
    _meltPlaying = false;
    _meltBadge = false;
    _melt = 0;
    _meltTime = 0;
    _firstTwistMilestone = false;
    _firstFaceMilestone = false;
    _firstLayerMilestone = false;
    _twoLayerMilestone = false;
    _lift = 0;
    _fallVelocity = 0;
    _airborne = false;
    _squash = 0.13;
    _squashVel = -2.4;
    _rock = 0;
    _rockVel = 0;
    _yaw = 0.58;
    _pitch = 0.43;
    _zoom = 1.0;
    _targetYaw = _yaw;
    _targetPitch = _pitch;
    _targetZoom = _zoom;
    _camVelYaw = 0;
    _camVelPitch = 0;
    _cameraHoming = false;
    if (!_demoMode) {
      _haptic(HapticFeedback.lightImpact);
      _play(JellySfx.bloop, gain: 0.45);
    }
    if (announce && !_demoMode) {
      _showToast('Reset · fresh from the fridge');
    }
    _dirty = true;
    notifyListeners();
  }

  void centerCamera() {
    _cameraHoming = true;
    _targetYaw = 0.58;
    _targetPitch = 0.43;
    _targetZoom = 1.0;
    _camVelYaw = 0;
    _camVelPitch = 0;
    _haptic(HapticFeedback.selectionClick);
    _play(JellySfx.snap, gain: 0.25);
    notifyListeners();
  }

  // ------------------------------------------------------------------- moves
  void move(String notation) {
    if (_demoMode) return;
    _cancelAutomation(silent: true);
    final move = parseJellyMove(notation, _size);
    _commitMove(move, record: true, user: true, animate: true);
  }

  void _commitMove(
    JellyMove move, {
    required bool record,
    bool user = false,
    bool animate = true,
    bool silent = false,
  }) {
    _cube.apply(move);
    if (record) {
      _history.add(move);
      _moveCount++;
      if (user && _scrambled) _manualMoves++;
    }
    if (animate) {
      _spawnTurn(move, velocity: 0);
    }
    _rockVel -= move.quarterTurns.sign * (_reducedMotion ? 4.0 : 13.0);
    if (!silent) {
      _play(
        JellySfx.twist,
        gain: 0.55,
        rate: 0.90 + (_speed - 0.6).clamp(0.0, 1.2) * 0.16,
      );
    }
    if (user) {
      _clockStartMs = _clockStartMs == 0
          ? DateTime.now().millisecondsSinceEpoch
          : _clockStartMs;
    }
    _afterMove(user: user, silent: silent);
  }

  void _spawnTurn(JellyMove move, {double velocity = 0}) {
    // Only the newest slice is allowed a visual residual. This keeps rapid
    // scrambles and solves physically coherent instead of compounding several
    // post-state rotations on the same cubelet.
    _turns.clear();
    final turn = JellyTurnAnimation(
      axis: move.axis,
      coordinates: List<int>.of(move.coordinates),
      angle: -move.quarterTurns * 90.0,
      velocity: velocity,
      notation: move.notation,
    )..snapped = false;
    _turns.add(turn);
    if (_turns.length > 14) {
      _turns.removeAt(0);
    }
    _dirty = true;
  }

  void undo() {
    if (_demoMode) return;
    _cancelAutomation(silent: true);
    if (_history.isEmpty) {
      _showToast('Nothing to undo');
      _haptic(HapticFeedback.selectionClick);
      return;
    }
    final last = _history.removeLast();
    final inverse = last.inverse();
    _cube.apply(inverse);
    _usedUndo = true;
    _moveCount++;
    _spawnTurn(inverse);
    _rockVel += inverse.quarterTurns.sign * 11;
    _play(JellySfx.twist, gain: 0.45, rate: 0.82);
    _haptic(HapticFeedback.selectionClick);
    _afterMove(user: true, silent: true);
    notifyListeners();
  }

  void _afterMove({required bool user, bool silent = false}) {
    final solved = _cube.isSolved;
    final solvedFaces = _cube.solvedFaceCount;

    if (user && !silent) {
      if (!_firstTwistMilestone) {
        _firstTwistMilestone = true;
        _showToast('First twist');
      } else if (!_firstFaceMilestone && solvedFaces >= 1) {
        _firstFaceMilestone = true;
        _showToast('First face!');
      } else if (!_firstLayerMilestone && solvedFaces >= 2) {
        _firstLayerMilestone = true;
        _showToast('First layer!');
      } else if (!_twoLayerMilestone && solvedFaces >= 4) {
        _twoLayerMilestone = true;
        _showToast('Two layers!');
      }
    }

    if (!_wasSolved && solved) {
      final elapsed = _scrambleElapsed();
      _showToast('Solved · ${formatDuration(elapsed)} · $_moveCount moves');
      if (user &&
          _scrambled &&
          _manualMoves >= 8 &&
          !_usedUndo &&
          !_usedSolve &&
          !_meltPlayed) {
        _meltPlayed = true;
        final token = ++_automationSerial;
        Timer(const Duration(milliseconds: 650), () {
          if (_disposed || token != _automationSerial) return;
          _startMelt();
        });
      }
    }
    _wasSolved = solved;
    _dirty = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- scramble
  Future<void> scramble([int? seed]) async {
    if (_demoMode) return;
    _cancelAutomation(silent: true);
    final rng = math.Random(seed ?? DateTime.now().microsecondsSinceEpoch);
    final moves = generateScramble(_size, rng);
    final token = ++_automationSerial;
    _toast = null;
    _toastSerial++;
    _scrambling = true;
    _scrambled = true;
    _usedUndo = false;
    _usedSolve = false;
    _manualMoves = 0;
    _meltPlayed = false;
    _meltBadge = false;
    _meltPlaying = false;
    _melt = 0;
    _firstTwistMilestone = false;
    _firstFaceMilestone = false;
    _firstLayerMilestone = false;
    _twoLayerMilestone = false;
    _clockStartMs = DateTime.now().millisecondsSinceEpoch;
    _wasSolved = false;
    _dirty = true;
    notifyListeners();

    for (var i = 0; i < moves.length; i++) {
      if (token != _automationSerial || _disposed) return;
      _commitMove(moves[i], record: true, animate: true, silent: true);
      _play(JellySfx.scramble, gain: 0.45 + 0.15 * (i.isEven ? 1 : 0));
      if (_haptics && i % 2 == 0) _haptic(HapticFeedback.selectionClick);
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (token != _automationSerial || _disposed) return;
    _scrambling = false;
    _wasSolved = _cube.isSolved;
    _showToast('Scrambled · ${moves.length} moves');
    _haptic(HapticFeedback.mediumImpact);
    notifyListeners();
  }

  // ------------------------------------------------------------------- solve
  Future<void> solve() async {
    if (_demoMode) return;
    _cancelAutomation(silent: true);
    if (_cube.isSolved) {
      _showToast('Already solved · poke it');
      return;
    }
    _toast = null;
    _toastSerial++;
    _usedSolve = true;
    final simplified = simplifyMoves(_history);
    _history
      ..clear()
      ..addAll(simplified);
    final total = simplified.length;
    if (total == 0) return;

    final token = ++_automationSerial;
    _solving = true;
    _solveIndex = 0;
    _solveTotal = total;
    _dirty = true;
    notifyListeners();

    _play(JellySfx.solve, gain: 0.32, rate: 1.1);
    final intervalMs = math.min(240, math.max(45, (7200 / total).round()));

    while (_history.isNotEmpty) {
      if (token != _automationSerial || _disposed) return;
      final last = _history.removeLast();
      final inverse = last.inverse();
      _cube.apply(inverse);
      _spawnTurn(inverse);
      _rockVel += inverse.quarterTurns.sign * 8;
      _solveIndex++;
      _play(JellySfx.scramble, gain: 0.32);
      if (_solveIndex % 3 == 0 || _history.isEmpty) {
        _haptic(HapticFeedback.selectionClick);
      }
      _dirty = true;
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: intervalMs));
    }
    if (token != _automationSerial || _disposed) return;
    _solving = false;
    _solveIndex = _solveTotal;
    _wasSolved = true;
    _play(JellySfx.solve, gain: 0.9);
    _haptic(HapticFeedback.mediumImpact);
    _showToast(
      'Solved · ${formatDuration(_scrambleElapsed())} · $_solveTotal moves',
    );
    notifyListeners();
  }

  void _cancelAutomation({bool silent = false}) {
    final wasSolving = _solving;
    _automationSerial++;
    _scrambling = false;
    _solving = false;
    _solveIndex = 0;
    _solveTotal = 0;
    if (wasSolving && !silent && !_demoMode) {
      _showToast('Solve paused · your move');
    }
  }

  // ------------------------------------------------------------------ camera
  void spin(double dx, double dy) {
    _applyOrbit(dx, dy);
    _camVelYaw = dx * 0.035;
    _camVelPitch = dy * 0.028;
    _dirty = true;
    notifyListeners();
  }

  void _applyOrbit(double dx, double dy) {
    _yaw += dx * 0.0085;
    _pitch = (_pitch + dy * 0.0070).clamp(-1.05, 1.18);
    _targetYaw = _yaw;
    _targetPitch = _pitch;
    _cameraHoming = false;
    _orbiting = true;
    _dirty = true;
    final speed = dx.abs() + dy.abs();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (speed > 1.2 && now - _lastSpinSoundMs > 150) {
      _lastSpinSoundMs = now;
      _play(
        JellySfx.spin,
        gain: (0.10 + speed * 0.010).clamp(0.10, 0.30),
        rate: (0.75 + speed * 0.012).clamp(0.75, 1.35),
      );
    }
  }

  void _zoomBy(double factor) {
    _zoom = (_zoom * factor).clamp(0.68, 1.58);
    _targetZoom = _zoom;
    _cameraHoming = false;
    _dirty = true;
  }

  // ------------------------------------------------------------------- input
  void pointerDown(
    int id,
    Offset position, {
    double pressure = 1,
    bool stylus = false,
  }) {
    if (_demoMode) return;
    if (_solving || _scrambling) _cancelAutomation();
    _primeAudioForGesture();
    if (_edgeGuard(position)) {
      _pointers[id] = _PointerSeat(position, position)..ignored = true;
      _pointerOrder.add(id);
      return;
    }
    final seat = _PointerSeat(position, position);
    _pointers[id] = seat;
    _pointerOrder.add(id);
    if (_pointers.length > 2) {
      seat.ignored = true;
      return;
    }
    if (_pointers.length == 2) {
      _beginPinch();
      return;
    }

    _haptic(HapticFeedback.selectionClick);
    switch (_tool) {
      case JellyTool.twist:
        final hit = _pickHit(position);
        _pendingHit = hit;
        seat.mode = hit == null ? 'spinPending' : 'twistPending';
        break;
      case JellyTool.spin:
        seat.mode = 'spin';
        break;
      case JellyTool.poke:
        seat.mode = 'pokePending';
        break;
      case JellyTool.drop:
        seat.mode = 'dropPending';
        break;
    }
    if (stylus && _interactive == null) {
      // Precision instruments do not need touch slop.
      seat.mode = 'pokeDone';
      _startPoke(position, pressure.clamp(0.25, 1.0));
    }
  }

  void pointerMove(int id, Offset position, {double pressure = 1}) {
    if (_demoMode) return;
    final seat = _pointers[id];
    if (seat == null) return;
    if (seat.ignored) {
      seat.last = position;
      return;
    }

    if (_pointers.length >= 2) {
      seat.last = position;
      final positions = _pointers.values
          .where((p) => !p.ignored)
          .map((p) => p.last)
          .toList(growable: false);
      if (positions.length >= 2) {
        final center = (positions[0] + positions[1]) * 0.5;
        final distance = (positions[0] - positions[1]).distance;
        if (!_pinching) _beginPinch();
        final delta = center - _pinchLastCenter;
        _pinchLastCenter = center;
        _applyOrbit(delta.dx, delta.dy);
        if (_pinchStartDistance > 8) {
          _zoomBy(distance / _pinchStartDistance);
          _pinchStartDistance = distance;
        }
        _dirty = true;
        notifyListeners();
      }
      return;
    }

    final previous = seat.last;
    seat.last = position;
    final total = position - seat.down;
    if (!seat.slopPassed && total.distance >= 10) {
      seat.slopPassed = true;
    }

    if (seat.mode == 'twistPending' && seat.slopPassed) {
      final hit = _pendingHit;
      final intent = hit == null ? null : _projection().dragIntent(hit, total);
      if (intent == null) {
        seat.mode = 'spin';
      } else {
        _beginInteractive(hit!, intent, seat.down);
        seat.mode = 'twist';
        _turnPointer = id;
      }
    }

    if (seat.mode == 'spinPending' && seat.slopPassed) {
      seat.mode = 'spin';
      _orbiting = true;
    }

    if (seat.mode == 'twist') {
      _updateInteractive(position);
    } else if (seat.mode == 'spin') {
      // Use frame delta, not total, to avoid acceleration.
      final frameDelta = position - previous;
      _applyOrbit(frameDelta.dx, frameDelta.dy);
      _camVelYaw = frameDelta.dx * 0.32;
      _camVelPitch = frameDelta.dy * 0.26;
      notifyListeners();
    }
  }

  void pointerUp(int id, Offset position, {double pressure = 1}) {
    if (_demoMode) return;
    final seat = _pointers.remove(id);
    _pointerOrder.remove(id);
    if (seat == null) return;
    if (seat.ignored) return;

    final wasTurnPointer = _turnPointer == id;
    final total = position - seat.down;
    final held = DateTime.now().difference(seat.started);

    if (_pointers.isEmpty) {
      _pinching = false;
      if (_interactive != null && wasTurnPointer) {
        _releaseInteractive(position);
      } else if (total.distance < 10 && held.inMilliseconds < 450) {
        _handleTap(position, pressure);
      }
      _orbiting = false;
      _turnPointer = null;
    } else if (_pointers.length == 1) {
      final remaining = _pointers.values.first;
      remaining.mode = 'spin';
      _pinching = false;
      remaining.slopPassed = true;
      _pinchLastCenter = remaining.last;
    }
    _dirty = true;
    notifyListeners();
  }

  void pointerCancel(int id) {
    if (_demoMode) return;
    final seat = _pointers.remove(id);
    _pointerOrder.remove(id);
    if (seat == null) return;
    if (_turnPointer == id) {
      _settleInteractive(preempt: false);
      _turnPointer = null;
    }
    if (_pointers.isEmpty) {
      _pinching = false;
      _orbiting = false;
    }
    notifyListeners();
  }

  bool _edgeGuard(Offset p) {
    const guard = 24.0;
    return p.dx < guard ||
        p.dy < guard ||
        p.dx > _viewportSize.width - guard ||
        p.dy > _viewportSize.height - guard;
  }

  void _beginPinch() {
    _pinching = true;
    final positions = _pointers.values
        .where((p) => !p.ignored)
        .map((p) => p.last)
        .toList(growable: false);
    if (positions.length >= 2) {
      _pinchStartDistance = (positions[0] - positions[1]).distance;
      _pinchLastCenter = (positions[0] + positions[1]) * 0.5;
    }
    if (_interactive != null) {
      _settleInteractive(preempt: true);
    }
    _turnPointer = null;
    _orbiting = true;
  }

  void _beginInteractive(
    JellyHit hit,
    JellyDragIntent intent,
    Offset dragOrigin,
  ) {
    final projection = _projection();
    final centerWorld =
        projection.worldCubeletCenter(hit.cubie.pos) + hit.normal * 0.48;
    final axisVec = switch (intent.axis) {
      0 => const V3(1, 0, 0),
      1 => const V3(0, 1, 0),
      _ => const V3(0, 0, 1),
    };
    final surface = axisVec.cross(centerWorld) * (intent.sign * 0.25);
    final p0 = projection.project(centerWorld);
    final p1 = projection.project(centerWorld + surface);
    var dir = p1 - p0;
    if (dir.distance < 1) dir = const Offset(0, -1);
    dir = dir / dir.distance;
    final degreesPerPixel = 90.0 / math.max(52.0, projection.scale * 1.05);
    _interactive = JellyInteractiveTurn(
      axis: intent.axis,
      coordinate: intent.coordinate,
      sign: intent.sign,
      notation: intent.notation,
      screenDirection: dir,
      degreesPerPixel: degreesPerPixel,
      hit: hit,
      dragOrigin: dragOrigin,
    );
    _turns.clear();
    _lastInteractiveAngle = 0;
    _lastInteractiveTime = DateTime.now();
    _turnVelocity = 0;
    _pendingHit = hit;
    _orbiting = false;
    _play(JellySfx.twist, gain: 0.28, rate: 1.15);
  }

  void _updateInteractive(Offset position) {
    final turn = _interactive;
    if (turn == null) return;
    final drag = position - turn.dragOrigin;
    final angle =
        (drag.dx * turn.screenDirection.dx +
            drag.dy * turn.screenDirection.dy) *
        turn.degreesPerPixel;
    final clamped = angle.clamp(-155.0, 155.0);
    final now = DateTime.now();
    final dt = now.difference(_lastInteractiveTime).inMicroseconds / 1e6;
    if (dt > 1e-4) {
      turn.angularVelocity = ((clamped - _lastInteractiveAngle) / dt).clamp(
        -1200.0,
        1200.0,
      );
      _turnVelocity = turn.angularVelocity;
    }
    _lastInteractiveAngle = clamped;
    _lastInteractiveTime = now;
    turn.angle = clamped;

    if (!turn.committed && clamped.abs() >= 45) {
      _commitInteractiveTurn(turn);
    }
    _dirty = true;
    notifyListeners();
  }

  void _commitInteractiveTurn(JellyInteractiveTurn turn) {
    if (turn.committed) return;
    turn.committed = true;
    final sign = turn.angle.isNegative ? -1 : 1;
    turn.committedSign = sign;
    final move = JellyMove(
      axis: turn.axis,
      coordinates: <int>[turn.coordinate],
      quarterTurns: sign,
      notation: turn.notation,
    );
    _commitMove(move, record: true, user: true, animate: false);
    _haptic(HapticFeedback.mediumImpact);
    _play(JellySfx.snap, gain: 0.52);
    _rockVel -= sign * 9;
  }

  void _spawnResidual(JellyInteractiveTurn turn) {
    _turns.clear();
    final residual = turn.committed
        ? turn.angle - turn.committedSign * 90.0
        : turn.angle;
    final anim = JellyTurnAnimation(
      axis: turn.axis,
      coordinates: <int>[turn.coordinate],
      angle: residual,
      velocity: turn.angularVelocity,
      notation: turn.notation,
    );
    _turns.add(anim);
    if (_turns.length > 14) _turns.removeAt(0);
  }

  void _releaseInteractive(Offset position) {
    final turn = _interactive;
    if (turn == null) return;
    _updateInteractive(position);
    final flick = _turnVelocity.abs() > 170 && turn.angle.abs() > 28;
    if (!turn.committed && (turn.angle.abs() >= 45 || flick)) {
      _commitInteractiveTurn(turn);
    }
    _spawnResidual(turn);
    _interactive = null;
    _lastInteractiveAngle = 0;
    _turnVelocity = 0;
    _dirty = true;
  }

  void _settleInteractive({required bool preempt}) {
    final turn = _interactive;
    if (turn == null) return;
    if (!turn.committed && turn.angle.abs() >= 45) {
      _commitInteractiveTurn(turn);
    }
    _spawnResidual(turn);
    _interactive = null;
    _turnPointer = null;
    _dirty = true;
  }

  void _handleTap(Offset position, double pressure) {
    switch (_tool) {
      case JellyTool.poke:
        _startPoke(position, pressure.clamp(0.3, 1.0));
        break;
      case JellyTool.drop:
        drop();
        break;
      case JellyTool.twist:
        _startPoke(position, (pressure * 0.65).clamp(0.25, 0.85));
        break;
      case JellyTool.spin:
        break;
    }
  }

  // -------------------------------------------------------------------- tools
  void drop() {
    if (_demoMode) return;
    if (_airborne) return;
    _beginDrop(1.85);
    _play(JellySfx.spin, gain: 0.25, rate: 0.65);
    notifyListeners();
  }

  void _beginDrop(double height) {
    _lift = height;
    _fallVelocity = 0;
    _airborne = true;
    _bounceCount = 0;
    _dirty = true;
  }

  void poke(Offset point, double strength) {
    if (_demoMode) return;
    _startPoke(point, strength.clamp(0.15, 1.0));
  }

  void _startPoke(Offset point, double strength) {
    final hit = _pickHit(point);
    if (hit == null) {
      _haptic(HapticFeedback.selectionClick);
      return;
    }
    _startPokeAtHit(hit, strength);
  }

  void _startPokeAtHit(JellyHit hit, double strength, {int? forceLocalFace}) {
    final localFace = forceLocalFace ?? hit.localFace;
    final effect = JellyPokeEffect(
      cubeletId: hit.cubeletId,
      localFace: localFace,
      worldFace: hit.face,
      strength: strength,
    );
    _pokeEffect = effect;
    _pokeTrail.add(effect);
    if (_pokeTrail.length > 3) _pokeTrail.removeAt(0);
    _rockVel += strength * 4.2;
    _play(
      JellySfx.poke,
      gain: 0.4 + strength * 0.35,
      rate: 0.9 + strength * 0.22,
    );
    _haptic(HapticFeedback.lightImpact);
    _dirty = true;
    notifyListeners();
  }

  void _primeAudioForGesture() {
    if (_muted || _demoMode) return;
    unawaited(_audio.init());
  }

  // -------------------------------------------------------------- automation
  Future<void> _demoPoke() async {
    final cubie = _cube.cubies
        .where((c) => c.pos == Int3(0, 0, _size - 1))
        .firstOrNull;
    if (cubie == null) return;
    var localFace = faceF;
    for (final f in cubie.stickers) {
      final w = cubie.orientation.apply(kFaceNormals[f]);
      if (w == kFaceNormals[faceF]) {
        localFace = f;
        break;
      }
    }
    final hit = JellyHit(
      cubie: cubie,
      cubeletId: cubie.id,
      face: faceF,
      localFace: localFace,
      normal: const V3(0, 0, 1),
      polygon: const <Offset>[],
      depth: 3,
      screenCenter: _projection().center,
    );
    _startPokeAtHit(hit, 0.92);
    _haptic(HapticFeedback.lightImpact);
  }

  // -------------------------------------------------------------------- pick
  JellyProjection _projection() => JellyProjection(
    canvasSize: _viewportSize,
    sceneRect: _sceneRect,
    cubeSize: _size,
    camera: camera,
    lift: _lift,
    squashY: squashY,
    squashXZ: squashXZ,
    cubeScale: 0.96,
  );

  JellyHit? _pickHit(Offset point) => _projection().pick(_cube, point);

  /// Public pick. Returns cubelet id, discrete position and face index.
  Map<String, dynamic>? pick(Offset point) => _pickHit(point)?.toMap();

  JellyHit? hitTest(Offset point) => _pickHit(point);

  /// Programmatic drag used by the automation hook and accessibility tools.
  void drag(Offset p0, Offset p1) {
    if (_demoMode) return;
    _cancelAutomation(silent: true);
    final projection = _projection();
    final hit = projection.pick(_cube, p0);
    if (hit == null) {
      spin((p1.dx - p0.dx) * 1.2, (p1.dy - p0.dy) * 1.2);
      return;
    }
    final dragDelta = p1 - p0;
    if (dragDelta.distance < 2) {
      _startPokeAtHit(hit, 0.65);
      return;
    }
    final intent = projection.dragIntent(hit, dragDelta);
    if (intent == null) return;
    final move = JellyMove(
      axis: intent.axis,
      coordinates: <int>[intent.coordinate],
      quarterTurns: intent.sign,
      notation: intent.notation,
    );
    _commitMove(move, record: true, user: true, animate: true);
  }

  // -------------------------------------------------------------------- melt
  /// Used by the hidden `?preview=melt` art-direction route.
  void previewMelt({double? freezeAt}) {
    if (_demoMode || _meltPlaying) return;
    if (freezeAt == null) {
      _startMelt();
      return;
    }
    final t = freezeAt.clamp(0.0, 3.7);
    _meltTime = t;
    if (t < 1.15) {
      _melt = _smooth(t / 1.15);
    } else if (t < 1.85) {
      _melt = 1;
    } else if (t < 3.55) {
      _melt = 1 - _smooth((t - 1.85) / 1.7);
    } else {
      _melt = 0;
    }
    _meltPlaying = false;
    _meltBadge = true;
    _dirty = true;
    notifyListeners();
  }

  void _startMelt() {
    if (_meltPlaying || _demoMode) return;
    _meltPlaying = true;
    _meltBadge = true;
    _meltTime = 0;
    _melt = 0;
    _play(JellySfx.solve, gain: 0.95, rate: 0.82);
    _haptic(HapticFeedback.mediumImpact);
    notifyListeners();
  }

  void _stepMelt(double dt) {
    if (!_meltPlaying) return;
    _meltTime += dt;
    final t = _meltTime;
    if (t < 1.15) {
      _melt = _smooth(t / 1.15);
    } else if (t < 1.85) {
      _melt = 1;
    } else if (t < 3.55) {
      _melt = 1 - _smooth((t - 1.85) / 1.7);
    } else {
      _melt = 0;
      _meltPlaying = false;
    }
    _dirty = true;
  }

  // ------------------------------------------------------------------- demo
  void startDemo({double? freezeAt, bool force = false}) {
    if (_demoMode && !force) return;
    _demoMode = true;
    _muted = true;
    _audio.enabled = false;
    _cancelAutomation(silent: true);
    _size = 3;
    _cube = JellyCube.solved(3);
    _history.clear();
    _turns.clear();
    _interactive = null;
    _pokeEffect = null;
    _pokeTrail.clear();
    _moveCount = 0;
    _manualMoves = 0;
    _clockStartMs = 0;
    _scrambled = false;
    _usedUndo = false;
    _usedSolve = false;
    _wasSolved = true;
    _meltPlayed = false;
    _meltPlaying = false;
    _meltBadge = false;
    _melt = 0;
    _meltTime = 0;
    _rock = 0;
    _rockVel = 0;
    _squash = 0;
    _squashVel = 0;
    _lift = 0;
    _fallVelocity = 0;
    _airborne = false;
    _yaw = 0.58;
    _pitch = 0.43;
    _zoom = 1.0;
    _targetYaw = _yaw;
    _targetPitch = _pitch;
    _targetZoom = 1;
    _cameraHoming = false;
    _softness = 0.95;
    _speed = 1.80;
    _demoTime = 0;
    _demoEventIndex = 0;
    if (freezeAt != null) {
      _demoFrozen = true;
      _simulateDemoTo(freezeAt.clamp(0.0, 3.98));
    } else {
      _demoFrozen = false;
      _fireDemoEvents(0, 0);
    }
    _dirty = true;
    notifyListeners();
  }

  static const List<(double, String)> _demoEvents = <(double, String)>[
    (0.0, 'drop'),
    (0.8, 'R'),
    (1.6, 'U'),
    (2.1, 'poke'),
    (2.6, "U'"),
    (3.1, "R'"),
  ];

  void _simulateDemoTo(double seconds) {
    final steps = (seconds * 120).round();
    _demoFrozen = false;
    for (var i = 0; i < steps; i++) {
      _advanceDemo(1 / 120, simulate: true);
    }
    _demoFrozen = true;
  }

  void _advanceDemo(double dt, {bool simulate = false}) {
    final previous = _demoTime;
    _demoTime += dt;
    if (_demoTime >= 4.0) {
      _demoTime = 0;
      _demoEventIndex = 0;
      _cube = JellyCube.solved(3);
      _turns.clear();
      _interactive = null;
      _pokeEffect = null;
      _pokeTrail.clear();
      _rock = 0;
      _rockVel = 0;
      _squash = 0;
      _squashVel = 0;
      _lift = 0;
      _fallVelocity = 0;
      _airborne = false;
      _wasSolved = true;
      _fireDemoEvents(0, 0);
    } else {
      _fireDemoEvents(previous, _demoTime);
    }
    _stepPhysics(dt);
    if (!simulate) _dirty = true;
  }

  void _fireDemoEvents(double previous, double now) {
    while (_demoEventIndex < _demoEvents.length) {
      final event = _demoEvents[_demoEventIndex];
      if (event.$1 > now + 1e-9) break;
      if (event.$1 > previous - 1e-9) {
        switch (event.$2) {
          case 'drop':
            _beginDrop(1.85);
            break;
          case 'poke':
            unawaited(_demoPoke());
            break;
          default:
            final move = parseJellyMove(event.$2, 3);
            _commitMove(move, record: false, animate: true, silent: true);
            break;
        }
      }
      _demoEventIndex++;
    }
  }

  // -------------------------------------------------------------------- tick
  void update(Duration elapsed) {
    if (_disposed) return;
    if (_demoFrozen) return;
    var dt = 0.0;
    if (_hasTick) {
      dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    }
    _lastElapsed = elapsed;
    _hasTick = true;
    if (_demoMode) {
      if (dt > 0.25) dt = 1 / 60;
      _advanceDemo(dt);
      if (_dirty) {
        _dirty = false;
        notifyListeners();
      }
      return;
    }
    if (dt <= 0) return;
    if (dt > 0.25) dt = 1 / 60;
    _accumulator += dt;
    while (_accumulator >= _fixedStep) {
      _accumulator -= _fixedStep;
      _stepPhysics(_fixedStep);
    }
    // Only rebuild when something actually moved. The ticker itself runs at
    // 120 Hz, but an idle cube must not repaint 60 times a second.
    if (_dirty) {
      _dirty = false;
      notifyListeners();
    }
  }

  void _stepPhysics(double dt) {
    _visualTime += dt;
    var animating = false;
    final stiffness =
        155.0 *
        math.pow(0.72 + _speed * 0.64, 2) *
        (_reducedMotion ? 0.82 : 1.0);
    final zeta = (_reducedMotion ? 0.90 : (0.63 - _softness * 0.20)).clamp(
      0.40,
      0.90,
    );
    final damping = 2 * zeta * math.sqrt(stiffness);

    for (final turn in _turns) {
      turn.previousAngle = turn.angle;
      turn.previousVelocity = turn.velocity;
      final accel = -stiffness * turn.angle - damping * turn.velocity;
      turn.velocity += accel * dt;
      turn.angle += turn.velocity * dt;
      if (!turn.snapped && turn.angle.abs() <= 45) {
        turn.snapped = true;
        _haptic(HapticFeedback.mediumImpact);
        _play(JellySfx.snap, gain: 0.24);
      }
      if (!turn.overshootFired &&
          turn.previousVelocity * turn.velocity < 0 &&
          turn.angle.abs() > 2.0) {
        turn.overshootFired = true;
        _haptic(HapticFeedback.lightImpact);
        _play(JellySfx.bloop, gain: 0.23);
      }
      if (turn.angle.abs() < 0.045 && turn.velocity.abs() < 0.32) {
        turn.angle = 0;
        turn.finished = true;
        _dirty = true;
      }
      if (!turn.finished) animating = true;
    }
    _turns.removeWhere((t) => t.finished);

    // Body rock settles on a slightly underdamped spring.
    _rockVel += (-_rock * 125 - _rockVel * 10.5) * dt;
    _rock += _rockVel * dt;
    if (_rock.abs() < 0.0015 && _rockVel.abs() < 0.02) {
      _rock = 0;
      _rockVel = 0;
    } else {
      animating = true;
    }

    // Squash spring.
    _squashVel += (-_squash * 168 - _squashVel * 9.2) * dt;
    _squash += _squashVel * dt;
    if (_squash.abs() < 0.0008 && _squashVel.abs() < 0.012) {
      _squash = 0;
      _squashVel = 0;
    } else {
      animating = true;
    }

    if (_airborne) {
      _fallVelocity -= 12.5 * dt;
      _lift += _fallVelocity * dt;
      if (_lift <= 0) {
        _lift = 0;
        final impact = -_fallVelocity;
        _fallVelocity = 0;
        _airborne = false;
        _squash = math.max(_squash, (impact * 0.026).clamp(0.075, 0.18));
        _squashVel = -impact * 0.55;
        final firstContact = _bounceCount == 0;
        _haptic(
          firstContact
              ? HapticFeedback.heavyImpact
              : HapticFeedback.lightImpact,
        );
        _play(
          JellySfx.drop,
          gain: firstContact ? (0.5 + impact * 0.05).clamp(0.4, 1.0) : 0.26,
        );
        if (impact > 2.4 && _bounceCount < 3) {
          _bounceCount++;
          _lift = 0.001;
          _fallVelocity = impact * 0.28;
          _airborne = true;
        }
      }
      animating = true;
    }

    if (_pokeEffect != null) {
      final effect = _pokeEffect!;
      effect.elapsed += dt;
      if (effect.elapsed >= effect.duration) {
        _pokeTrail.remove(effect);
        _pokeEffect = null;
      } else {
        animating = true;
      }
    }
    for (final p in _pokeTrail.toList(growable: false)) {
      if (p.elapsed >= p.duration) _pokeTrail.remove(p);
    }

    if (_meltPlaying) {
      _stepMelt(dt);
      animating = true;
    }

    // Camera inertia / home spring.
    if (_interactive == null && !_pinching && !_orbiting) {
      if (_cameraHoming) {
        final k = 1 - math.exp(-dt * 9.0);
        _yaw += (_targetYaw - _yaw) * k;
        _pitch += (_targetPitch - _pitch) * k;
        _zoom += (_targetZoom - _zoom) * k;
        if ((_yaw - _targetYaw).abs() < 0.0005 &&
            (_pitch - _targetPitch).abs() < 0.0005 &&
            (_zoom - _targetZoom).abs() < 0.0005) {
          _yaw = _targetYaw;
          _pitch = _targetPitch;
          _zoom = _targetZoom;
          _cameraHoming = false;
          _dirty = true;
        } else {
          animating = true;
        }
      } else if (_camVelYaw.abs() > 0.002 || _camVelPitch.abs() > 0.002) {
        _yaw += _camVelYaw * dt;
        _pitch = (_pitch + _camVelPitch * dt).clamp(-1.05, 1.18);
        final friction = math.pow(0.08, dt).toDouble();
        _camVelYaw *= friction;
        _camVelPitch *= friction;
        animating = true;
      }
    }

    if (animating) _dirty = true;
  }

  // ------------------------------------------------------------------ toasts
  void _showToast(String text, {int duration = 2500}) {
    if (_demoMode) return;
    final token = ++_toastSerial;
    _toast = text;
    _toastTimer?.cancel();
    _toastTimer = Timer(Duration(milliseconds: duration), () {
      if (_disposed || token != _toastSerial) return;
      _toast = null;
      notifyListeners();
    });
    notifyListeners();
  }

  void clearToast() {
    _toast = null;
    _toastSerial++;
    notifyListeners();
  }

  // -------------------------------------------------------------------- util
  int _scrambleElapsed() {
    if (_clockStartMs == 0) return 0;
    return DateTime.now().millisecondsSinceEpoch - _clockStartMs;
  }

  static String formatDuration(int ms) {
    final total = (ms / 1000).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _haptic(Future<void> Function() effect) {
    if (!_haptics || _demoMode) return;
    try {
      unawaited(effect().catchError((Object _) {}));
    } catch (_) {}
  }

  void _play(JellySfx sfx, {double gain = 1, double rate = 1}) {
    if (_muted || _demoMode) return;
    unawaited(_audio.play(sfx, gain: gain, rate: rate));
  }

  static double _smooth(double t) {
    final x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  Map<String, dynamic> state() => <String, dynamic>{
    'size': _size,
    'faces': _cube.faceStrings(),
    'solved': _cube.isSolved,
    'solvedFaces': _cube.solvedFaceCount,
    'moves': _moveCount,
    'history': history,
    'busy': busy,
    'intact': _cube.isIntact,
    'tool': _tool.name,
    'phase': phase.name,
    'scrambling': _scrambling,
    'solving': _solving,
    'solveIndex': _solveIndex,
    'solveTotal': _solveTotal,
    'flavors': kFlavorNames,
    'audio': _audio.backendName,
    'meltBadge': _meltBadge,
    'muted': _muted,
  };

  @override
  void dispose() {
    _disposed = true;
    _toastTimer?.cancel();
    _purchases.removeListener(_onPurchasesChanged);
    _purchases.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }
}
