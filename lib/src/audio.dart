import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_io_stub.dart'
    if (dart.library.html) 'audio_io_web.dart'
    if (dart.library.io) 'audio_io_native.dart'
    as io;

enum JellySfx { twist, spin, poke, drop, scramble, solve, bloop, snap }

/// A tiny, deterministic offline synthesizer. Every sample is generated from
/// oscillators, filtered noise and envelopes; there are no audio assets.
class JellySynth {
  static const int sampleRate = 44100;

  static Float32List render(JellySfx sfx) {
    switch (sfx) {
      case JellySfx.twist:
        return _twist();
      case JellySfx.spin:
        return _spin();
      case JellySfx.poke:
        return _poke();
      case JellySfx.drop:
        return _drop();
      case JellySfx.scramble:
        return _scramble();
      case JellySfx.solve:
        return _solve();
      case JellySfx.bloop:
        return _bloop();
      case JellySfx.snap:
        return _snap();
    }
  }

  static double _noise(_Lcg rng) => rng.next() * 2 - 1;

  static Float32List _twist() {
    final n = (sampleRate * 0.62).round();
    final out = Float32List(n);
    final rng = _Lcg(0x51A7E);
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final attack = (t / 0.014).clamp(0.0, 1.0);
      final air = attack * math.exp(-t * 8.2);
      final cutoff = 0.035 + 0.16 * math.exp(-t * 7.0);
      lp += (_noise(rng) - lp) * cutoff;
      final suction = math.exp(-math.pow((t - 0.20) / 0.085, 2).toDouble());
      final thupPhase = 2 * math.pi * (84 * t - 16 * t * t);
      final thup = math.sin(thupPhase) * math.exp(-t * 13.0) * 0.72;
      final wet = (lp * 1.4 + _noise(rng) * 0.06) * suction * 0.58;
      final bloop =
          math.sin(2 * math.pi * (182 * t + 14 * t * t)) *
          math.exp(-math.pow((t - 0.34) / 0.095, 2).toDouble()) *
          0.25;
      out[i] =
          (air * (lp * 0.8 + _noise(rng) * 0.16) * 0.6) +
          thup * 0.44 +
          wet * 0.35 +
          bloop;
    }
    _fade(out, 0.012);
    return _normalize(out, 0.76);
  }

  static Float32List _spin() {
    final n = (sampleRate * 0.82).round();
    final out = Float32List(n);
    final rng = _Lcg(0xC0FFEE);
    var hp = 0.0;
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final env = math
          .sin(math.pi * (t / 0.82).clamp(0.0, 1.0))
          .clamp(0.0, 1.0);
      final noise = _noise(rng);
      lp += (noise - lp) * 0.06;
      hp = noise - lp;
      final shimmer =
          math.sin(2 * math.pi * 740 * t) * 0.025 +
          math.sin(2 * math.pi * 1110 * t + 0.7) * 0.018;
      out[i] = (hp * 0.30 + shimmer) * env;
    }
    _fade(out, 0.05);
    return _normalize(out, 0.42);
  }

  static Float32List _poke() {
    final n = (sampleRate * 0.52).round();
    final out = Float32List(n);
    final rng = _Lcg(0x7E57);
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final bend = 210 - 128 * (1 - math.exp(-t * 13));
      final pop = math.sin(2 * math.pi * bend * t) * math.exp(-t * 10.5);
      final squishEnv = math.exp(-math.pow((t - 0.06) / 0.055, 2).toDouble());
      lp += (_noise(rng) - lp) * 0.05;
      final squish = lp * squishEnv * 0.42;
      out[i] = pop * 0.58 + squish;
    }
    _fade(out, 0.008);
    return _normalize(out, 0.66);
  }

  static Float32List _drop() {
    final n = (sampleRate * 0.92).round();
    final out = Float32List(n);
    final rng = _Lcg(0xB00B);
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final body =
          math.sin(2 * math.pi * (54 * t - 8 * t * t)) * math.exp(-t * 8.5);
      final sub = math.sin(2 * math.pi * 31 * t) * math.exp(-t * 5.4);
      lp += (_noise(rng) - lp) * 0.03;
      final contact = lp * math.exp(-t * 28) * 1.8;
      final tap1 =
          math.sin(2 * math.pi * 120 * (t - 0.20)) *
          math.exp(-math.pow((t - 0.21) / 0.024, 2).toDouble()) *
          0.30;
      final tap2 =
          math.sin(2 * math.pi * 168 * (t - 0.34)) *
          math.exp(-math.pow((t - 0.35) / 0.026, 2).toDouble()) *
          0.16;
      out[i] = body * 0.66 + sub * 0.34 + contact * 0.28 + tap1 + tap2;
    }
    _fade(out, 0.02);
    return _normalize(out, 0.82);
  }

  static Float32List _scramble() {
    final n = (sampleRate * 0.16).round();
    final out = Float32List(n);
    final rng = _Lcg(0x1234);
    var lp = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final click = math.exp(-t * 52);
      final tick =
          math.sin(2 * math.pi * 1550 * t) * 0.22 +
          math.sin(2 * math.pi * 990 * t) * 0.18;
      lp += (_noise(rng) - lp) * 0.22;
      out[i] = (tick + lp * 0.55) * click;
    }
    _fade(out, 0.004);
    return _normalize(out, 0.46);
  }

  static Float32List _solve() {
    final n = (sampleRate * 1.65).round();
    final out = Float32List(n);
    final notes = <double>[392.0, 523.25, 659.25, 783.99, 1046.5];
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var sample = 0.0;
      for (var k = 0; k < notes.length; k++) {
        final start = 0.10 * k;
        if (t < start) continue;
        final local = t - start;
        final env = (local / 0.018).clamp(0.0, 1.0) * math.exp(-local * 2.6);
        final wobble = 1 + 0.006 * math.sin(2 * math.pi * 5.2 * t + k);
        sample +=
            math.sin(2 * math.pi * notes[k] * wobble * local) * env * 0.23;
        sample += math.sin(2 * math.pi * notes[k] * 2.01 * local) * env * 0.055;
      }
      final shimmer =
          math.sin(2 * math.pi * 2093 * t) *
          math.exp(-math.pow((t - 0.62) / 0.18, 2).toDouble()) *
          0.05;
      out[i] = sample + shimmer;
    }
    _fade(out, 0.06);
    return _normalize(out, 0.64);
  }

  static Float32List _bloop() {
    final n = (sampleRate * 0.34).round();
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final f = 225 - 72 * (1 - math.exp(-t * 7));
      final env = math.exp(-t * 5.4);
      out[i] =
          math.sin(2 * math.pi * f * t) * env * 0.55 +
          math.sin(2 * math.pi * f * 1.98 * t) * env * 0.16;
    }
    _fade(out, 0.01);
    return _normalize(out, 0.38);
  }

  static Float32List _snap() {
    final n = (sampleRate * 0.09).round();
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      out[i] =
          math.sin(2 * math.pi * 1250 * t) * math.exp(-t * 58) * 0.34 +
          math.sin(2 * math.pi * 720 * t) * math.exp(-t * 44) * 0.18;
    }
    _fade(out, 0.004);
    return _normalize(out, 0.34);
  }

  static void _fade(Float32List samples, double seconds) {
    final count = math.min(samples.length, (seconds * sampleRate).round());
    for (var i = 0; i < count; i++) {
      final g = i / count;
      samples[samples.length - 1 - i] *= g;
      samples[i] *= math.min(1.0, i / math.max(1, count * 0.35));
    }
  }

  static Float32List _normalize(Float32List samples, double peak) {
    var maxAbs = 0.0;
    for (final v in samples) {
      maxAbs = math.max(maxAbs, v.abs());
    }
    if (maxAbs < 1e-6) return samples;
    final gain = peak / maxAbs;
    for (var i = 0; i < samples.length; i++) {
      samples[i] *= gain;
    }
    return samples;
  }
}

