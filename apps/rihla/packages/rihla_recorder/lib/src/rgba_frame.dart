import 'dart:typed_data';

/// إطار RGBA خام (4 بايت لكل بكسل) مع طابع زمني بساعة التسجيل.
class RgbaFrame {
  RgbaFrame(this.width, this.height, this.rgba, {this.timestamp = Duration.zero})
      : assert(rgba.length == width * height * 4);

  factory RgbaFrame.filled(int width, int height, int r, int g, int b,
      {Duration timestamp = Duration.zero}) {
    final f = RgbaFrame(width, height, Uint8List(width * height * 4),
        timestamp: timestamp);
    f.fillRect(0, 0, width, height, r, g, b);
    return f;
  }

  final int width;
  final int height;
  final Uint8List rgba;
  final Duration timestamp;

  void setPixel(int x, int y, int r, int g, int b) {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    final i = (y * width + x) * 4;
    rgba[i] = r;
    rgba[i + 1] = g;
    rgba[i + 2] = b;
    rgba[i + 3] = 255;
  }

  (int, int, int) pixel(int x, int y) {
    final i = (y * width + x) * 4;
    return (rgba[i], rgba[i + 1], rgba[i + 2]);
  }

  void fillRect(int x0, int y0, int w, int h, int r, int g, int b) {
    for (var y = y0; y < y0 + h; y++) {
      for (var x = x0; x < x0 + w; x++) {
        setPixel(x, y, r, g, b);
      }
    }
  }
}
