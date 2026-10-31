import 'package:flutter/painting.dart';

/// أكبر حجم خط بين [max] و[min] (خطوة 2) يتسع فيه [text] في سطر واحد ضمن [maxWidth].
/// إن لم يتسع عند [min] يعيد [min] (ويُقصّ النص بنقاط عند العرض).
double fitFontSize({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double max,
  required double min,
  TextDirection textDirection = TextDirection.rtl,
}) {
  var size = max;
  while (size > min) {
    final p = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: size)),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final fits = p.width <= maxWidth;
    p.dispose();
    if (fits) return size;
    size -= 2;
  }
  return min;
}

/// هل في النص حروف عربية (لتحديد اتجاه الاسم).
bool containsArabic(String s) => RegExp(r'[؀-ۿݐ-ݿ]').hasMatch(s);
