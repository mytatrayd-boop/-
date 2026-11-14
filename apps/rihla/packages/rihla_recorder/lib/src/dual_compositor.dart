import 'dart:typed_data';

import 'rgba_frame.dart';

/// يركّب لوحة 16:9: الكاميرا (قص مركزي) في جهة، وآخر إطار خريطة في الجهة الأخرى.
/// الخريطة تُحجَّم بنمط "contain" دون أي قص كي يبقى شعار جوجل والإسناد ظاهرين.
/// إن لم يصل إطار خريطة جديد يُكرَّر آخر إطار.
class DualCompositor {
  DualCompositor({this.width = 1280, this.height = 720, this.mapOnRight = false})
      : assert(width.isEven && height.isEven);

  final int width;
  final int height;

  /// الافتراضي حسب D16: الفيديو يطابق الشاشة (خريطة يسار، كاميرا يمين).
  final bool mapOnRight;

  RgbaFrame? _lastMap;
  int _mapRepeats = 0;

  /// عدد مرات تكرار آخر إطار خريطة منذ آخر إطار جديد.
  int get mapRepeats => _mapRepeats;

  int get halfWidth => width ~/ 2;

  RgbaFrame compose(RgbaFrame camera, {RgbaFrame? map, Duration? timestamp}) {
    if (map != null) {
      _lastMap = map;
      _mapRepeats = 0;
    } else if (_lastMap != null) {
      _mapRepeats++;
    }
    final out = RgbaFrame(width, height, Uint8List(width * height * 4),
        timestamp: timestamp ?? camera.timestamp);
    out.fillRect(0, 0, width, height, 14, 19, 22);
    final camX = mapOnRight ? 0 : halfWidth;
    final mapX = mapOnRight ? halfWidth : 0;
    _blitCover(camera, out, camX, 0, halfWidth, height);
    final m = _lastMap;
    if (m != null) _blitContain(m, out, mapX, 0, halfWidth, height);
    return out;
  }

  /// تعبئة تغطي المستطيل مع قص مركزي (للكاميرا).
  void _blitCover(RgbaFrame s, RgbaFrame d, int dx, int dy, int dw, int dh) {
    final scale = _max(dw / s.width, dh / s.height);
    final cw = (dw / scale).round();
    final ch = (dh / scale).round();
    final sx0 = (s.width - cw) ~/ 2;
    final sy0 = (s.height - ch) ~/ 2;
    for (var y = 0; y < dh; y++) {
      final sy = (sy0 + y / scale).floor().clamp(0, s.height - 1);
      for (var x = 0; x < dw; x++) {
        final sx = (sx0 + x / scale).floor().clamp(0, s.width - 1);
        _copy(s, sx, sy, d, dx + x, dy + y);
      }
    }
  }

  /// احتواء كامل بلا قص (للخريطة).
  void _blitContain(RgbaFrame s, RgbaFrame d, int dx, int dy, int dw, int dh) {
    final scale = _min(dw / s.width, dh / s.height);
    final tw = (s.width * scale).round();
    final th = (s.height * scale).round();
    final ox = dx + (dw - tw) ~/ 2;
    final oy = dy + (dh - th) ~/ 2;
    for (var y = 0; y < th; y++) {
      final sy = (y / scale).floor().clamp(0, s.height - 1);
      for (var x = 0; x < tw; x++) {
        final sx = (x / scale).floor().clamp(0, s.width - 1);
        _copy(s, sx, sy, d, ox + x, oy + y);
      }
    }
  }

  void _copy(RgbaFrame s, int sx, int sy, RgbaFrame d, int x, int y) {
    final si = (sy * s.width + sx) * 4;
    final di = (y * d.width + x) * 4;
    d.rgba[di] = s.rgba[si];
    d.rgba[di + 1] = s.rgba[si + 1];
    d.rgba[di + 2] = s.rgba[si + 2];
    d.rgba[di + 3] = 255;
  }

  double _max(double a, double b) => a > b ? a : b;
  double _min(double a, double b) => a < b ? a : b;
}
