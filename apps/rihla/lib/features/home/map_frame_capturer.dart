import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

/// معدل التقاط الخريطة أثناء التسجيل (~2 إطار/ث، ARCHITECTURE 4.1).
const mapFrameInterval = Duration(milliseconds: 500);

/// يلتقط RepaintBoundary الخريطة كإطار RGBA بعرض [targetWidth] (نصف لوحة الفيديو).
/// يعيد null إن لم تكن الخريطة جاهزة للرسم بعد (يُعاد المحاولة في الدورة التالية).
Future<RgbaFrame?> captureMapFrame(GlobalKey key, int targetWidth) async {
  final ro = key.currentContext?.findRenderObject();
  if (ro is! RenderRepaintBoundary || !ro.hasSize || ro.size.width <= 0) {
    return null;
  }
  try {
    final image = await ro.toImage(pixelRatio: targetWidth / ro.size.width);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return null;
      return RgbaFrame(
        image.width,
        image.height,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  } catch (_) {
    // الحدود لم تُرسم بعد أو التُقطت أثناء إعادة الرسم.
    return null;
  }
}
