import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../astronomy/seasons.dart';
import '../../../domain/item.dart';
import '../../../formatting/digits.dart';
import '../../../theme/app_theme.dart';
import '../../common/weather_icon.dart';
import 'dial_model.dart';
import 'weather_marks.dart';

/// كثافة الأسماء في الدائرة حسب عرض الشاشة (DESIGN R2.10، R3.1).
enum DialDensity {
  /// ≥ 400dp: الأشهر بخط 17، ورموز الجو 16.
  full,

  /// 360–399dp: الأشهر بخط 15، ورموز الجو 14.
  medium,

  /// < 360dp: الأشهر بأرقامها (7.6).
  compact,
}

/// التكبير الذي تظهر عنده أرقام كل 5 أيام وكل أسماء البروج (R3.1-7 و10).
const double dialDetailZoom = 1.6;

/// التكبير الذي تظهر عنده كل أسماء الطوالع (R3.1-9).
const double dialAllStarsZoom = 2;

// ألوان التعبئات (DESIGN R3.1-14 والبند 8).
const _frameFill = Color(0xFF142F3D);
const _monthsFill = Color(0xFF10293A);
const _daysFill = Color(0xFF0E2533);
const _darEmptyFill = Color(0xFF0F2A36);
const _starsFill = Color(0xFF0E2732);
const _zodiacFill = Color(0xFF11303C);
const _centerFill = Color(0xFF15323F);
const _currentQuarterFill = Color(0xFF1C4150);
const _ringEdge = Color(0x737FE9F3); // #7FE9F3 45%
const _darSeparator = Color(0xB30A2230); // #0A2230 70%

/// تعبئات المئات المعتمة (R3.1-8)، وتُستخدم للطوالع في منطقة بلا درور.
const _hundredFills = {
  'saif': Color(0xFF5E6A3A),
  'qaiz': Color(0xFF6B5232),
  'safari': Color(0xFF6A4560),
  'shita': Color(0xFF2A5A7C),
};

/// الحروف التي لا تتصل بما بعدها (لا كشيدة بعدها، R3.1-6).
// ا أ إ آ د ذ ر ز و ؤ ة ى ء والكشيدة نفسها.
const _nonConnecting = {
  0x0627, 0x0623, 0x0625, 0x0622, 0x062F, 0x0630, 0x0631, 0x0632, //
  0x0648, 0x0624, 0x0629, 0x0649, 0x0621, 0x0640,
};

/// الكشيدة (التطويل) U+0640.
const _tatweel = '\u0640';

bool _isArabicLetter(int c) => c >= 0x0621 && c <= 0x064A;

/// يدرج الكشيدة U+0640 في موضعين على الأكثر حتى يبلغ عرض [name] [target]
/// (R3.1-6). يُرجع الاسم كما هو إن كان عرضه الطبيعي ≥ [target].
String stretchWithKashida(
  String name,
  double target,
  double Function(String) measure,
) {
  if (measure(name) >= target) return name;
  final codes = name.runes.toList();
  final candidates = <int>[
    for (var i = 0; i < codes.length - 1; i++)
      if (_isArabicLetter(codes[i]) &&
          _isArabicLetter(codes[i + 1]) &&
          !_nonConnecting.contains(codes[i]))
        i,
  ];
  if (candidates.isEmpty) return name;
  // أقرب موضعين إلى منتصف الاسم.
  final mid = (codes.length - 1) / 2;
  candidates.sort((a, b) => (a - mid).abs().compareTo((b - mid).abs()));
  final positions = candidates.take(2).toList()..sort();
  final counts = List.filled(positions.length, 0);
  String build() {
    final out = StringBuffer();
    for (var i = 0; i < codes.length; i++) {
      out.writeCharCode(codes[i]);
      final p = positions.indexOf(i);
      if (p >= 0) out.write(_tatweel * counts[p]);
    }
    return out.toString();
  }

  var result = name;
  for (var k = 0; k < 16; k++) {
    counts[k % positions.length]++;
    final next = build();
    if (measure(next) > target * 1.02) break;
    result = next;
    if (measure(next) >= target) break;
  }
  return result;
}

/// نصوص الدائرة مُعدّة مسبقاً (TextPainter) حتى لا يُعاد تخطيطها مع كل
/// إطار. تُبنى مرة لكل (سنة، منطقة، حجم، خط، كثافة، أرقام).
class DialLabels {
  DialLabels._({
    required this.months,
    required this.monthNumbers,
    required this.dayNumbers,
    required this.dururNumbers,
    required this.dururNames,
    required this.stars,
    required this.heliacal,
    required this.weatherNames,
    required this.zodiac,
    required this.zodiacCurrent,
    required this.quarterNames,
    required this.quarterNamesCurrent,
    required this.heritage,
    required this.heritageCurrent,
    required this.quarterDates,
    required this.quarterDatesShort,
  });

