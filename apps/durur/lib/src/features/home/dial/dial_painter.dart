import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/item.dart';
import '../../../domain/weather_symbol.dart';
import '../../../formatting/digits.dart';
import '../../../theme/app_theme.dart';
import '../../common/weather_icon.dart';
import 'dial_model.dart';

/// كثافة الأسماء في الدائرة حسب عرض الشاشة (DESIGN 7.6).
enum DialDensity {
  /// ≥ 400dp: كل الأسماء.
  full,

  /// 360–399dp: أسماء النجوم مختصرة (أول كلمة).
  medium,

  /// < 360dp: لا أسماء نجوم، والأشهر بأرقامها.
  compact,
}

/// نصوص الدائرة مُعدّة مسبقاً (TextPainter) حتى لا يُعاد تخطيطها مع كل إطار
/// أثناء السحب. تُبنى مرة لكل (سنة، منطقة، سمة، حجم خط، كثافة).
class DialLabels {
  DialLabels._(
    this.months,
    this.seasons,
    this.durur,
    this.stars,
    this.weatherIcons,
    this.heliacal,
  );

  factory DialLabels.build({
    required DialModel model,
    required Map<String, Item> items,
    required AppLocalizations l10n,
    required DururColors colors,
    required TextScaler textScaler,
    required DialDensity density,
    DigitStyle digits = DigitStyle.arabicIndic,
  }) {
    // نصوص الدائرة تتكبّر حتى 1.3× فقط (DESIGN 7.6)؛ التكبير بالإصبع بديل.
    final scaler = textScaler.clamp(maxScaleFactor: 1.3);
    TextPainter label(String text, double size, Color color) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: DururFonts.body,
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
      maxLines: 1,
    )..layout();

    String nameOf(String? id) => items[id]?.name.ar ?? '';

    return DialLabels._(
      [
        for (final m in model.months)
          label(
            density == DialDensity.compact
                ? formatInteger(m.month!, digits)
                : l10n.gregorianMonthName('g${m.month}'),
            13,
            colors.ink,
          ),
      ],
      [
        for (final s in model.segments(DialRing.seasons))
          label(nameOf(s.itemId), 13, colors.onSeason),
      ],
      [
        for (final s in model.segments(DialRing.durur))
          label(formatInteger(s.dar!.number * 10, digits), 11, colors.ink),
      ],
      [
        for (final s in model.segments(DialRing.stars))
          switch (density) {
            DialDensity.compact => null,
            DialDensity.medium => label(
              nameOf(s.itemId).split(' ').first,
              11,
              colors.ink,
            ),
            DialDensity.full => label(nameOf(s.itemId), 11, colors.ink),
          },
      ],
      [
        for (final s in model.segments(DialRing.weather))
          items[s.itemId]?.weather.firstOrNull,
      ],
      [
        for (final s in model.segments(DialRing.stars))
          items[s.itemId]?.dateMethod == DateMethod.heliacal,
      ],
    );
  }

  final List<TextPainter> months;
  final List<TextPainter> seasons;
  final List<TextPainter> durur;
  final List<TextPainter?> stars;
  final List<WeatherSymbol?> weatherIcons;

  /// النجوم المحسوبة فلكياً (سهيل والثريا): نجمة أكبر بحلقة ذهبية.
  final List<bool> heliacal;

  void dispose() {
    for (final p in [...months, ...seasons, ...durur, ...stars]) {
      p?.dispose();
    }
  }
}

/// يرسم القرص والمؤشر (DESIGN 7.2–7.3). يعيد الرسم فقط عند تغيّر [rotation]
/// (أثناء السحب) دون إعادة بناء أي عنصر واجهة.
class DialPainter extends CustomPainter {
  DialPainter({
    required this.model,
    required this.labels,
    required this.colors,
    required this.radius,
    required this.rotation,
    required this.todayDay,
  }) : super(repaint: rotation);

  final DialModel model;
  final DialLabels labels;
  final DururColors colors;
  final double radius;

  /// فهرس اليوم تحت المؤشر (كسري أثناء السحب).
  final ValueNotifier<double> rotation;

  /// فهرس «اليوم الحقيقي» في هذه السنة، أو null إن كان في سنة أخرى.
  final int? todayDay;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = DialGeometry(radius: radius, dayCount: model.dayCount);
    final rot = rotation.value;
    final selected = rot.round() % model.dayCount;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    _paintMonths(canvas, geo, rot);
    _paintSeasons(canvas, geo, rot);
    _paintDurur(canvas, geo, rot);
    _paintStars(canvas, geo, rot);
    _paintWeather(canvas, geo, rot);

