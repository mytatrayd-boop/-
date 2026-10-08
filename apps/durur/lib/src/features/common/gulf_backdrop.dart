import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gulf_map_data.dart';

/// زخرفة أعلى الشاشة الرئيسية (DESIGN R3.1-13): خريطة الخليج في أعلى
/// **اليمين فعلياً** (الجغرافيا لا تنعكس مع RTL)، ووردة رياح ثمانية الأطراف
/// في أعلى **اليسار فعلياً**. تحت الدائرة، تتحرك مع التمرير، ومخفية عن قارئ
/// الشاشة. الخريطة من بيانات Natural Earth (ملكية عامة)، مضمّنة مساراً ثابتاً.
class GulfBackdrop extends StatelessWidget {
  const GulfBackdrop({super.key, required this.firstScreenHeight});

  /// ارتفاع الشاشة الأولى (لموضع الوردة y 9%).
  final double firstScreenHeight;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _BackdropPainter(firstScreenHeight),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.screenHeight);

  final double screenHeight;

  static const _land = Color(0xFF0F2A38);
  static const _coast = Color(0x295FE3F0); // cyan 16%
  static const _ink = Color(0xFFEAF6FA);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    // الخريطة: عرضها 46% من الشاشة، ملتصقة بالحافتين العليا واليمنى.
    final mapW = w * 0.46;
    final mapH = mapW / gulfMapAspect;
    final origin = Offset(w - mapW, 0);
    final path = Path()..fillType = PathFillType.nonZero;
    for (final ring in gulfMapLand) {
      for (var i = 0; i + 1 < ring.length; i += 2) {
        final p = origin + Offset(ring[i] * mapW, ring[i + 1] * mapH);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    }
    canvas.save();
    canvas.clipRect(origin & Size(mapW, mapH));
    canvas.drawPath(path, Paint()..color = _land);
    canvas.drawPath(
      path,
      Paint()
        ..color = _coast
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();

    // وردة الرياح: قطرها 46% من العرض، مركزها x 14% وy 9% من الشاشة الأولى.
    final c = Offset(w * 0.14, screenHeight * 0.09);
    final r = w * 0.23;
    final line = Paint()
      ..color = _ink.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final faceA = Paint()..color = _ink.withValues(alpha: 0.05);
    final faceB = Paint()..color = _ink.withValues(alpha: 0.10);
    // ثمانية أطراف: أربعة طويلة (الجهات) وأربعة قصيرة (بينها)، ولكل طرف
    // وجهان متناوبا الشفافية.
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final len = i.isEven ? r : r * 0.62;
      final half = i.isEven ? r * 0.12 : r * 0.09;
      final tip = c + Offset.fromDirection(a, len);
      final left = c + Offset.fromDirection(a - math.pi / 2, half);
      final right = c + Offset.fromDirection(a + math.pi / 2, half);
      final p1 = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      final p2 = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(tip.dx, tip.dy)
        ..close();
      canvas.drawPath(p1, faceA);
      canvas.drawPath(p2, faceB);
      canvas.drawPath(p1, line);
      canvas.drawPath(p2, line);
    }
    canvas.drawCircle(c, r * 0.72, line);
    canvas.drawCircle(c, r * 0.4, line);
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.screenHeight != screenHeight;
}
