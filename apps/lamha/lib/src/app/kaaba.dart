import 'package:flutter/material.dart';

/// رسم الكعبة في مربع القبلة (الميزة ٦، تصميم المالك ٣): مكعب أسود بحزام ذهبي، وتحته قاعدة.
/// الإحداثيات على مربع ١٠٠×١٠٠، مطابقة لـ res/drawable/kaaba.xml في أندرويد.
const kaabaShapes = <(int, List<Offset>)>[
  // السطح العلوي.
  (0xFF3A3A3A, [Offset(50, 8), Offset(92, 24), Offset(50, 40), Offset(8, 24)]),
  // الوجهان.
  (0xFF111111, [Offset(8, 24), Offset(50, 40), Offset(50, 80), Offset(8, 64)]),
  (0xFF1E1E1E, [Offset(50, 40), Offset(92, 24), Offset(92, 64), Offset(50, 80)]),
  // الحزام الذهبي.
  (0xFFD4A437, [Offset(8, 32), Offset(50, 48), Offset(50, 54), Offset(8, 38)]),
  (0xFFC0922C, [Offset(50, 48), Offset(92, 32), Offset(92, 38), Offset(50, 54)]),
  // الشاذروان الأبيض.
  (0xFFEEEEEE, [Offset(8, 64), Offset(50, 80), Offset(50, 85), Offset(8, 69)]),
  (0xFFDDDDDD, [Offset(50, 80), Offset(92, 64), Offset(92, 69), Offset(50, 85)]),
  // القاعدة.
  (0xFFB5532E, [Offset(6, 69), Offset(50, 85), Offset(50, 95), Offset(6, 79)]),
  (0xFF9E4426, [Offset(50, 85), Offset(94, 69), Offset(94, 79), Offset(50, 95)]),
];

class KaabaPainter extends CustomPainter {
  const KaabaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 100;
    canvas.translate(
      (size.width - 100 * k) / 2,
      (size.height - 100 * k) / 2,
    );
    for (final (color, points) in kaabaShapes) {
      final path = Path()
        ..addPolygon([for (final p in points) p * k], true);
      canvas.drawPath(path, Paint()..color = Color(color));
    }
  }

  @override
  bool shouldRepaint(KaabaPainter oldDelegate) => false;
}
