import 'package:flutter_test/flutter_test.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

const code = FrameCounterCode();

void main() {
  test('FrameCounterCode roundtrip', () {
    final f = RgbaFrame.filled(code.totalWidth, 32, 0, 0, 0);
    code.draw(f, 0xA5C3, x0: 0, y0: 0);
    expect(code.decode((b) => f.pixel(b * code.blockW + 20, 10).$1), 0xA5C3);
  });

  group('DualCompositor', () {
    const cam = SyntheticCameraSource();

    test('output is 16:9 with camera frame code on the left', () {
      final out = DualCompositor().compose(cam.frame(7));
      expect(out.width * 9, out.height * 16);
      expect(code.decode((b) => out.pixel(b * 40 + 20, 24).$1), 7);
    });

    test('repeats last map frame; letterboxes without cropping', () {
      final c = DualCompositor();
      final wide = RgbaFrame.filled(1000, 500, 255, 0, 255);
      c.compose(cam.frame(0), map: wide);
      final out = c.compose(cam.frame(1));
      expect(c.mapRepeats, 1);
      expect(out.pixel(640, 360), (255, 0, 255));
      expect(out.pixel(1279, 360), (255, 0, 255));
      expect(out.pixel(900, 5), isNot((255, 0, 255)));
    });
  });

  test('synthetic audio: click each second, muted is same-length silence', () {
    const a = SyntheticAudioSource();
    final s = a.samples(const Duration(seconds: 3));
    expect(s.length, 144000);
    expect(s[48000].abs(), greaterThan(20000));
    expect(s[24000], 0);
    final m = const SyntheticAudioSource(muted: true)
        .samples(const Duration(seconds: 3));
    expect(m.length, s.length);
    expect(m.every((e) => e == 0), isTrue);
    expect(a.toWav(s).length, 44 + s.length * 2);
  });
}
