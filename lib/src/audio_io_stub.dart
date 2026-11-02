import 'dart:typed_data';

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

JellyAudioSink createJellyAudioSink() => _StubSink();

class _StubSink implements JellyAudioSink {
  @override
  Future<void> init() async {}

  @override
  Future<void> play(
    String name,
    Float32List samples, {
    double volume = 1,
    double rate = 1,
  }) async {}

  @override
  Future<void> dispose() async {}

  @override
  String get backendName => 'silent';
}
