import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

/// معدل التقاط الخريطة أثناء التسجيل (~2 إطار/ث، ARCHITECTURE 4.1).
const mapFrameInterval = Duration(milliseconds: 500);

/// المنطقة المركزية من صورة [srcW]x[srcH] بنسبة [targetW]:[targetH] (تغطية
/// بالقص لا احتواء بشريطين أسودين). تعيد (x, y, عرض, ارتفاع).
({int x, int y, int w, int h}) coverCropRect(
  int srcW,
  int srcH,
  int targetW,
  int targetH,
) {
  // المصدر أعرض من الهدف: نقص الجانبين؛ وإلا نقص الأعلى والأسفل.
  final wide = srcW * targetH > srcH * targetW;
  final w = wide ? (srcH * targetW / targetH).round().clamp(1, srcW) : srcW;
  final h = wide ? srcH : (srcW * targetH / targetW).round().clamp(1, srcH);
  return (x: (srcW - w) ~/ 2, y: (srcH - h) ~/ 2, w: w, h: h);
}

/// يقص [f] إلى المنطقة المركزية بنسبة الهدف.
RgbaFrame cropToAspect(RgbaFrame f, int targetW, int targetH) {
  final r = coverCropRect(f.width, f.height, targetW, targetH);
  if (r.w == f.width && r.h == f.height) return f;
  final out = Uint8List(r.w * r.h * 4);
  for (var row = 0; row < r.h; row++) {
    final src = ((r.y + row) * f.width + r.x) * 4;
    out.setRange(row * r.w * 4, (row + 1) * r.w * 4, f.rgba, src);
  }
  return RgbaFrame(r.w, r.h, out);
}

/// يلتقط RepaintBoundary الخريطة كإطار RGBA بنسبة لوحة الخريطة في الفيديو
/// ([targetWidth]x[targetHeight]، نصف لوحة 16:9): تُغطّى اللوحة بالكامل بقص
/// مركزي فلا تظهر أشرطة سوداء. يعيد null إن لم تكن الخريطة جاهزة بعد.
Future<RgbaFrame?> captureMapFrame(
  GlobalKey key,
  int targetWidth,
  int targetHeight,
) async {
  final ro = key.currentContext?.findRenderObject();
  if (ro is! RenderRepaintBoundary || !ro.hasSize || ro.size.width <= 0) {
    return null;
  }
  try {
    // مقياس التغطية: يملأ الصورة المقصوصة (targetWidth x targetHeight) بلا تمديد.
    final scale = math.max(
      targetWidth / ro.size.width,
      targetHeight / ro.size.height,
    );
    final image = await ro.toImage(pixelRatio: scale);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return cropToAspect(
        RgbaFrame(
          image.width,
          image.height,
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        ),
        targetWidth,
        targetHeight,
      );
    } finally {
      image.dispose();
    }
  } catch (_) {
    // الحدود لم تُرسم بعد أو التُقطت أثناء إعادة الرسم.
    return null;
  }
}
