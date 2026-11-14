import 'dart:typed_data';

import 'frame_counter_code.dart';
import 'rgba_frame.dart';

/// كاميرا اصطناعية حتمية: تدرّج لوني يتغيّر مع الإطار + عدّاد إطار في الأعلى.
/// العدّاد داخل المنطقة المركزية (عرض 640 من 1280) فلا يُقصّ بالقص المركزي.
class SyntheticCameraSource {
  const SyntheticCameraSource({
    this.width = 1280,
    this.height = 720,
    this.fps = 30,
    this.code = const FrameCounterCode(),
  });

  final int width;
  final int height;
  final int fps;
  final FrameCounterCode code;

  RgbaFrame frame(int index) {
    final f = RgbaFrame(width, height, Uint8List(width * height * 4), timestamp: _ts(index));
    for (var y = 0; y < height; y += 1) {
      final r = (index * 4) & 255;
      final g = (y * 255 ~/ height);
      for (var x = 0; x < width; x += 1) {
        final i = (y * width + x) * 4;
        f.rgba[i] = r;
        f.rgba[i + 1] = g;
        f.rgba[i + 2] = (x * 255 ~/ width);
        f.rgba[i + 3] = 255;
      }
    }
    final x0 = (width - code.totalWidth) ~/ 2;
    code.draw(f, index, x0: x0, y0: 8);
    return f;
  }

  Duration _ts(int index) =>
      Duration(microseconds: index * 1000000 ~/ fps);
}
