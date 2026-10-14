import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// ألوان الأغلفة (DESIGN §4.6). المعرّفات غير المعروفة تأخذ لوناً ثابتاً من
/// القائمة نفسها حسب معرّفها.
const coverColors = <String, Color>{
  'bayan': Color(0xFF1E5B4F),
  'kamil': Color(0xFF6B2E1F),
  'uyun': Color(0xFF203A5C),
  'kalila': Color(0xFF5A4A12),
  'adab': Color(0xFF3D2B4F),
};

Color coverColorFor(String bookId) {
  final known = coverColors[bookId];
  if (known != null) return known;
  final palette = coverColors.values.toList();
  final hash = bookId.codeUnits.fold<int>(
    0,
    (h, c) => (h * 31 + c) & 0x7fffffff,
  );
  return palette[hash % palette.length];
}

/// غلاف مرسوم 3:4: لون الكتاب، ونقش نجمة ثمانية متكرر بذهبي شفاف، والعنوان
/// بخط أميري بلون عاجي داخل إطار. زخرفي فقط: مستبعد من قارئ الشاشة.
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({
    super.key,
    required this.bookId,
    required this.title,
    required this.width,
  });

  final String bookId;
  final String title;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 4 / 3;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width / 12),
        child: SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _StarPatternPainter(coverColorFor(bookId)),
            child: Padding(
              padding: EdgeInsets.all(width * 0.1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: AdeebColors.goldOrnament, width: 1),
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(width * 0.05),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      overflow: TextOverflow.fade,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: bookFont,
                        color: AdeebColors.coverTitle,
                        fontSize: width * 0.14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarPatternPainter extends CustomPainter {
  _StarPatternPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final stroke = Paint()
      ..color = AdeebColors.goldOrnament.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, size.width / 120);
    final cell = size.width / 3;
    final r = cell * 0.42;
    for (var y = cell / 2; y < size.height + cell; y += cell) {
      for (var x = cell / 2; x < size.width + cell; x += cell) {
        final c = Offset(x, y);
        // نجمة ثمانية = مربعان متداخلان أحدهما مدار 45°.
        for (final rot in [0.0, math.pi / 4]) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = rot + i * math.pi / 2 + math.pi / 4;
            final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
            i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
          }
          path.close();
          canvas.drawPath(path, stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_StarPatternPainter old) => old.color != color;
}
