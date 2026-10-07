import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../domain/item.dart';
import '../../../formatting/digits.dart';
import '../../../theme/app_theme.dart';
import '../../common/weather_icon.dart';
import 'dial_model.dart';
import 'weather_marks.dart';

/// كثافة الأسماء في الدائرة حسب عرض الشاشة (DESIGN R2.10).
enum DialDensity {
  /// ≥ 400dp: الأشهر بخط 15، ورموز الجو 18.
  full,

  /// 360–399dp: الأشهر بخط 13، ورموز الجو 16.
  medium,

  /// < 360dp: الأشهر بأرقامها، والطوالع بلا أسماء (7.6).
  compact,
}

/// التكبير الذي تظهر عنده أسماء الدرور وتدريج كل يوم وأرقام ١٠/٢٠/٣٠.
const double dialDetailZoom = 1.6;

/// التكبير الذي تظهر عنده كل أسماء الطوالع.
const double dialAllStarsZoom = 2;

/// نصوص الدائرة مُعدّة مسبقاً (TextPainter) حتى لا يُعاد تخطيطها مع كل إطار
/// أثناء السحب. تُبنى مرة لكل (سنة، منطقة، حجم خط، كثافة، أرقام).
class DialLabels {
  DialLabels._({
    required this.months,
    required this.monthDays,
    required this.dururNumbers,
    required this.dururNames,
    required this.stars,
    required this.heliacal,
    required this.weatherNames,
    required this.seasonNames,
  });

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
    TextPainter label(
      String text,
      double size,
      Color color, {
      FontWeight weight = FontWeight.w700,
      bool glow = false,
    }) => TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: DururFonts.body,
          fontSize: size,
          fontWeight: weight, // Almarai بلا 500/600 (DESIGN §3)
          color: color,
          height: 1.2,
          shadows: glow ? textGlow(color) : null,
        ),
      ),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
      maxLines: 1,
    )..layout();

    String nameOf(String? id) => items[id]?.name.ar ?? '';
    // أسماء الأشهر: Almarai 800، 15 (≥ 400dp) أو 13، cyan متوهج (R2.4).
    final monthSize = density == DialDensity.full ? 15.0 : 13.0;

    return DialLabels._(
      months: [
        for (final m in model.months)
          label(
            density == DialDensity.compact
                ? formatInteger(m.month!, digits)
                : l10n.gregorianMonthName('g${m.month}'),
            monthSize,
            colors.primary,
            weight: FontWeight.w800,
            glow: true,
          ),
      ],
      monthDays: {
        for (final d in const [10, 20, 30])
          d: label(formatInteger(d, digits), 11, colors.inkSoft),
      },
      dururNumbers: [
        for (final s in model.segments(DialRing.durur))
          label(formatInteger(s.dar!.number * 10, digits), 11, colors.ink),
      ],
      dururNames: [
        for (final s in model.segments(DialRing.durur))
          label(s.dar!.name.ar, 11, colors.ink),
      ],
      stars: [
        for (final s in model.segments(DialRing.stars))
          label(
            nameOf(s.itemId),
            12,
            items[s.itemId]?.dateMethod == DateMethod.heliacal
                ? colors.goldText
                : colors.ink,
          ),
      ],
      heliacal: [
        for (final s in model.segments(DialRing.stars))
          items[s.itemId]?.dateMethod == DateMethod.heliacal,
      ],
      weatherNames: {
        for (final s in model.segments(DialRing.weather))
          s.itemId!: label(nameOf(s.itemId), 12, colors.ink),
      },
      seasonNames: {
        for (final s in model.segments(DialRing.seasons))
          s.itemId!: label(nameOf(s.itemId), 12, colors.inkSoft),
      },
    );
  }

  final List<TextPainter> months;
  final Map<int, TextPainter> monthDays;
  final List<TextPainter> dururNumbers;
  final List<TextPainter> dururNames;
  final List<TextPainter> stars;

  /// الطوالع المحسوبة فلكياً (سهيل والثريا): الاسم بلون gold ويظهر دائماً.
  final List<bool> heliacal;

  /// أسماء مواسم الجو على الحلقة A (بالمعرّف).
  final Map<String, TextPainter> weatherNames;

  /// أسماء المواسم الأربعة في المركز (بالمعرّف).
  final Map<String, TextPainter> seasonNames;

  void dispose() {
    for (final p in [
      ...months,
      ...monthDays.values,
      ...dururNumbers,
      ...dururNames,
      ...stars,
      ...weatherNames.values,
      ...seasonNames.values,
    ]) {
      p.dispose();
    }
  }
}

