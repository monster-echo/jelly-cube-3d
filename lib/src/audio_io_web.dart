import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
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

JellyAudioSink createJellyAudioSink() => _WebSink();

class _WebSink implements JellyAudioSink {
  JSObject? _context;
  bool _ready = false;

  @override
  String get backendName => 'webaudio-pcm';

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      final constructor = globalContext['AudioContext'] as JSFunction?;
      if (constructor == null) return;
      final ctx = constructor.callAsConstructor<JSObject>();
      _context = ctx;
      _ready = true;
      _resume(ctx);
    } catch (_) {
      _ready = false;
    }
  }

  void _resume(JSObject ctx) {
    try {
      final state = (ctx['state'] as JSString?)?.toDart;
      if (state == 'suspended') {
        ctx.callMethod<JSPromise<JSAny?>>('resume'.toJS);
      }
    } catch (_) {}
  }

  @override
  Future<void> play(
    String name,
    Float32List samples, {
    double volume = 1,
    double rate = 1,
  }) async {
    if (!_ready) {
      await init();
      if (!_ready) return;
    }
    final ctx = _context;
    if (ctx == null) return;
    try {
      _resume(ctx);
      final buffer = ctx.callMethod<JSObject>(
        'createBuffer'.toJS,
        1.toJS,
        samples.length.toJS,
        44100.toJS,
      );
      final channel = buffer.callMethod<JSFloat32Array>(
        'getChannelData'.toJS,
        0.toJS,
      );
      channel.toDart.setAll(0, samples);

      final source = ctx.callMethod<JSObject>('createBufferSource'.toJS);
      source.setProperty('buffer'.toJS, buffer);
      final playbackRate = source['playbackRate'] as JSObject?;
      playbackRate?.setProperty('value'.toJS, rate.clamp(0.5, 2.0).toJS);
      final gain = ctx.callMethod<JSObject>('createGain'.toJS);
      final gainParam = gain['gain'] as JSObject?;
      gainParam?.setProperty('value'.toJS, volume.clamp(0.0, 1.0).toJS);
      source.callMethod<JSObject>('connect'.toJS, gain);
      gain.callMethod<JSObject>('connect'.toJS, ctx['destination'] as JSObject);
      source.callMethod<JSAny?>('start'.toJS, 0.toJS);
    } catch (_) {
      // Audio must never be able to break the toy.
    }
  }

  @override
  Future<void> dispose() async {
    try {
      _context?.callMethod<JSPromise<JSAny?>>('close'.toJS);
    } catch (_) {}
    _context = null;
    _ready = false;
  }
}
