import 'package:rihla_recorder/rihla_recorder.dart';

import 'map_frame_source.dart';

/// مصدر خريطة مزيّف حتمي بلا شبكة ولا مفتاح: شبكة + عدّاد إطار (ثنائي) + خط
/// مسار يتقدّم + مستطيل أرجواني في أسفل اليسار يمثّل شعار/إسناد جوجل (لاختبار
/// أنه لا يُقصّ ولا يُغطّى).
class FakeMapFrameSource implements MapFrameSource {
  FakeMapFrameSource({
    this.width = 640,
    this.height = 720,
    this.fps = 2,
    this.count = 10,
    List<(double, double)>? track,
  }) : track = track ?? defaultTrack();

  final int width;
  final int height;
  final int fps;
  final int count;
  final List<(double lat, double lng)> track;

  static const code = FrameCounterCode(bits: 8, blockW: 40, blockH: 32);
  static const attributionX = 8;
  static const attributionW = 80;
  static const attributionH = 20;
  static const attributionColor = (255, 0, 255);

  int get attributionY => height - attributionH - 8;

  /// مسار اصطناعي ثابت (بدل ملف GPS مسجَّل).
  static List<(double, double)> defaultTrack() => [
    for (var i = 0; i < 40; i++)
      (24.7 + i * 0.001, 46.6 + 0.01 * (i / 10) * ((i % 8) / 8) + i * 0.0008),
  ];

  @override
  Stream<MapFrame> frames() => Stream.fromIterable(generate());

  Iterable<MapFrame> generate() sync* {
    for (var i = 0; i < count; i++) {
      yield frame(i);
    }
  }

  MapFrame frame(int index) {
    final f = RgbaFrame.filled(
      width,
      height,
      221,
      221,
      221,
      timestamp: Duration(microseconds: index * 1000000 ~/ fps),
    );
    for (var x = 0; x < width; x += 80) {
      f.fillRect(x, 0, 2, height, 170, 170, 170);
    }
    for (var y = 0; y < height; y += 80) {
      f.fillRect(0, y, width, 2, 170, 170, 170);
    }
    _drawTrack(f, index);
    code.draw(f, index, x0: 0, y0: 8);
    final (r, g, b) = attributionColor;
    f.fillRect(attributionX, attributionY, attributionW, attributionH, r, g, b);
    return f;
  }

  void _drawTrack(RgbaFrame f, int index) {
    final lats = track.map((p) => p.$1), lngs = track.map((p) => p.$2);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);
    final spanLat = (maxLat - minLat) == 0 ? 1 : maxLat - minLat;
    final spanLng = (maxLng - minLng) == 0 ? 1 : maxLng - minLng;
    (int, int) project(int i) => (
      60 + ((track[i].$2 - minLng) / spanLng * (width - 120)).round(),
      100 + ((maxLat - track[i].$1) / spanLat * (height - 220)).round(),
    );
    final upto = ((index + 1) * track.length ~/ count).clamp(2, track.length);
    for (var i = 1; i < upto; i++) {
      final (x0, y0) = project(i - 1);
      final (x1, y1) = project(i);
      _line(f, x0, y0, x1, y1);
    }
  }

  void _line(RgbaFrame f, int x0, int y0, int x1, int y1) {
    final steps = [
      (x1 - x0).abs(),
      (y1 - y0).abs(),
    ].reduce((a, b) => a > b ? a : b);
    for (var s = 0; s <= steps; s++) {
      final t = steps == 0 ? 0.0 : s / steps;
      final x = (x0 + (x1 - x0) * t).round();
      final y = (y0 + (y1 - y0) * t).round();
      f.fillRect(x - 1, y - 1, 3, 3, 245, 165, 36);
    }
  }
}
