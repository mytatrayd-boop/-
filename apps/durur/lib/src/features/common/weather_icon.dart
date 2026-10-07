import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/weather_symbol.dart';

/// اسم رمز الجو بالعربية (للشرائح وقارئ الشاشة، D23).
String weatherSymbolLabel(AppLocalizations l10n, WeatherSymbol s) =>
    l10n.weatherSymbolName(s.code);

/// أيقونة جو خطية من رسمنا (DESIGN §6): شبكة 24، خط 2، أطراف مستديرة،
/// لون واحد. لا تنعكس في RTL. معناها يُقرأ من الكلمة المرافقة، فهي مخفية
/// عن قارئ الشاشة.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon(this.symbol, {super.key, this.size = 20, this.color});

  final WeatherSymbol symbol;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: WeatherIconPainter(symbol, c),
      ),
    );
  }
}

/// يرسم رمز الجو في مربع بأي حجم (يُستخدم أيضاً داخل الدائرة).
class WeatherIconPainter extends CustomPainter {
  const WeatherIconPainter(this.symbol, this.color);

  final WeatherSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    paintWeatherSymbol(canvas, symbol, color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(WeatherIconPainter old) =>
      old.symbol != symbol || old.color != color;
}

/// يرسم [symbol] على شبكة 24×24 بلا تحجيم. [strokeWidth] بوحدات الشبكة.
void paintWeatherSymbol(
  Canvas canvas,
  WeatherSymbol symbol,
  Color color, {
  double strokeWidth = 2,
}) {
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final tint = Paint()..color = color.withValues(alpha: 0.2);
  final dot = Paint()..color = color;

  void line(double x1, double y1, double x2, double y2) =>
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);