/// صور مخزّنة للأجزاء الثابتة من الدائرة (DESIGN R2.3): الخلفية والإطار
/// المتوهج، والقرص بكل قطعه وتوهجه (يُرسم مرة ثم يُدار بتحويل فقط)، والإبرة
/// والمقبض. التوهج (MaskFilter.blur) أغلى ما في الرسم، فلا يُعاد مع كل إطار.
class DialPictures {
  Object? _key;
  ui.Picture? back;
  ui.Picture? disc;
  ui.Picture? front;

  /// يعيد بناء الصور إن تغيّر [key].
  void ensure(Object key, DialPainter p) {
    if (_key == key && back != null) return;
    dispose();
    _key = key;
    back = _record((c) => p._paintBack(c));
    disc = _record((c) => p._paintDisc(c));
    front = _record((c) => p._paintFront(c));
  }

  static ui.Picture _record(void Function(Canvas) draw) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    return recorder.endRecording();
  }

  void dispose() {
    back?.dispose();
    disc?.dispose();
    front?.dispose();
    back = disc = front = null;
    _key = null;
  }
}

/// يرسم القرص والإبرة (DESIGN R2.5). يعيد الرسم عند تغيّر [rotation] (أثناء
/// السحب) دون إعادة بناء أي عنصر واجهة؛ الأجزاء الثابتة من [pictures].
class DialPainter extends CustomPainter {
  DialPainter({
    required this.model,
    required this.labels,
    required this.colors,
    required this.radius,
    required this.rotation,
    required this.todayDay,
    required this.pictures,
    required this.layout,
    this.zoom = 1,
    this.iconSize = 16,
    this.density = DialDensity.medium,
  }) : super(repaint: rotation);

  final DialModel model;
  final DialLabels labels;
  final DururColors colors;
  final double radius;

  /// فهرس اليوم تحت الإبرة (كسري أثناء السحب).
  final ValueNotifier<double> rotation;

  /// فهرس «اليوم الحقيقي» في هذه السنة، أو null إن كان في سنة أخرى.
  final int? todayDay;
  final DialPictures pictures;

  /// رموز الجو على الحلقة A لهذا التكبير.
  final WeatherLayout layout;

  /// مقياس التكبير بالإصبع: النصوص والرموز تُرسم بحجمها على الشاشة
  /// (مقسومة عليه) فتتسع المساحة لها بدل أن تكبر.
  final double zoom;

  /// حجم رمز الجو المرئي (16 أو 18، R2.6).
  final double iconSize;
  final DialDensity density;

  DialGeometry get _geo =>
      DialGeometry(radius: radius, dayCount: model.dayCount);

  bool get _detail => zoom >= dialDetailZoom;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _geo;
    final rot = rotation.value;
    final selected = rot.round() % model.dayCount;
    pictures.ensure((model, radius, colors, _detail), this);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawPicture(pictures.back!);
    canvas.save();
    // القرص مرسوم والدوران صفر؛ يدور الآن بتحويل فقط.
    canvas.rotate(-rot * geo.step);
    canvas.drawPicture(pictures.disc!);
    canvas.restore();

    _paintSelection(canvas, geo, rot, selected);
    _paintLabels(canvas, geo, rot, selected);
    _paintWeatherMarks(canvas, geo, rot);

    // علامة ذهبية عند «اليوم الحقيقي» حين يُعرض تاريخ آخر (DESIGN 7.3).
    final today = todayDay;
    if (today != null && today != selected) {
      final o = _polar(geo.angleOf(today + 0.5, rot), radius - 3);
      canvas.drawCircle(o, 4.5, Paint()..color = colors.background);
      canvas.drawCircle(o, 3, Paint()..color = colors.goldDeco);
    }