    // القطع تحت المؤشر: حدّ 2dp بلون primary (تمييز ليس باللون وحده).
    final highlight = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final ring in const [
      DialRing.durur,
      DialRing.stars,
      DialRing.weather,
    ]) {
      final seg = model.segmentAt(ring, selected);
      if (seg == null) continue;
      final (outer, inner) = geo.band(ring);
      canvas.drawPath(
        _sector(
          geo.angleOf(seg.start, rot),
          geo.angleOf(seg.end, rot),
          outer - 1,
          inner + 1,
        ),
        highlight,
      );
    }

    // علامة ذهبية عند «اليوم الحقيقي» حين يُعرض تاريخ آخر (DESIGN 7.3).
    final today = todayDay;
    if (today != null && today != selected) {
      final a = geo.angleOf(today + 0.5, rot);
      final o = _polar(a, radius - geo.scale(4));
      canvas.drawCircle(o, geo.scale(4.5), Paint()..color = colors.primary);
      canvas.drawCircle(o, geo.scale(3), Paint()..color = colors.goldDeco);
    }

    // شريحة اليوم المعروض تحت الإبرة عبر كل الحلقات.
    canvas.drawPath(
      _sector(-geo.step / 2, geo.step / 2, radius, geo.hubRadius),
      Paint()..color = colors.primary.withValues(alpha: 0.10),
    );

    // المحور.
    canvas.drawCircle(
      Offset.zero,
      geo.hubRadius,
      Paint()..color = colors.surface,
    );
    canvas.drawCircle(
      Offset.zero,
      geo.hubRadius,
      Paint()
        ..color = colors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // الإبرة: خط رفيع من الحلقة الخارجية إلى المحور، ومثلث خارجها.
    canvas.drawLine(
      Offset(0, -radius),
      Offset(0, -geo.hubRadius),
      Paint()
        ..color = colors.primary
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, -radius + 2)
        ..lineTo(-6, -radius - 10)
        ..lineTo(6, -radius - 10)
        ..close(),
      Paint()..color = colors.primary,
    );
    canvas.drawCircle(
      Offset(0, -radius - 11),
      3,
      Paint()..color = colors.goldDeco,
    );

    canvas.restore();
  }

  void _paintMonths(Canvas canvas, DialGeometry geo, double rot) {
    final (outer, inner) = geo.band(DialRing.months);
    canvas.drawCircle(
      Offset.zero,
      (outer + inner) / 2,
      Paint()
        ..color = colors.surfaceAlt
        ..style = PaintingStyle.stroke
        ..strokeWidth = outer - inner,
    );
    final tick = Paint()
      ..color = colors.outline
      ..strokeWidth = 1;
    for (final (i, m) in model.months.indexed) {
      // علامة أطول أول كل شهر، وصغيرة كل 5 أيام.
      for (var d = 0; d < m.length; d += 5) {
        final a = geo.angleOf(m.start + d, rot);
        final len = d == 0 ? outer - inner : geo.scale(5);
        canvas.drawLine(_polar(a, outer), _polar(a, outer - len), tick);
      }
      _tangentialLabel(
        canvas,
        labels.months[i],
        geo.angleOf(m.start + m.length / 2, rot),
        (outer + inner) / 2,
      );
    }
  }

  void _paintSeasons(Canvas canvas, DialGeometry geo, double rot) {
    final (outer, inner) = geo.band(DialRing.seasons);
    final segs = model.segments(DialRing.seasons);
    for (final (i, s) in segs.indexed) {
      final a0 = geo.angleOf(s.start, rot);
      final a1 = geo.angleOf(s.end, rot);
      canvas.drawPath(
        _sector(a0, a1, outer, inner),
        Paint()..color = colors.season(s.colorSeasonId),
      );
      _separator(canvas, a0, outer, inner, colors.background, 2);
      if (s.length >= 12) {
        _tangentialLabel(
          canvas,
          labels.seasons[i],
          geo.angleOf(s.start + s.length / 2, rot),
          (outer + inner) / 2,
        );
      }
    }
  }

  void _paintDurur(Canvas canvas, DialGeometry geo, double rot) {
    final (outer, inner) = geo.band(DialRing.durur);
    final segs = model.segments(DialRing.durur);
    for (final (i, s) in segs.indexed) {
      final a0 = geo.angleOf(s.start, rot);
      final a1 = geo.angleOf(s.end, rot);
      canvas.drawPath(
        _sector(a0, a1, outer, inner),
        Paint()
          ..color = colors
              .season(s.colorSeasonId)
              .withValues(alpha: colors.seasonTint),
      );
      _separator(canvas, a0, outer, inner, colors.line, 1);
      if (s.length >= 5) {
        _radialLabel(
          canvas,
          labels.durur[i],
          geo.angleOf(s.start + s.length / 2, rot),
          (outer + inner) / 2,
        );
      }
    }
  }

  void _paintStars(Canvas canvas, DialGeometry geo, double rot) {
    final (outer, inner) = geo.band(DialRing.stars);
    final segs = model.segments(DialRing.stars);
    final gold = colors.starMark;
    for (final (i, s) in segs.indexed) {
      final a0 = geo.angleOf(s.start, rot);
      _separator(canvas, a0, outer, inner, colors.line, 1);
      final mid = (outer + inner) / 2;
      final big = labels.heliacal[i];
      final starCenter = _polar(a0 + geo.step * 2.5, mid);
      final r = geo.scale(big ? 7 : 5);
      if (big) {
        canvas.drawCircle(
          starCenter,
          r + 2,
          Paint()
            ..color = gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      canvas.drawPath(fourPointStar(starCenter, r), Paint()..color = gold);
      final label = labels.stars[i];
      // الاسم في القطع القصيرة يتداخل مع النجمة؛ الاسم الكامل في الورقة.
      if (label != null && s.length >= 20) {
        _tangentialLabel(
          canvas,
          label,
          geo.angleOf(s.start + s.length / 2 + 2, rot),
          mid,
        );
      }
    }
  }

  void _paintWeather(Canvas canvas, DialGeometry geo, double rot) {
    final (outer, inner) = geo.band(DialRing.weather);
    final segs = model.segments(DialRing.weather);
    for (final (i, s) in segs.indexed) {
      final color = colors.season(s.colorSeasonId);
      final a0 = geo.angleOf(s.start, rot);
      final a1 = geo.angleOf(s.end, rot);
      canvas.drawPath(
        _sector(a0, a1, outer, inner),
        Paint()..color = color.withValues(alpha: colors.seasonTint),
      );
      _dashedSector(canvas, a0, a1, outer - 0.75, inner + 0.75, color);
      final symbol = labels.weatherIcons[i];
      if (symbol != null && s.length >= 6) {
        final c = _polar(
          geo.angleOf(s.start + s.length / 2, rot),
          (outer + inner) / 2,
        );
        final size = geo.scale(16);
        canvas.save();
        canvas.translate(c.dx - size / 2, c.dy - size / 2);
        canvas.scale(size / 24);
        paintWeatherSymbol(canvas, symbol, color);
        canvas.restore();
      }
    }
  }

  /// نقطة بزاوية مع عقارب الساعة من الأعلى.
  static Offset _polar(double angle, double r) =>
      Offset(r * math.sin(angle), -r * math.cos(angle));

  static Path _sector(double a0, double a1, double outer, double inner) {
    final s0 = a0 - math.pi / 2;
    final sweep = a1 - a0;
    return Path()
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: outer),
        s0,
        sweep,
        true,
      )
      ..arcTo(
        Rect.fromCircle(center: Offset.zero, radius: inner),
        s0 + sweep,
        -sweep,
        false,
      )
      ..close();
  }

  static void _separator(
    Canvas canvas,
    double a,
    double outer,
    double inner,
    Color color,
    double width,
  ) {
    canvas.drawLine(
      _polar(a, outer),
      _polar(a, inner),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  static void _dashedSector(
    Canvas canvas,
    double a0,
    double a1,
    double outer,
    double inner,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final r in [outer, inner]) {
      final dash = 4 / r;
      final gap = 3 / r;
      for (var a = a0; a < a1; a += dash + gap) {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: r),
          a - math.pi / 2,
          math.min(dash, a1 - a),
          false,
          paint,
        );
      }
    }
    canvas.drawLine(_polar(a0, outer), _polar(a0, inner), paint);
    canvas.drawLine(_polar(a1, outer), _polar(a1, inner), paint);
  }

  /// نص على امتداد القوس، معدولاً دائماً (يُقلب في النصف السفلي).
  static void _tangentialLabel(
    Canvas canvas,
    TextPainter text,
    double angle,
    double r,
  ) {
    canvas.save();
    canvas.rotate(angle);
    canvas.translate(0, -r);
    if (math.cos(angle) < 0) canvas.rotate(math.pi);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  /// نص على امتداد نصف القطر (أرقام الدرور)، يُقرأ بلا إمالة الرأس.
  static void _radialLabel(
    Canvas canvas,
    TextPainter text,
    double angle,
    double r,
  ) {
    canvas.save();
    canvas.rotate(angle);
    canvas.translate(0, -r);
    canvas.rotate(math.sin(angle) >= 0 ? -math.pi / 2 : math.pi / 2);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(DialPainter old) =>
      old.model != model ||
      old.labels != labels ||
      old.colors != colors ||
      old.radius != radius ||
      old.todayDay != todayDay ||
      old.rotation != rotation;
}
