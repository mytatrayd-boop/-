import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'fit_text.dart';

/// حبر اللوقو (أغمق لون في logo-mark.png، نحو #111).
const logoInk = Color(0xFF111111);
const signatureFontFamily = 'ArefRuqaa';

/// اللوقو الموقَّع: logo-mark.png (200px) واسم المستخدم بخط يد تحت الحبة بتداخل 12px
/// وميلان -6° وخط امتداد رفيع كذيل التوقيع. العلامة كلها 280×174.
class SignedLogo extends StatelessWidget {
  const SignedLogo({super.key, required this.logo, required this.name});

  static const double width = 280;
  static const double height = 174;
  static const double markWidth = 200;
  static const double overlap = 12;

  final ui.Image logo;
  final String name;

  @override
  Widget build(BuildContext context) {
    final markHeight = markWidth * logo.height / logo.width;
    final top = markHeight - overlap;
    final dir = containsArabic(name) ? TextDirection.rtl : TextDirection.ltr;
    const base = TextStyle(fontFamily: signatureFontFamily, color: logoInk, height: 1.1);
    final size = fitFontSize(
        text: name, style: base, maxWidth: width, max: 52, min: 36, textDirection: dir);
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
}

/// خط الامتداد: يبدأ من آخر حرف (يسار الاسم العربي، يمين اللاتيني) ويمتد عكس اتجاه الكتابة
/// بطول 50% من عرض الاسم بانحناءة طفيفة للأعلى.
class _TailPainter extends CustomPainter {
  _TailPainter({required this.textWidth, required this.rtl});
  final double textWidth;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.min(textWidth, size.width);
    final len = w * 0.5;
    final y = size.height - 4;
    final startX = rtl ? (size.width - w) / 2 : (size.width + w) / 2;
    final dx = rtl ? len : -len;
    final path = Path()
      ..moveTo(startX, y)
      ..quadraticBezierTo(startX + dx * 0.5, y + 2, startX + dx, y - 5);
    canvas.drawPath(
      path,
      Paint()
        ..color = logoInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.textWidth != textWidth || old.rtl != rtl;
}