  factory DialLabels.build({
    required DialModel model,
    required Map<String, Item> items,
    required AppLocalizations l10n,
    required DururColors colors,
    required TextScaler textScaler,
    required DialDensity density,
    required double radius,
    DigitStyle digits = DigitStyle.arabicIndic,
  }) {
    // نصوص الدائرة تتكبّر حتى 1.3× فقط (DESIGN 7.6)؛ التكبير بالإصبع بديل.
    final scaler = textScaler.clamp(maxScaleFactor: 1.3);
    TextStyle style(
      double size,
      Color color, {
      FontWeight weight = FontWeight.w700,
      List<Shadow>? shadows,
    }) => TextStyle(
      fontFamily: DururFonts.body,
      fontSize: size,
      fontWeight: weight, // Almarai بلا 500/600 (DESIGN §3)
      color: color,
      height: 1.2,
      shadows: shadows,
    );
    TextPainter paint(String text, TextStyle s) => TextPainter(
      text: TextSpan(text: text, style: s),
      textDirection: TextDirection.rtl,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    TextPainter label(
      String text,
      double size,
      Color color, {
      FontWeight weight = FontWeight.w700,
      List<Shadow>? shadows,
    }) => paint(text, style(size, color, weight: weight, shadows: shadows));

    String nameOf(String? id) => items[id]?.name.ar ?? '';
    final geo = DialGeometry.of(model, radius);

    // B: أسماء الأشهر Almarai 800، 17 (≥ 400dp) أو 15، cyan بتوهج طبقتين،
    // ممدودة بالكشيدة إلى 80% من قوس الشهر (R3.1-6).
    final monthSize = density == DialDensity.full ? 17.0 : 15.0;
    final monthStyle = style(
      monthSize,
      colors.primary,
      weight: FontWeight.w800,
      shadows: [
        Shadow(color: colors.primary.withValues(alpha: 0.7), blurRadius: 3),
        Shadow(color: colors.primary.withValues(alpha: 0.4), blurRadius: 10),
      ],
    );
    double measure(String s) {
      final p = paint(s, monthStyle);
      final w = p.width;
      p.dispose();
      return w;
    }

    final (mo, mi) = geo.band(DialRing.months);
    final monthR = (mo + mi) / 2;

    final (fo, _) = geo.band(DialRing.seasons);
    final heritage = <AstroSeason, String?>{};
    for (final s in model.cyclicSegments(DialRing.seasons)) {
      final id = model.heritageFor(s);
      final h = id == null ? null : nameOf(id);
      final name = l10n.astroSeasonName(s.astroSeason!.name);
      // يُخفى إن طابق اسم الفصل (R3.2).
      heritage[s.astroSeason!] = h == null || h.isEmpty || h == name ? null : h;
    }
    String dm(DateTime d) =>
        l10n.dayMonthDate(formatInteger(d.day, digits), 'g${d.month}');
    String dmShort(DateTime d) => l10n.astroDateShort(
      formatInteger(d.day, digits),
      formatInteger(d.month, digits),
    );
    final seasonStarts = {
      for (final p in model.astro.seasons)
        if (p.start.day.year == model.year) p.value: p.start.day,
    };

    return DialLabels._(
      months: [
        for (final m in model.months)
          density == DialDensity.compact
              ? paint(formatInteger(m.month!, digits), monthStyle)
              : paint(
                  stretchWithKashida(
                    l10n.gregorianMonthName('g${m.month}'),
                    0.8 * m.length * geo.step * monthR,
                    measure,
                  ),
                  monthStyle,
                ),
      ],
      monthNumbers: [
        for (var m = 1; m <= 12; m++)
          label(formatInteger(m, digits), 11, colors.inkSoft),
      ],
      dayNumbers: {
        for (final d in const [5, 10, 15, 20, 25, 30])
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
      stars: {
        for (final s in model.segments(DialRing.stars))
          s.itemId!: label(
            nameOf(s.itemId),
            11,
            items[s.itemId]?.dateMethod == DateMethod.heliacal
                ? colors.goldText
                : colors.ink,
          ),
      },
      heliacal: {
        for (final s in model.segments(DialRing.stars))
          if (items[s.itemId]?.dateMethod == DateMethod.heliacal) s.itemId!,
      },
      weatherNames: {
        for (final s in model.segments(DialRing.weather))
          s.itemId!: label(nameOf(s.itemId), 11, colors.inkSoft),
      },
      zodiac: {
        for (final z in ZodiacSign.values)
          z: label(l10n.zodiacName(z.name), 11, colors.inkSoft),
      },
      zodiacCurrent: {
        for (final z in ZodiacSign.values)
          z: label(l10n.zodiacName(z.name), 11, colors.ink),
      },
      quarterNames: {
        for (final s in AstroSeason.values)
          s: label(
            l10n.astroSeasonName(s.name),
            13,
            colors.primary,
            weight: FontWeight.w800,
          ),
      },
      quarterNamesCurrent: {
        for (final s in AstroSeason.values)
          s: label(
            l10n.astroSeasonName(s.name),
            15,
            colors.primary,
            weight: FontWeight.w800,
            shadows: textGlow(colors.primary),
          ),
      },
      heritage: {
        for (final MapEntry(:key, :value) in heritage.entries)
          if (value != null) key: label(value, 11, colors.inkSoft),
      },
      heritageCurrent: {
        for (final MapEntry(:key, :value) in heritage.entries)
          if (value != null) key: label(value, 11, colors.ink),
      },
      quarterDates: {
        for (final MapEntry(:key, :value) in seasonStarts.entries)
          key: label(dm(value), 11, colors.inkSoft),
      },
      quarterDatesShort: {
        for (final MapEntry(:key, :value) in seasonStarts.entries)
          key: label(dmShort(value), 11, colors.inkSoft),
      },
    )..centerRadius = fo;
  }

  final List<TextPainter> months;
  final List<TextPainter> monthNumbers;
  final Map<int, TextPainter> dayNumbers;
  final List<TextPainter> dururNumbers;
  final List<TextPainter> dururNames;
  /// أسماء الطوالع بالمعرّف.
  final Map<String, TextPainter> stars;

  /// الطوالع المحسوبة فلكياً (سهيل والثريا): الاسم بلون gold.
  final Set<String> heliacal;

  /// أسماء مواسم الجو على الإطار A (بالمعرّف).
  final Map<String, TextPainter> weatherNames;
  final Map<ZodiacSign, TextPainter> zodiac;
  final Map<ZodiacSign, TextPainter> zodiacCurrent;
  final Map<AstroSeason, TextPainter> quarterNames;
  final Map<AstroSeason, TextPainter> quarterNamesCurrent;

  /// الاسم التراثي المقابل لكل فصل (إن وُجد ولم يطابق اسم الفصل).
  final Map<AstroSeason, TextPainter> heritage;
  final Map<AstroSeason, TextPainter> heritageCurrent;

  /// تاريخ بداية كل فصل على ذراع الصليب: كامل، ومختصر «٢١/١٢».
  final Map<AstroSeason, TextPainter> quarterDates;
  final Map<AstroSeason, TextPainter> quarterDatesShort;

  /// نصف قطر المركز الذي بُنيت عليه النصوص.
  double centerRadius = 0;

  void dispose() {
    for (final p in [
      ...months,
      ...monthNumbers,
      ...dayNumbers.values,
      ...dururNumbers,
      ...dururNames,
      ...stars.values,
      ...weatherNames.values,
      ...zodiac.values,
      ...zodiacCurrent.values,
      ...quarterNames.values,
      ...quarterNamesCurrent.values,
      ...heritage.values,
      ...heritageCurrent.values,
      ...quarterDates.values,
      ...quarterDatesShort.values,
    ]) {
      p.dispose();
    }
  }
}

/// صورة مخزّنة للقرص الثابت (R3.7-5): كل الحلقات والنصوص والتوهج تُرسم مرة،
/// ولا يُعاد مع السحب إلا العقرب والشريحة والتمييز.
class DialPictures {
  Object? _key;
  ui.Picture? disc;

  void ensure(Object key, DialPainter p) {
    if (_key == key && disc != null) return;
    dispose();
    _key = key;
    final recorder = ui.PictureRecorder();
    p._paintDisc(Canvas(recorder));
    disc = recorder.endRecording();
  }

  void dispose() {
    disc?.dispose();
    disc = null;
    _key = null;
  }
}

/// يرسم القرص الثابت والعقرب الدوّار (DESIGN R3.1). يعيد الرسم عند تغيّر
/// [rotation] (فهرس اليوم تحت العقرب، كسري أثناء السحب) دون إعادة بناء أي
/// عنصر واجهة.
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

  /// فهرس اليوم تحت العقرب (كسري أثناء السحب).
  final ValueNotifier<double> rotation;

  /// فهرس «اليوم الحقيقي» في هذه السنة، أو null إن كان في سنة أخرى.
  final int? todayDay;
  final DialPictures pictures;

  /// أسماء مواسم الجو والرموز الظاهرة في الإطار A.
  final FrameLayout layout;

  /// مقياس التكبير بالإصبع: النصوص والرموز تُرسم بحجمها على الشاشة.
  final double zoom;

  /// حجم رمز الجو المرئي (14 أو 16، R3.1-5).
  final double iconSize;
  final DialDensity density;

  DialGeometry get _geo => DialGeometry.of(model, radius);

  bool get _detail => zoom >= dialDetailZoom;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _geo;
    final rot = rotation.value;
    final selected = rot.round().clamp(0, model.dayCount - 1);
    pictures.ensure((model, radius, colors, labels, layout, zoom), this);

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawPicture(pictures.disc!);
    _paintSelection(canvas, geo, rot, selected);
    _paintCenter(canvas, geo, selected);
    _paintPointer(canvas, geo, rot);

    // علامة ذهبية عند «اليوم الحقيقي» حين يُعرض تاريخ آخر (DESIGN 7.3).
    final today = todayDay;
    if (today != null && today != selected) {
      final o = _polar(geo.centerAngle(today), radius - 3);
      canvas.drawCircle(o, 4.5, Paint()..color = colors.background);
      canvas.drawCircle(o, 3, Paint()..color = colors.goldDeco);
    }
    canvas.restore();
  }

