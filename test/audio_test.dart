import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_cube_3d/src/audio.dart';

void main() {
  test('every procedural sound is a finite bounded PCM buffer', () {
    for (final sfx in JellySfx.values) {
      final pcm = JellySynth.render(sfx);
      expect(pcm.length, greaterThan(1000), reason: sfx.name);
      var peak = 0.0;
      for (final sample in pcm) {
        expect(sample.isFinite, isTrue, reason: sfx.name);
        if (sample.abs() > peak) peak = sample.abs();
      }
      expect(peak, lessThanOrEqualTo(1.0), reason: sfx.name);
      expect(peak, greaterThan(0.05), reason: sfx.name);
    }
  });
}
