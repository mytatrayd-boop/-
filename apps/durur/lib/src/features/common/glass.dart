import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// سطح زجاجي (DESIGN R2.3): تعبئة تدرّج رأسي `#7FE9F3` من 10% إلى 4%، حد
/// 1dp `glass-stroke`، وخط لمعة داخلي أبيض 12% على الحافة العليا. ضبابية
/// الخلفية ([blur]) للبطاقات فقط، بحد أقصى 6 أسطح ظاهرة معاً.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsetsDirectional.all(16),
    this.blur = false,
    this.borderColor,
    this.onTap,
    this.fill,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// ضبابية الخلفية sigma 12 (`BackdropFilter`).
  final bool blur;

  /// حد مختلف (مثل `cyan` 50% للعدّاد)، وإلا `glass-stroke`.
  final Color? borderColor;

  /// تعبئة مصمتة بدل التدرّج (مثل الحبة المختارة).
  final Color? fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    final shape = BorderRadius.circular(radius);
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: shape,
          splashColor: colors.primary.withValues(alpha: 0.12),
          highlightColor: colors.primary.withValues(alpha: 0.06),
          child: content,
        ),
      );
    }
    Widget surface = CustomPaint(
      painter: _GlassFill(radius, fill),
      foregroundPainter: _GlassEdge(
        radius,
        borderColor ?? colors.glassStroke,
      ),
      child: content,
    );
    if (blur) {
      surface = BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: surface,
      );
    }
    return ClipRRect(borderRadius: shape, child: surface);
  }
}

class _GlassFill extends CustomPainter {
  const _GlassFill(this.radius, this.fill);

  final double radius;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint();
    if (fill != null) {
      paint.color = fill!;
    } else {
      paint.shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        const [Color(0x1A7FE9F3), Color(0x0A7FE9F3)],
      );
    }
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_GlassFill old) =>
      old.radius != radius || old.fill != fill;
}

class _GlassEdge extends CustomPainter {
  const _GlassEdge(this.radius, this.border);

  final double radius;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // خط اللمعة الداخلي على الحافة العليا.
    final inset = radius.clamp(0, size.width / 2).toDouble();
    canvas.drawLine(
      Offset(inset, 1.5),
      Offset(size.width - inset, 1.5),
      Paint()
        ..color = const Color(0x1FFFFFFF)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_GlassEdge old) =>
      old.radius != radius || old.border != border;
}

/// خلفية سماء الليل (DESIGN R2.1): تدرّج كحلي أفتح خلف الدائرة (حتى `bg-glow`)
/// وأغمق في الأسفل، ووردة رياح ثمانية الأطراف من صنعنا بشفافية 6%. زخرفة
/// ثابتة مخفية عن قارئ الشاشة.
class NightSky extends StatelessWidget {
  const NightSky({super.key, this.glowCenter = 0.3, this.rose = true});

  /// موضع أفتح نقطة رأسياً (نسبة من الارتفاع).
  final double glowCenter;
  final bool rose;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _NightSkyPainter(DururColors.of(context), glowCenter, rose),
        size: Size.infinite,
      ),
    );
  }
}

class _NightSkyPainter extends CustomPainter {
  const _NightSkyPainter(this.colors, this.glowCenter, this.rose);

  final DururColors colors;
  final double glowCenter;
  final bool rose;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          rect.topCenter,
          rect.bottomCenter,
          [colors.background, colors.backgroundDeep],
        ),
    );
    final center = Offset(size.width / 2, size.height * glowCenter);
    final r = size.width * 0.75;
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(center, r, [
          colors.backgroundGlow,
          colors.backgroundGlow.withValues(alpha: 0.5),
          colors.background.withValues(alpha: 0),
        ], const [0, 0.35, 1]),
    );
    if (!rose) return;
    // وردة الرياح أعلى يمين الدائرة.
    final c = Offset(size.width * 0.84, size.height * 0.14);
    final fill = Paint()..color = colors.primary.withValues(alpha: 0.06);
    final line = Paint()
      ..color = colors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    Path star(double long, double short, double turn) {
      final p = Path();
      for (var i = 0; i < 8; i++) {
        final a = turn + i * 3.141592653589793 / 4;
        final len = i.isEven ? long : short;
        final pt = c + Offset.fromDirection(a, len);
        if (i == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      return p..close();
    }

    for (final p in [star(58, 6, -1.5707963), star(34, 4, -0.785398)]) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, line);
    }
    canvas.drawCircle(c, 40, line);
  }

  @override
  bool shouldRepaint(_NightSkyPainter old) =>
      old.colors != colors ||
      old.glowCenter != glowCenter ||
      old.rose != rose;
}