  // ———— القرص الثابت (يُسجَّل في صورة) ————

  void _paintDisc(Canvas canvas) {
    final geo = _geo;
    final edge = _stroke(_ringEdge, 1);

    // توهج الحافة الخارجية وتعبئات الحلقات (R3.1-12 و14).
    canvas.drawCircle(
      Offset.zero,
      radius,
      _glow(colors.primary.withValues(alpha: 0.5), 6, 0.7, 4),
    );
    void fillBand(DialRing ring, Color color) {
      final (o, i) = geo.band(ring);
      canvas.drawCircle(
        Offset.zero,
        (o + i) / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = o - i,
      );
    }

    fillBand(DialRing.weather, _frameFill);
    fillBand(DialRing.months, _monthsFill);
    fillBand(DialRing.days, _daysFill);
    if (model.hasDurur) {
      fillBand(DialRing.durur, _darEmptyFill);
      fillBand(DialRing.stars, _starsFill);
    }
    fillBand(DialRing.zodiac, _zodiacFill);
    canvas.drawCircle(
      Offset.zero,
      geo.band(DialRing.seasons).$1,
      Paint()..color = _centerFill,
    );

    _paintFrame(canvas, geo);
    _paintMonths(canvas, geo);
    _paintDays(canvas, geo);
    if (model.hasDurur) _paintDurur(canvas, geo);
    _paintStars(canvas, geo);
    _paintZodiac(canvas, geo);

    // حدود الحلقات: الخارجية وحافتا الأشهر cyan 80% مع توهج، وحافة المركز
    // cyan 60%، والبقية #7FE9F3 45% (R3.1-12).
    final bright = colors.primary.withValues(alpha: 0.8);
    final (wo, wi) = geo.band(DialRing.weather);
    final (_, mi) = geo.band(DialRing.months);
    for (final r in [wo - 0.75, wi, mi]) {
      canvas.drawCircle(Offset.zero, r, _glow(bright, 3, 0.5, 1.5));
      canvas.drawCircle(Offset.zero, r, _stroke(bright, 1.5));
    }
    for (final ring in geo.rings) {
      if (ring == DialRing.weather ||
          ring == DialRing.months ||
          ring == DialRing.seasons) {
        continue;
      }
      canvas.drawCircle(Offset.zero, geo.band(ring).$2, edge);
    }
    canvas.drawCircle(
      Offset.zero,
      geo.band(DialRing.seasons).$1,
      _stroke(colors.primary.withValues(alpha: 0.6), 1.5),
    );

    // صليب المركز: خطوط عند بدايات الفصول من المحور إلى حافة المركز (R3.2).
    final (fo, _) = geo.band(DialRing.seasons);
    final cross = _stroke(colors.primary.withValues(alpha: 0.7), 1.5);
    for (final s in model.cyclicSegments(DialRing.seasons)) {
      final a = geo.angleOf(s.start);
      canvas.drawLine(_polar(a, geo.hubRadius), _polar(a, fo), cross);
      _paintArmDate(canvas, geo, s.astroSeason!, a);
    }

    // المحور G: قطره 0.07R، تدرّج #2B4F5E←#0E2533، حد cyan 60% 2dp، ونقطة
    // ink 5dp (R3.1-11).
    final hub = geo.hubRadius;
    canvas.drawCircle(
      Offset.zero,
      hub,
      Paint()
        ..shader = ui.Gradient.radial(Offset(0, -hub * 0.3), hub * 1.2, const [
          Color(0xFF2B4F5E),
          Color(0xFF0E2533),
        ]),
    );
    canvas.drawCircle(
      Offset.zero,
      hub,
      _stroke(colors.primary.withValues(alpha: 0.6), 2),
    );
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = colors.ink);
  }

  /// A: رمز لكل خلية بلونه الدلالي، وأسماء مواسم الجو، وتدريجتا حدودها،
  /// وأرقام الأشهر على الحافة الخارجية (R3.1-5).
  void _paintFrame(Canvas canvas, DialGeometry geo) {
    final (wo, wi) = geo.band(DialRing.weather);
    final mid = geo.weatherMid;
    final tick = _stroke(colors.inkSoft, 1);
    for (final s in model.cyclicSegments(DialRing.weather)) {
      for (final day in [s.start, s.end]) {
        final a = geo.angleOf(day);
        canvas.drawLine(_polar(a, wi), _polar(a, wi + 6), tick);
      }
    }
    for (final name in layout.names) {
      final label = labels.weatherNames[name.itemId];
      if (label == null) continue;
      _tangential(canvas, label, geo.angleOf(name.center), mid);
    }
    for (final m in layout.marks) {
      final (x, y) = DialGeometry.polar(geo.angleOf(m.center), mid);
      canvas.save();
      canvas.translate(x, y);
      // الرمز قائم دائماً بحجمه على الشاشة، بلا قرص خلفي (R3.1-5).
      canvas.scale(1 / zoom);
      canvas.translate(-iconSize / 2, -iconSize / 2);
      canvas.scale(iconSize / 24);
      paintWeatherSymbol(
        canvas,
        m.symbol,
        colors.dialWeatherTone(m.symbol.code),
        strokeWidth: 1.75 * 24 / iconSize,
      );
      canvas.restore();
    }
    // أرقام الأشهر عند بداية كل شهر على الحافة الخارجية.
    for (final (i, m) in model.months.indexed) {
      final t = labels.monthNumbers[i];
      final r = wo - (t.height / 2 + 1) / zoom;
      final a = geo.angleOf(m.start) - (t.width / 2 + 3) / (r * zoom);
      _tangential(canvas, t, a, r);
    }
  }

  /// B: الأسماء (بالكشيدة والتوهج) وحد كل شهر بعرض B وB2.
  void _paintMonths(Canvas canvas, DialGeometry geo) {
    final (mo, mi) = geo.band(DialRing.months);
    final (_, di) = geo.band(DialRing.days);
    final line = _stroke(colors.primary, 1.5);
    for (final (i, m) in model.months.indexed) {
      final a = geo.angleOf(m.start);
      canvas.drawLine(_polar(a, mo), _polar(a, di), line);
      _tangential(
        canvas,
        labels.months[i],
        geo.angleOf(m.start + m.length / 2),
        (mo + mi) / 2,
      );
    }
  }

  /// B2: تدريجة كل يوم 3dp، وكل 5 أيام 6dp، وأرقام ١٠/٢٠/٣٠ (وكل 5 أيام
  /// عند التكبير) مكان تدريجتها (R3.1-7).
  void _paintDays(Canvas canvas, DialGeometry geo) {
    final (bo, bi) = geo.band(DialRing.days);
    final small = _stroke(const Color(0x737FE9F3), 1);
    final long = _stroke(colors.primary.withValues(alpha: 0.8), 1);
    final pxPerDay = geo.step * (bo + bi) / 2 * zoom;
    for (final m in model.months) {
      for (var d = 1; d < m.length; d++) {
        final a = geo.angleOf(m.start + d);
        final five = d % 5 == 0;
        final number = labels.dayNumbers[d];
        final showNumber =
            number != null &&
            (d % 10 == 0 || _detail) &&
            // يُحذف ٣٠ إن كان على بعد أقل من 8dp من حد الشهر.
            ((m.length - d) * pxPerDay - number.width / 2 >= 8);
        if (showNumber) {
          _tangential(canvas, number, a, (bo + bi) / 2);
          continue;
        }
        canvas.drawLine(
          _polar(a, bo),
          _polar(a, bo - (five ? 6 : 3)),
          five ? long : small,
        );
      }
    }
  }

  /// C: الدرور بتعبئات مئاتها المعتمة، وأسماؤها (أو أرقامها) شعاعية، وفواصلها،
  /// وتدريج أيام داخلي (R3.1-8).
  void _paintDurur(Canvas canvas, DialGeometry geo) {
    final (co, ci) = geo.band(DialRing.durur);
    final segs = model.cyclicSegments(DialRing.durur);
    for (final s in segs) {
      canvas.drawPath(
        _sector(geo.angleOf(s.start), geo.angleOf(s.end), co, ci),
        Paint()..color = _hundredFills[s.colorSeasonId] ?? _darEmptyFill,
      );
    }
    for (final (i, s) in segs.indexed) {
      final prev = segs[(i - 1 + segs.length) % segs.length];
      final hundred = prev.colorSeasonId != s.colorSeasonId;
      final a = geo.angleOf(s.start);
      canvas.drawLine(
        _polar(a, co),
        _polar(a, ci),
        hundred
            ? _stroke(colors.ink.withValues(alpha: 0.4), 1.5)
            : _stroke(_darSeparator, 1),
      );
    }
    final inner = _stroke(colors.ink.withValues(alpha: 0.25), 1);
    for (var d = 0; d < model.dayCount; d++) {
      final a = geo.angleOf(d);
      canvas.drawLine(_polar(a, ci), _polar(a, ci + 2), inner);
    }
    // قاعدة الاتساع: كل الأسماء أو كل الأرقام، لا خلط.
    final cMid = (co + ci) / 2;
    // القياس على القطع الدائرية: الدَّرّ العابر لنهاية السنة قطعة واحدة،
    // فلا يُحسب نصفاه القصيران «لا يتسع» فتتحول كل الأسماء أرقاماً.
    final plain = model.segments(DialRing.durur);
    int labelOf(DialSegment s) =>
        plain.indexWhere((p) => identical(p.dar, s.dar));
    bool fits(TextPainter t, DialSegment s) =>
        t.width <= (co - ci) * zoom - 4 &&
        t.height <= s.length * geo.step * cMid * zoom;
    final useNames = segs.every((s) => fits(labels.dururNames[labelOf(s)], s));
    for (final s in segs) {
      final i = labelOf(s);
      final t = useNames ? labels.dururNames[i] : labels.dururNumbers[i];
      if (!useNames && !fits(t, s)) continue;
      _radial(canvas, t, geo.angleOf(s.start + s.length / 2), cMid);
    }
  }

  /// D: الطوالع. في الخليج حلقة رفيعة بخلايا ونجمة 8dp (الاسم الحالي يُرسم
  /// مع التمييز)؛ وبلا درور حلقة عريضة بتعبئات المواسم وأسماء شعاعية (R3.10).
  void _paintStars(Canvas canvas, DialGeometry geo) {
    final (so, si) = geo.band(DialRing.stars);
    final segs = model.cyclicSegments(DialRing.stars);
    final wide = !model.hasDurur;
    if (wide) {
      for (final s in segs) {
        canvas.drawPath(
          _sector(geo.angleOf(s.start), geo.angleOf(s.end), so, si),
          Paint()..color = _hundredFills[s.colorSeasonId] ?? _starsFill,
        );
      }
    }
    final sep = _stroke(colors.glassStroke, 1);
    final starSize = wide ? 5.0 : 4.0;
    for (final s in segs) {
      final a = geo.angleOf(s.start);
      canvas.drawLine(_polar(a, so), _polar(a, si), sep);
      final r = so - starSize - 2;
      canvas.drawPath(
        fourPointStar(_polar(a - (starSize + 2) / r, r), starSize),
        Paint()..color = colors.starMark,
      );
    }
    if (!wide) {
      if (zoom < dialAllStarsZoom) return;
      for (final s in model.cyclicSegments(DialRing.stars)) {
        _tangential(
          canvas,
          labels.stars[s.itemId]!,
          geo.angleOf(s.start + s.length / 2),
          (so + si) / 2,
        );
      }
      return;
    }
    if (!_allStarNamesFit(geo)) return;
    for (final s in model.cyclicSegments(DialRing.stars)) {
      _radial(
        canvas,
        labels.stars[s.itemId]!,
        geo.angleOf(s.start + s.length / 2),
        (so + si) / 2,
      );
    }
  }

  /// بلا درور: هل تتسع كل أسماء الطوالع شعاعياً؟ (أو التكبير ≥ 1.6×.)
  bool _allStarNamesFit(DialGeometry geo) {
    if (_detail) return true;
    final (so, si) = geo.band(DialRing.stars);
    final mid = (so + si) / 2;
    for (final s in model.cyclicSegments(DialRing.stars)) {
      final t = labels.stars[s.itemId]!;
      if (t.width > (so - si) * zoom - 4 ||
          t.height > s.length * geo.step * mid * zoom) {
        return false;
      }
    }
    return true;
  }

  /// E: البروج بفواصلها وأسمائها إن اتسعت الخلية (R3.1-10).
  void _paintZodiac(Canvas canvas, DialGeometry geo) {
    final (eo, ei) = geo.band(DialRing.zodiac);
    final sep = _stroke(colors.glassStroke, 1);
    final mid = (eo + ei) / 2;
    for (final s in model.cyclicSegments(DialRing.zodiac)) {
      final a = geo.angleOf(s.start);
      canvas.drawLine(_polar(a, eo), _polar(a, ei), sep);
    }
    for (final s in model.cyclicSegments(DialRing.zodiac)) {
      final t = labels.zodiac[s.zodiac!]!;
      if (!_detail && t.width > s.length * geo.step * mid * zoom - 4) continue;
      _tangential(canvas, t, geo.angleOf(s.start + s.length / 2), mid);
    }
  }

  /// تاريخ بداية الفصل على ذراع الصليب: شعاعي، على بعد 2dp من الذراع في
  /// جهة الفصل الذي يبدأ؛ مختصر إن لم يتسع (R3.2).
  void _paintArmDate(
    Canvas canvas,
    DialGeometry geo,
    AstroSeason season,
    double armAngle,
  ) {
    final (fo, _) = geo.band(DialRing.seasons);
    final hub = geo.hubRadius;
    final arm = (fo - hub) * zoom - 4;
    final full = labels.quarterDates[season];
    final short = labels.quarterDatesShort[season];
    final t = full != null && full.width <= arm ? full : short;
    if (t == null || t.width > arm) return;
    final r = (fo + hub) / 2;
    // الفصل الذي يبدأ يقع بعد الذراع زمنياً، أي بزاوية أصغر.
    final a = armAngle - (2 + t.height / 2) / (r * zoom);
    _radial(canvas, t, a, r);
  }

  // ———— الأجزاء المتغيرة مع اليوم ————

  void _paintSelection(Canvas canvas, DialGeometry geo, double rot, int day) {
    final days = model.index.days;
    final info = days[day];

    // شريحة اليوم عبر الحلقات من B إلى C (أو D مكانها)، cyan 12%.
    final (mo, _) = geo.band(DialRing.months);
    final inner = geo.band(model.hasDurur ? DialRing.durur : DialRing.stars).$2;
    final a = geo.centerAngle(rot);
    canvas.drawPath(
      _sector(a + geo.step / 2, a - geo.step / 2, mo, inner),
      Paint()..color = colors.primary.withValues(alpha: 0.12),
    );

    void outline(DialRing ring, int start, int end, double width) {
      final (o, i) = geo.band(ring);
      final path = _sector(geo.angleOf(start), geo.angleOf(end), o - 1, i + 1);
      canvas.drawPath(path, _glow(colors.primary, 3, 0.5, width));
      canvas.drawPath(path, _stroke(colors.primary, width));
    }

    // الدَّرّ الحالي، والطالع الحالي: حد cyan 2dp مع توهج 1.
    final dar = info.dar;
    if (dar != null) {
      outline(
        DialRing.durur,
        _dayIndex(dar.start),
        _dayIndex(dar.end) + 1,
        2,
      );
    }
    final star = info.star;
    final starStart = _dayIndex(star.start);
    final starEnd = _dayIndex(star.end) + 1;
    outline(DialRing.stars, starStart, starEnd, 2);
    if (model.hasDurur) {
      // اسم الطالع الحالي على طول القوس، ويمتد على الخلايا المجاورة.
      final t = labels.stars[star.itemId];
      if (t != null && zoom < dialAllStarsZoom) {
        final (so, si) = geo.band(DialRing.stars);
        final mid = (so + si) / 2;
        final center = (starStart + starEnd) / 2;
        final back = Paint()..color = _starsFill;
        final half = (t.width / 2 + 3) / (mid * zoom);
        canvas.drawPath(
          _sector(
            geo.angleOf(center) + half,
            geo.angleOf(center) - half,
            so - 1.5,
            si + 1.5,
          ),
          back,
        );
        _tangential(canvas, t, geo.angleOf(center), mid);
      }
    } else if (!_allStarNamesFit(geo)) {
      // بلا درور ولم تتسع الأسماء: الحالي وسهيل والثريا (R3.10).
      final (so, si) = geo.band(DialRing.stars);
      for (final s in model.cyclicSegments(DialRing.stars)) {
        final id = s.itemId!;
        if (id != star.itemId && !labels.heliacal.contains(id)) continue;
        _radial(
          canvas,
          labels.stars[id]!,
          geo.angleOf(s.start + s.length / 2),
          (so + si) / 2,
        );
      }
    }

    // البرج الحالي: اسمه ink وحد cyan 1.5dp.
    final zodiac = model.segmentAt(DialRing.zodiac, day);
    if (zodiac != null) {
      final period = model.astro.zodiacAt(_localOf(day));
      final start = model.dayIndexOf(period.start.day);
      final end = model.dayIndexOf(period.end.day);
      final (eo, ei) = geo.band(DialRing.zodiac);
      final mid = (eo + ei) / 2;
      final t = labels.zodiacCurrent[period.value]!;
      final center = (start + end) / 2;
      canvas.drawPath(
        _sector(geo.angleOf(start), geo.angleOf(end), eo - 1, ei + 1),
        Paint()..color = _zodiacFill,
      );
      _tangential(canvas, t, geo.angleOf(center), mid);
      final path = _sector(geo.angleOf(start), geo.angleOf(end), eo - 1, ei + 1);
      canvas.drawPath(path, _stroke(colors.primary, 1.5));
    }
  }

  /// F: ربع الفصل الحالي بتعبئته، وأسماء الفصول وأسماؤها التراثية أفقية في
  /// مركز ثقل كل ربع على 0.6 من نصف قطر المركز، وقوس التقدّم (R3.2).
  void _paintCenter(Canvas canvas, DialGeometry geo, int day) {
    final (fo, _) = geo.band(DialRing.seasons);
    final hub = geo.hubRadius;
    final current = model.astro.seasonAt(_localOf(day));
    final cStart = model.dayIndexOf(current.start.day);
    final cEnd = model.dayIndexOf(current.end.day);
    canvas.drawPath(
      _sector(geo.angleOf(cStart), geo.angleOf(cEnd), fo - 0.75, hub + 1),
      Paint()..color = _currentQuarterFill,
    );
    // الصليب فوق التعبئة.
    final cross = _stroke(colors.primary.withValues(alpha: 0.7), 1.5);
    for (final d in [cStart, cEnd]) {
      final a = geo.angleOf(d);
      canvas.drawLine(_polar(a, hub), _polar(a, fo), cross);
    }

    final r = 0.6 * fo;
    for (final s in model.cyclicSegments(DialRing.seasons)) {
      final season = s.astroSeason!;
      final isCurrent = season == current.value;
      final name = (isCurrent
          ? labels.quarterNamesCurrent
          : labels.quarterNames)[season]!;
      final heritage = (isCurrent
          ? labels.heritageCurrent
          : labels.heritage)[season];
      final (x, y) = DialGeometry.polar(
        geo.angleOf(s.start + s.length / 2),
        r,
      );
      final chord = r * math.sqrt2 * zoom; // عرض تقريبي متاح في الربع
      final showHeritage =
          heritage != null && heritage.width <= chord && name.width <= chord;
      final total = name.height + (showHeritage ? heritage.height : 0);
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(1 / zoom);
      name.paint(canvas, Offset(-name.width / 2, -total / 2));
      if (showHeritage) {
        heritage.paint(
          canvas,
          Offset(-heritage.width / 2, -total / 2 + name.height),
        );
      }
      canvas.restore();
    }

    // قوس التقدّم: 4dp cyan بتوهج 2، من بداية الفصل الحالي إلى العقرب.
    final a0 = geo.angleOf(cStart);
    final a1 = geo.centerAngle(rotation.value);
    if (a0 > a1) {
      final arc = Path()
        ..addArc(
          Rect.fromCircle(center: Offset.zero, radius: geo.progressRadius),
          a1 - math.pi / 2,
          a0 - a1,
        );
      canvas.drawPath(
        arc,
        _glow(colors.primary, 6, 0.7, 4)..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        arc,
        _stroke(colors.primary, 4)..strokeCap = StrokeCap.round,
      );
    }
  }

  /// العقرب المدبب من المحور إلى حافة المركز، والخط الرفيع إلى 0.69R،
  /// والمثلث ونقطة gold على رأسه (R3.1-11).
  void _paintPointer(Canvas canvas, DialGeometry geo, double rot) {
    final a = geo.centerAngle(rot);
    final (fo, _) = geo.band(DialRing.seasons);
    final lineEnd = DialGeometry.needleLineFraction * radius;
    canvas.save();
    canvas.rotate(a);
    // الخط الرفيع.
    final line = Path()
      ..moveTo(0, -fo)
      ..lineTo(0, -lineEnd + 8);
    canvas.drawPath(line, _stroke(colors.primary.withValues(alpha: 0.8), 1.5));
    // العقرب: قاعدة 6dp ورأس 1.5dp، تدرّج ink←cyan، توهج 2.
    final needle = Path()
      ..moveTo(-3, 0)
      ..lineTo(-0.75, -fo)
      ..lineTo(0.75, -fo)
      ..lineTo(3, 0)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..color = colors.primary.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      needle,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, -fo), [
          colors.ink,
          colors.primary,
        ]),
    );
    // المثلث على الحافة الخارجية لحلقة الدرور (أو الطوالع مكانها).
    final tri = Path()
      ..moveTo(0, -lineEnd + 9)
      ..lineTo(-5, -lineEnd)
      ..lineTo(5, -lineEnd)
      ..close();
    canvas.drawPath(tri, Paint()..color = colors.ink);
    canvas.drawCircle(Offset(0, -lineEnd - 2), 2, Paint()..color = colors.goldDeco);
    canvas.restore();
    // المحور فوق قاعدة العقرب.
    final hub = geo.hubRadius;
    canvas.drawCircle(
      Offset.zero,
      hub - 1,
      Paint()
        ..shader = ui.Gradient.radial(Offset(0, -hub * 0.3), hub * 1.2, const [
          Color(0xFF2B4F5E),
          Color(0xFF0E2533),
        ]),
    );
    canvas.drawCircle(
      Offset.zero,
      hub,
      _stroke(colors.primary.withValues(alpha: 0.6), 2),
    );
    canvas.drawCircle(Offset.zero, 2.5, Paint()..color = colors.ink);
  }

  // ———— أدوات ————

  /// اليوم المحلي (منتصف الليل) لفهرس في السنة.
  DateTime _localOf(int day) => DateTime(model.year, 1, 1 + day);

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

  /// قطاع حلقي بين زاويتين (بأي ترتيب).
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

  /// نص شعاعي: في النصف الأيمن يُقرأ من الخارج إلى الداخل، وفي الأيسر من
  /// الداخل إلى الخارج (R3.1-8)، فيبقى قائماً تقريباً.
  void _radial(Canvas canvas, TextPainter text, double angle, double r) {
    final (x, y) = DialGeometry.polar(angle, r);
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(
      math.sin(angle) >= 0 ? angle - math.pi / 2 : angle + math.pi / 2,
    );
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
