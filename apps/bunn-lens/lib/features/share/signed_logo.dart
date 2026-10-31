import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fit_text.dart';

/// حبر اللوقو (أغمق لون في logo-mark.png، نحو #111).
const logoInk = Color(0xFF111111);
const signatureFontFamily = 'ArefRuqaa';

/// اللوقو الموقَّع: logo-mark.png (210px) واسم المستخدم بخط يد تحت الحبة بتباعد واضح
/// وميلان -6° وخط امتداد رفيع كذيل التوقيع يبدأ بعد آخر حرف بفراغ ولا يلامسه. العلامة 320×224.
class SignedLogo extends StatelessWidget {
  const SignedLogo({super.key, required this.logo, required this.name});

  static const double width = 320;
  static const double height = 224;
  static const double markWidth = 210;
  static const double gap = 6;
  static const double nameMax = 68;
  static const double nameMin = 36;
  static const double tailGap = 14;
  static const double tailMaxLength = 90;
  static const double tailMinLength = 24;

  final ui.Image logo;
  final String name;

  @override
  Widget build(BuildContext context) {
    final markHeight = markWidth * logo.height / logo.width;
    final top = markHeight + gap;
    final dir = containsArabic(name) ? TextDirection.rtl : TextDirection.ltr;
    const base = TextStyle(fontFamily: signatureFontFamily, color: logoInk, height: 1.1);
    final size = fitFontSize(
        text: name, style: base, maxWidth: width, max: nameMax, min: nameMin, textDirection: dir);
    final style = base.copyWith(fontSize: size);
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: dir,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width);
    final textWidth = painter.width;
    painter.dispose();
    final boxHeight = height - top;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (width - markWidth) / 2,
            top: 0,
            width: markWidth,
            height: markHeight,
            child: RawImage(image: logo, fit: BoxFit.fill, filterQuality: FilterQuality.high),
          ),
          Positioned(
            left: 0,
            top: top,
            width: width,
            height: boxHeight,
            child: Transform.rotate(
              angle: -6 * math.pi / 180,
              child: CustomPaint(
                painter: _TailPainter(textWidth: textWidth, rtl: dir == TextDirection.rtl),
                child: Center(
                  child: Directionality(
                    textDirection: dir,
                    child: Text(name,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        textScaler: TextScaler.noScaling),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// طول ذيل التوقيع لاسم بعرض [textWidth]: يبدأ بعد الاسم بـ[tailGap] ويقصر بقدر المتاح
  /// داخل العلامة (حتى [tailMaxLength])، و0 (بلا ذيل) إن لم يبقَ مكان لا يلامس الحروف.
  static double tailLength(double textWidth) {
    final room = (width - math.min(textWidth, width)) / 2 - tailGap;
    if (room < tailMinLength) return 0;
    return math.min(room, tailMaxLength);
  }
}

/// خط الامتداد: يبدأ بعد آخر حرف بفراغ [SignedLogo.tailGap] (يسار الاسم العربي، يمين اللاتيني)
/// ويمتد عكس اتجاه الكتابة بانحناءة طفيفة للأعلى، على مستوى أسفل الحروف.
class _TailPainter extends CustomPainter {
  _TailPainter({required this.textWidth, required this.rtl});
  final double textWidth;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final len = SignedLogo.tailLength(textWidth);
    if (len == 0) return;
    final w = math.min(textWidth, size.width);
    final y = size.height * 0.62;
    final edge = rtl ? (size.width - w) / 2 : (size.width + w) / 2;
    final startX = rtl ? edge - SignedLogo.tailGap : edge + SignedLogo.tailGap;
    final dx = rtl ? -len : len;
    final path = Path()
      ..moveTo(startX, y)
      ..quadraticBezierTo(startX + dx * 0.5, y + 3, startX + dx, y - 6);
    canvas.drawPath(
      path,
      Paint()
        ..color = logoInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.textWidth != textWidth || old.rtl != rtl;
}
