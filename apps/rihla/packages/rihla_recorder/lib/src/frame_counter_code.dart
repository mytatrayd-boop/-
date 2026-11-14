import 'rgba_frame.dart';

/// يرسم عدّاد إطار كأعمدة ثنائية كبيرة (أبيض=1) تنجو من ضغط H.264.
/// الاستخدام: التحقق من تزامن الصوت مع الصورة في الملف الناتج.
class FrameCounterCode {
  const FrameCounterCode({this.bits = 16, this.blockW = 40, this.blockH = 32});

  final int bits;
  final int blockW;
  final int blockH;

  int get totalWidth => bits * blockW;

  void draw(RgbaFrame f, int value, {required int x0, required int y0}) {
    for (var b = 0; b < bits; b++) {
      final on = (value >> (bits - 1 - b)) & 1 == 1;
      final v = on ? 255 : 0;
      f.fillRect(x0 + b * blockW, y0, blockW, blockH, v, v, v);
    }
  }

  /// يقرأ القيمة من لومينانس (0..255) لسطر/كتلة: [luma] دالة (bitIndex) => قيمة.
  int decode(int Function(int bitIndex) luma) {
    var v = 0;
    for (var b = 0; b < bits; b++) {
      v = (v << 1) | (luma(b) > 127 ? 1 : 0);
    }
    return v;
  }
}
