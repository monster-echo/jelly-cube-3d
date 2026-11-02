import 'dart:typed_data';

import 'package:flutter/services.dart';

abstract class JellyAudioSink {
  Future<void> init();
  Future<void> play(
    String name,
    Float32List samples, {
    double volume = 1,
    double rate = 1,
  });
  Future<void> dispose();
  String get backendName;
}

JellyAudioSink createJellyAudioSink() => _NativeSink();

class _NativeSink implements JellyAudioSink {
  static const MethodChannel _channel = MethodChannel(
    'tech.zhongbei/jellycube3d_audio',
  );

  bool _ready = false;

  @override
  String get backendName => 'native-pcm';

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      await _channel.invokeMethod<void>('init', <String, Object>{
        'sampleRate': 44100,
      });
      _ready = true;
    } catch (_) {
      // Platform audio is optional; the visual instrument never fails.
      _ready = false;
    }
  }

  @override
  Future<void> play(
    String name,
    Float32List samples, {
    double volume = 1,
    double rate = 1,
  }) async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod<void>('play', <String, Object>{
        'name': name,
        'volume': volume.clamp(0.0, 1.0),
        'rate': rate.clamp(0.5, 2.0),
        'pcm': samples,
      });
    } catch (_) {
      // Ignore a missing/unavailable audio route.
    }
  }

  @override
  Future<void> dispose() async {
    if (!_ready) return;
    try {
      await _channel.invokeMethod<void>('dispose');
    } catch (_) {}
    _ready = false;
  }
}