class _Lcg {
  _Lcg(this._state);
  int _state;
  double next() {
    _state = (1664525 * _state + 1013904223) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}

/// Pre-renders the six signature sounds and enforces a 16-voice ceiling.
class JellyAudioEngine {
  JellyAudioEngine({this.enabled = true});

  final io.JellyAudioSink _sink = io.createJellyAudioSink();
  final Map<JellySfx, Float32List> _buffers = <JellySfx, Float32List>{};
  final List<DateTime> _voices = <DateTime>[];
  bool enabled;
  double volume = 0.72;
  bool _initialized = false;
  Future<void>? _initFuture;

  String get backendName => _sink.backendName;

  Future<void> init() {
    if (!enabled) return Future<void>.value();
    if (_initialized) return Future<void>.value();
    return _initFuture ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      for (final sfx in JellySfx.values) {
        _buffers[sfx] = JellySynth.render(sfx);
      }
      await _sink.init();
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  Future<void> play(JellySfx sfx, {double gain = 1, double rate = 1}) async {
    if (!enabled || volume <= 0.001) return;
    try {
      await init();
      if (!_initialized) return;
      final now = DateTime.now();
      _voices.removeWhere((v) => now.difference(v).inMilliseconds > 1800);
      if (_voices.length >= 16) return;
      final samples = _buffers[sfx];
      if (samples == null) return;
      _voices.add(now);
      await _sink.play(
        sfx.name,
        samples,
        volume: (volume * gain).clamp(0.0, 1.0),
        rate: rate.clamp(0.5, 2.0),
      );
    } catch (_) {
      // Sound is a garnish, never a dependency.
    }
  }

  Future<void> dispose() async {
    try {
      await _sink.dispose();
    } catch (_) {}
    _voices.clear();
    _initialized = false;
    _initFuture = null;
  }
}
