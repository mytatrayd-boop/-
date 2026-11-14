import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/features/home/map_frame_capturer.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

/// ملاحظة 5: لوحة الخريطة في الفيديو 640x720 (8:9)؛ الإطار يغطيها بلا أشرطة.
void main() {
  test('مصدر أطول من الهدف: يُقص الأعلى والأسفل ويُملأ العرض', () {
    final r = coverCropRect(600, 1200, 640, 720);
    expect(r.w, 600);
    expect(r.h, 675); // 600 * 720 / 640
    expect(r.x, 0);
    expect(r.y, (1200 - 675) ~/ 2);
  });

  test('مصدر أعرض من الهدف: يُقص الجانبان', () {
    final r = coverCropRect(1000, 500, 640, 720);
    expect(r.h, 500);
    expect(r.w, 444); // 500 * 640 / 720
    expect(r.y, 0);
    expect(r.x, (1000 - 444) ~/ 2);
  });

  test('بنفس النسبة: لا قص', () {
    final r = coverCropRect(640, 720, 640, 720);
    expect((r.x, r.y, r.w, r.h), (0, 0, 640, 720));
  });

  test('cropToAspect: النتيجة بنسبة الهدف وتحتفظ بالمنتصف', () {
    // 4x8: صفوف بلون = رقم الصف. الهدف 1:1 -> 4x4 من الصفوف 2..5.
    final data = Uint8List(4 * 8 * 4);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 4; x++) {
        data[(y * 4 + x) * 4] = y;
      }
    }
    final out = cropToAspect(RgbaFrame(4, 8, data), 640, 640);
    expect((out.width, out.height), (4, 4));
    expect(out.rgba[0], 2);
    expect(out.rgba[(3 * 4) * 4], 5);
    expect(out.rgba.length, 4 * 4 * 4);
  });

  test('نسبة الإطار الناتج تطابق لوحة الخريطة لكل جودة', () {
    for (final q in RecorderQuality.values) {
      final src = RgbaFrame(540, 1100, Uint8List(540 * 1100 * 4));
      final out = cropToAspect(src, q.mapWidth, q.height);
      expect(out.width / out.height, closeTo(q.mapWidth / q.height, 0.01));
    }
  });
}