    canvas.drawPicture(pictures.front!);
    canvas.restore();
  }

  // ———— الأجزاء الثابتة (تُسجَّل في صور) ————

  /// الإطار المتوهج والقرص الزجاجي (R2.3): لا يتأثر بالدوران.
  void _paintBack(Canvas canvas) {
    canvas.drawCircle(
      Offset.zero,
      radius + 1,
      _glow(colors.primary.withValues(alpha: 0.35), 6, 0.7, 5),
    );
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, radius, const [
          Color(0xFF12304A),
          Color(0xFF0B1C31),
        ]),
    );
    final (ao, ai) = _geo.band(DialRing.weather);
    canvas.drawCircle(
      Offset.zero,
      (ao + ai) / 2,
      Paint()
        ..color = const Color(0xFF0C1F35).withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ao - ai,
    );
  }

  /// القرص كاملاً والدوران صفر: كل القطع والفواصل والتدريج والتوهج.
  void _paintDisc(Canvas canvas) {
    final geo = _geo;
    const rot = 0.0;
    final glass = Paint()
      ..color = colors.glassStroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // F: المواسم الأربعة بنسبها الحقيقية، تعبئة 14% (الحالي يُضاف فوقه).
    final (fo, fi) = geo.band(DialRing.seasons);
    for (final s in model.segments(DialRing.seasons)) {
      final path = _sector(
        geo.angleOf(s.start, rot),
        geo.angleOf(s.end, rot),
        fo,
        fi,
      );
      canvas.drawPath(
        path,
        Paint()..color = colors.season(s.colorSeasonId).withValues(alpha: 0.14),
      );
    }
    for (final s in model.cyclicSegments(DialRing.seasons)) {
      _separator(
        canvas,
        geo.angleOf(s.start, rot),
        fo,
        fi,
        colors.glassStroke,
        0.75,
      );
    }

    // D: الطوالع بتعبئة متناوبة cyan 5%/9%، ونجمة gold عند بداية كل طالع.
    final (so, si) = geo.band(DialRing.stars);
    for (final (i, s) in model.cyclicSegments(DialRing.stars).indexed) {
      final a0 = geo.angleOf(s.start, rot);
      final a1 = geo.angleOf(s.end, rot);
      canvas.drawPath(
        _sector(a0, a1, so, si),
        Paint()..color = colors.primary.withValues(alpha: i.isOdd ? 0.09 : 0.05),
      );
      _separator(canvas, a0, so, si, colors.glassStroke, 0.75);
      canvas.drawPath(
        fourPointStar(_polar(a0 + 7 / so, so - 7), 5),
        Paint()..color = colors.starMark,
      );
    }

    // C: الدرور بتعبئة لون مئتها 30%، وفاصل أعرض بين المئات.
    final (co, ci) = geo.band(DialRing.durur);
    final durur = model.cyclicSegments(DialRing.durur);
    for (final (i, s) in durur.indexed) {
      final a0 = geo.angleOf(s.start, rot);
      canvas.drawPath(
        _sector(a0, geo.angleOf(s.end, rot), co, ci),
        Paint()
          ..color = colors
              .season(s.colorSeasonId)
              .withValues(alpha: colors.seasonTint),
      );
      final prev = durur[(i - 1 + durur.length) % durur.length];
      final hundred = prev.colorSeasonId != s.colorSeasonId;
      _separator(
        canvas,
        a0,
        co,
        ci,
        colors.ink.withValues(alpha: hundred ? 0.6 : 0.22),
        hundred ? 1.5 : 0.75,
      );
    }

    // B: الأشهر: فاصل بعرض الحلقة، وتدريجة كل 5 أيام على الحافة الخارجية
    // (وكل يوم عند التكبير).
    final (mo, mi) = geo.band(DialRing.months);
    final monthLine = Paint()
      ..color = colors.primary.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    final tick = Paint()
      ..color = colors.inkSoft.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    final small = Paint()
      ..color = colors.inkSoft.withValues(alpha: 0.6)
      ..strokeWidth = 0.6;
    for (final m in model.months) {
      final a = geo.angleOf(m.start, rot);
      canvas.drawLine(_polar(a, mo), _polar(a, mi), monthLine);
      for (var d = 1; d <= m.length; d++) {
        final five = d % 5 == 0 && d < 30;
        if (!five && !_detail) continue;
        final ta = geo.angleOf(m.start + d - 0.5, rot);
        canvas.drawLine(
          _polar(ta, mo),
          _polar(ta, mo - (five ? 5 : 2.5)),
          five ? tick : small,
        );
      }
    }

    // A: أقواس مواسم الجو متقطعة 2.5dp بنغمة موسمها الكبير، مع توهج 1.
    final (_, wi) = geo.band(DialRing.weather);
    final r = wi + 4;
    for (final s in model.segments(DialRing.weather)) {
      final color = colors.season(s.colorSeasonId);
      final a0 = geo.angleOf(s.start, rot);
      final a1 = geo.angleOf(s.end, rot);
      final dashes = _dashedArc(a0, a1, r, 7, 4);
      canvas.drawPath(dashes, _glow(color, 3, 0.5, 2.5));
      canvas.drawPath(dashes, _stroke(color, 2.5));
    }

    // حدود الحلقات.
    for (final rr in [wi, mi, ci, si]) {
      canvas.drawCircle(Offset.zero, rr, glass);
    }
  }

  /// الإبرة الثابتة من حافة المركز إلى خارج الحلقة A، ورأسها، والمقبض.
  void _paintFront(Canvas canvas) {
    final geo = _geo;
    final (fo, _) = geo.band(DialRing.seasons);
    final needle = Path()
      ..moveTo(0, -fo)
      ..lineTo(0, -(radius + 1));
    canvas.drawPath(needle, _glow(colors.primary, 6, 0.7, 3));
    canvas.drawPath(needle, _stroke(colors.ink, 1.5));
    final head = Path()
      ..moveTo(0, -radius + 1)
      ..lineTo(-6, -radius - 11)
      ..lineTo(6, -radius - 11)
      ..close();
    canvas.drawPath(head, _glow(colors.primary, 6, 0.7, 0)..style = PaintingStyle.fill);
    canvas.drawPath(head, Paint()..color = colors.primary);
    canvas.drawCircle(
      Offset(0, -radius - 11),
      2.2,
      Paint()..color = colors.goldDeco,
    );

    // المقبض (G): تدرّج زجاجي، حد cyan 60% متوهج، ونقطة ink 5dp.
    final hub = geo.hubRadius;
    canvas.drawCircle(
      Offset.zero,
      hub,
      _glow(colors.primary.withValues(alpha: 0.6), 3, 0.5, 1),
    );
    canvas.drawCircle(
      Offset.zero,
      hub,
      Paint()
        ..shader = ui.Gradient.radial(Offset(0, -hub * 0.2), hub, [
          const Color(0xFF1B3B57),
          colors.background,
        ]),
    );
    canvas.drawCircle(
      Offset.zero,
      hub,
      _stroke(colors.primary.withValues(alpha: 0.6), 1),
    );
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = colors.ink);
  }

  // ———— الأجزاء المتغيرة مع اليوم ————

  void _paintSelection(Canvas canvas, DialGeometry geo, double rot, int day) {
    final (fo, fi) = geo.band(DialRing.seasons);
    final days = model.index.days;

    // الموسم الحالي في المركز: تعبئة 30% وحد متوهج بنغمته.
    final season = model.segmentAt(DialRing.seasons, day);
    if (season != null) {
      final tone = colors.season(season.colorSeasonId);
      final info = days[day].majorSeason;
      final start = _dayIndex(info.start);
      final end = _dayIndex(info.end) + 1;
      final a0 = geo.angleOf(start, rot);
      final a1 = geo.angleOf(end, rot);
      canvas.drawPath(
        _sector(a0, a1, fo, fi),
        Paint()..color = tone.withValues(alpha: 0.19),
      );
      final edge = _arc(a0, a1, fo - 1);
      canvas.drawPath(edge, _glow(tone, 3, 0.5, 2));
      canvas.drawPath(edge, _stroke(tone, 2));
    }

    // شريحة اليوم تحت الإبرة عبر كل الحلقات.
    canvas.drawPath(
      _sector(-geo.step / 2, geo.step / 2, radius, fo),
      Paint()..color = colors.primary.withValues(alpha: 0.12),
    );

    // القطع المختارة: حدّ cyan 2dp مع توهج 1 (تمييز ليس باللون وحده).
    for (final ring in const [
      DialRing.durur,
      DialRing.stars,
      DialRing.weather,
    ]) {
      final info = days[day];
      final period = switch (ring) {
        DialRing.durur => info.dar,
        DialRing.stars => info.star,
        _ => info.weatherSeason,
      };
      if (period == null) continue;
      final (outer, inner) = geo.band(ring);
      final path = _sector(
        geo.angleOf(_dayIndex(period.start), rot),
        geo.angleOf(_dayIndex(period.end) + 1, rot),
        outer - 1,
        inner + 1,
      );
      canvas.drawPath(path, _glow(colors.primary, 3, 0.5, 2));
      canvas.drawPath(path, _stroke(colors.primary, 2));
    }

    // قوس تقدّم الموسم الكبير الحالي: من بدايته إلى الإبرة، cyan 3dp متوهج.
    final major = days[day].majorSeason;
    final a0 = geo.angleOf(_dayIndex(major.start), rot);
    if (a0 < 0) {
      final arc = _arc(a0, 0, geo.progressRadius);
      canvas.drawPath(
        arc,
        _glow(colors.primary, 6, 0.7, 3)..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        arc,
        _stroke(colors.primary, 3)..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintLabels(Canvas canvas, DialGeometry geo, double rot, int day) {
    final z = zoom;

    // B: أسماء الأشهر (وعند التكبير أرقام ١٠/٢٠/٣٠).
    final (mo, mi) = geo.band(DialRing.months);
    for (final (i, m) in model.months.indexed) {
      final label = labels.months[i];
      final r = _detail
          ? mi + (label.height / 2 + 2) / z
          : (mo + mi) / 2;
      _tangential(canvas, label, geo.angleOf(m.start + m.length / 2, rot), r);
      if (_detail) {
        for (final MapEntry(key: d, value: t) in labels.monthDays.entries) {
          if (d > m.length) continue;
          _tangential(
            canvas,
            t,
            geo.angleOf(m.start + d - 0.5, rot),
            mo - 5 - (t.height / 2 + 1) / z,
          );
        }
      }
    }

    // C: أرقام الدرور (أو أسماؤها عند التكبير)، ونقطة إن ضاقت القطعة.
    final (co, ci) = geo.band(DialRing.durur);
    final cMid = (co + ci) / 2;
    for (final (i, s) in model.segments(DialRing.durur).indexed) {
      final arcPx = s.length * geo.step * cMid * z;
      final mid = geo.angleOf(s.start + s.length / 2, rot);
      final name = labels.dururNames[i];
      final number = labels.dururNumbers[i];
      final text = _detail && name.width <= arcPx - 2 ? name : number;
      if (text.width <= arcPx - 2) {
        _tangential(canvas, text, mid, cMid);
      } else {
        canvas.drawCircle(_polar(mid, cMid), 1.5 / z, Paint()..color = colors.ink);
      }
    }

    // D: أسماء الطوالع: الحالي وسهيل والثريا دائماً، وما يتسع قوسه.
    final (so, si) = geo.band(DialRing.stars);
    final dMid = (so + si) / 2 - 3 / z;
    if (density != DialDensity.compact) {
      final current = model.segmentAt(DialRing.stars, day);
      for (final (i, s) in model.segments(DialRing.stars).indexed) {
        final label = labels.stars[i];
        final arcPx = s.length * geo.step * dMid * z;
        final fits = arcPx >= label.width + 16;
        final always = labels.heliacal[i] || identical(s, current);
        if (!(fits || always || z >= dialAllStarsZoom)) continue;
        final mid = geo.angleOf(s.start + s.length / 2, rot);
        _tangential(canvas, label, mid, dMid);
        // اسم الطالع الحالي يُكرر يمين الإبرة إن بعُد منتصف قوسه عنها > 60°.
        if (identical(s, current)) {
          final away = (math.atan2(math.sin(mid), math.cos(mid))).abs();
          if (away > math.pi / 3) {
            _tangential(
              canvas,
              label,
              (label.width / 2 + 8) / (dMid * z),
              dMid,
            );
          }
        }
      }
    }

    // F: أسماء المواسم غير الحالية إن اتسع القطاع (الحالي نصه فوق المركز).
    final (fo, fi) = geo.band(DialRing.seasons);
    final fMid = (fo + fi) / 2;
    final currentSeason = model.index.days[day].majorSeason.itemId;
    for (final s in model.cyclicSegments(DialRing.seasons)) {
      if (s.itemId == currentSeason) continue;
      final label = labels.seasonNames[s.itemId];
      if (label == null) continue;
      final arcPx = s.length * geo.step * fMid * z;
      if (arcPx < label.width + 8) continue;
      _tangential(canvas, label, geo.angleOf(s.start + s.length / 2, rot), fMid);
    }
  }

  void _paintWeatherMarks(Canvas canvas, DialGeometry geo, double rot) {
    final r = geo.weatherMid;
    final back = Paint()..color = const Color(0xFF0C1F35);
    for (final g in layout.groups) {
      final nameOffset = g.nameOffset;
      if (nameOffset != null) {
        final label = labels.weatherNames[g.itemId];
        if (label != null) {
          _tangential(
            canvas,
            label,
            groupAngle(geo, g, nameOffset, rot, r, zoom),
            r,
          );
        }
      }
      for (final m in g.marks) {
        final (x, y) = markPosition(geo, g, m.offset, rot, r, zoom);
        canvas.save();
        canvas.translate(x, y);
        // الرمز قائم دائماً بحجمه على الشاشة، فوق قرص خلفي 20dp (R2.6).
        canvas.scale(1 / zoom);
        canvas.drawCircle(Offset.zero, iconSize * 0.62, back);
        canvas.translate(-iconSize / 2, -iconSize / 2);
        canvas.scale(iconSize / 24);
        paintWeatherSymbol(canvas, m.symbol, colors.ink);
        canvas.restore();
      }
    }
  }

  // ———— أدوات ————

  /// فهرس يوم (قد يكون خارج السنة) لتاريخ UTC.
  int _dayIndex(DateTime utc) => DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
  ).difference(DateTime.utc(model.year)).inDays;

  static Offset _polar(double angle, double r) =>
      Offset(r * math.sin(angle), -r * math.cos(angle));

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  /// توهج (R2.3): نسخة مموهة من الخط بشفافية [alpha] تحته.
  static Paint _glow(Color color, double sigma, double alpha, double width) =>
      Paint()
        ..color = color.withValues(alpha: color.a * alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

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

  static Path _arc(double a0, double a1, double r) => Path()
    ..addArc(
      Rect.fromCircle(center: Offset.zero, radius: r),
      a0 - math.pi / 2,
      a1 - a0,
    );

  static Path _dashedArc(
    double a0,
    double a1,
    double r,
    double dash,
    double gap,
  ) {
    final path = Path();
    final d = dash / r;
    final g = gap / r;
    for (var a = a0; a < a1; a += d + g) {
      path.addArc(
        Rect.fromCircle(center: Offset.zero, radius: r),
        a - math.pi / 2,
        math.min(d, a1 - a),
      );
    }
    return path;
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

  /// نص مماسّ للقوس، قائم دائماً (يُقلب في النصف السفلي)، بحجمه على الشاشة.
  void _tangential(Canvas canvas, TextPainter text, double angle, double r) {
    canvas.save();
    canvas.rotate(angle);
    canvas.translate(0, -r);
    if (math.cos(angle) < 0) canvas.rotate(math.pi);
    canvas.scale(1 / zoom);
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
      old.rotation != rotation ||
      old.zoom != zoom ||
      old.layout != layout ||
      old.iconSize != iconSize ||
      old.density != density;
}