  void sun(Offset c, double r, double ray, int rays, {bool fill = false}) {
    if (fill) canvas.drawCircle(c, r, tint);
    canvas.drawCircle(c, r, stroke);
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * math.pi / rays;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * (r + 2), c + d * (r + 2 + ray), stroke);
    }
  }

  Path cloud(double dy) => Path()
    ..moveTo(6, 15 + dy)
    ..arcToPoint(Offset(7.5, 9.5 + dy), radius: const Radius.circular(3))
    ..arcToPoint(Offset(16, 8.5 + dy), radius: const Radius.circular(4.5))
    ..arcToPoint(Offset(18, 15 + dy), radius: const Radius.circular(3.3))
    ..close();

  void thermometer(double level) {
    final body = RRect.fromLTRBR(7, 3, 11, 15, const Radius.circular(2));
    canvas.drawRRect(body, stroke);
    canvas.drawCircle(const Offset(9, 18), 3, stroke);
    line(9, 18, 9, level);
  }

  void flake(Offset c, double r) {
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3 + math.pi / 2;
      final d = Offset(math.cos(a), math.sin(a)) * r;
      canvas.drawLine(c - d, c + d, stroke);
    }
  }

  void wave(double y, double amp, double x1, double x2) {
    final p = Path()..moveTo(x1, y);
    final w = (x2 - x1) / 4;
    for (var i = 0; i < 4; i++) {
      final x = x1 + i * w;
      p.quadraticBezierTo(x + w / 2, y + (i.isEven ? -amp : amp), x + w, y);
    }
    canvas.drawPath(p, stroke);
  }

  void windLine(double y, double x1, double x2) {
    // الرياح تتجه من اليمين لليسار بصرياً، والطرف الملتف على اليسار.
    line(x2, y, x1 + 2, y);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(x1 + 2, y - 2), radius: 2),
      math.pi / 2,
      math.pi * 1.5,
      false,
      stroke,
    );
  }

  switch (symbol) {
    case WeatherSymbol.hot:
      sun(const Offset(12, 12), 4, 3, 8);
    case WeatherSymbol.veryHot:
      sun(const Offset(12, 10), 4, 3.5, 8, fill: true);
      wave(20.5, 1.2, 6, 18);
    case WeatherSymbol.mild:
      line(3, 17, 21, 17);
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(12, 17), radius: 5),
        math.pi,
        math.pi,
        false,
        stroke,
      );
      line(12, 9, 12, 6.5);
      line(6.5, 11.5, 5, 10);
      line(17.5, 11.5, 19, 10);
    case WeatherSymbol.cool:
      thermometer(12);
      canvas.drawCircle(const Offset(17, 8), 1.2, dot);
    case WeatherSymbol.cold:
      thermometer(16);
      flake(const Offset(17, 8), 3.5);
    case WeatherSymbol.veryCold:
      thermometer(16);
      flake(const Offset(17, 6.5), 3);
      flake(const Offset(18, 15), 2);
    case WeatherSymbol.wind:
      windLine(7, 5, 20);
      windLine(12, 3, 21);
      windLine(17, 6, 18);
    case WeatherSymbol.windStrong:
      windLine(6, 3, 21);
      windLine(10.5, 2, 22);
      windLine(15, 4, 21);
      line(14, 21, 18, 18);
    case WeatherSymbol.rain:
      canvas.drawPath(cloud(-2), stroke);
      for (final x in [8.0, 12.0, 16.0]) {
        line(x, 16.5, x - 1.5, 20.5);
      }
    case WeatherSymbol.heavyRain:
      canvas.drawPath(cloud(-3), stroke);
      for (final x in [6.0, 9.0, 12.0, 15.0, 18.0]) {
        line(x, 15, x - 2, 21.5);
      }
    case WeatherSymbol.thunder:
      canvas.drawPath(cloud(-3), stroke);
      canvas.drawPath(
        Path()
          ..moveTo(13, 14)
          ..lineTo(10.5, 18)
          ..lineTo(13.5, 18)
          ..lineTo(11, 22),
        stroke,
      );
    case WeatherSymbol.cloud:
      canvas.save();
      canvas.translate(-2, -3);
      canvas.scale(0.8);
      canvas.drawPath(cloud(0), stroke);
      canvas.restore();
      canvas.drawPath(cloud(3), stroke);
    case WeatherSymbol.dust:
      wave(7, 1, 4, 18);
      wave(12, 1, 3, 21);
      wave(17, 1, 6, 16);
      for (final o in const [
        Offset(20, 7),
        Offset(5, 14.5),
        Offset(19, 17),
        Offset(13, 20.5),
      ]) {
        canvas.drawCircle(o, 1, dot);
      }
    case WeatherSymbol.humidity:
      canvas.drawPath(
        Path()
          ..moveTo(12, 3)
          ..quadraticBezierTo(19, 11, 18, 15)
          ..arcToPoint(const Offset(6, 15), radius: const Radius.circular(6))
          ..quadraticBezierTo(5, 11, 12, 3)
          ..close(),
        stroke,
      );
      wave(14, 0.8, 9, 15);
      wave(17, 0.8, 10, 14);
    case WeatherSymbol.fog:
      for (final (y, x1, x2) in const [
        (6.0, 4.0, 14.0),
        (10.0, 8.0, 20.0),
        (14.0, 4.0, 16.0),
        (18.0, 9.0, 20.0),
      ]) {
        line(x1, y, x2, y);
      }
      line(17, 6, 20, 6);
      line(4, 10, 5, 10);
      line(19, 14, 20, 14);
      line(4, 18, 6, 18);
    case WeatherSymbol.seaCalm:
      wave(10, 1.2, 3, 21);
      wave(15, 1.2, 3, 21);
    case WeatherSymbol.seaRough:
      for (final y in [11.0, 19.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(2, y)
            ..quadraticBezierTo(6, y, 8, y - 5)
            ..arcToPoint(Offset(11, y - 4.5), radius: const Radius.circular(2))
            ..quadraticBezierTo(12, y, 22, y),
          stroke,
        );
      }
  }
}

/// نجمة رباعية الأطراف (أيقونة واجهة: النجوم وطلوع سهيل/الثريا، DESIGN §6).
Path fourPointStar(Offset c, double r) {
  final inner = r * 0.32;
  final p = Path();
  for (var i = 0; i < 8; i++) {
    final a = -math.pi / 2 + i * math.pi / 4;
    final rr = i.isEven ? r : inner;
    final o = c + Offset(math.cos(a), math.sin(a)) * rr;
    if (i == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  return p..close();
}
