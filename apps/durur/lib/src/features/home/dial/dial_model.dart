import 'dart:math' as math;

import '../../../astronomy/seasons.dart';
import '../../../domain/day_info.dart';
import '../../../domain/item.dart';
import '../../../domain/region_table.dart';
import '../../../domain/weather_symbol.dart';
import '../../../engine/year_index.dart';

/// حلقات الدائرة من الخارج إلى الداخل (DESIGN R3.1-4): الإطار ورموز الجو
/// ومواسمه (A)، الأشهر (B)، تدريج الأيام (B2)، الدرور (C)، الطوالع (D)،
/// البروج (E)، والفصول الأربعة في المركز (F). في منطقة بلا درور (R3.10)
/// لا حلقة C، وتأخذ الطوالع مكانها. [majorSeason] ليس حلقة مرسومة: هدف
/// «افتح صفحة الموسم» (الموسم الكبير التراثي) من قارئ الشاشة والبطاقات.
enum DialRing {
  weather,
  months,
  days,
  durur,
  stars,
  zodiac,
  seasons,
  majorSeason,
}

/// قطعة في حلقة: مدى أيام متصل داخل السنة المعروضة.
class DialSegment {
  const DialSegment({
    required this.ring,
    required this.start,
    required this.length,
    this.itemId,
    this.dar,
    this.colorSeasonId,
    this.month,
    this.astroSeason,
    this.zodiac,
  });

  final DialRing ring;

  /// أول يوم (فهرس من 0 = 1 يناير).
  final int start;
  final int length;

  /// عنصر الموسم أو النجم أو موسم الجو.
  final String? itemId;

  /// سجل الدَّرّ (حلقة الدرور).
  final DarRecord? dar;

  /// الموسم الكبير الذي يحدد لون القطعة (مئة الدَّرّ، أو موسم الطالع).
  final String? colorSeasonId;

  /// الشهر 1–12 (حلقة الأشهر).
  final int? month;

  /// الفصل الفلكي (المركز).
  final AstroSeason? astroSeason;

  /// البرج (حلقة البروج).
  final ZodiacSign? zodiac;

  /// أول يوم بعد القطعة (غير شامل).
  int get end => start + length;

  bool contains(int day) => day >= start && day < end;
}

/// خلية رموز الجو في الإطار (R3.1-5): خلية لكل دَرّ، أو لكل طالع في منطقة
/// بلا درور (R3.10). [symbol] الرمز الأول من `weather` (قد يكون null).
class WeatherCell {
  const WeatherCell({
    required this.start,
    required this.length,
    required this.symbols,
    this.dar,
    this.starItemId,
  });

  /// أول يوم (قد يكون سالباً أو بعد نهاية السنة إن عبرت الخلية حدّها).
  final int start;
  final int length;

  /// كل رموز الدَّرّ أو الطالع (للفقاعة).
  final List<WeatherSymbol> symbols;
  final DarRecord? dar;
  final String? starItemId;

  WeatherSymbol? get symbol => symbols.isEmpty ? null : symbols.first;

  double get center => start + length / 2;
  int get end => start + length;
}

/// قطع حلقات الدائرة لسنة واحدة، مبنية من [YearIndex] والحساب الفلكي
/// [AstroYear] (Dart صافٍ). الفترة التي تعبر نهاية السنة تظهر قطعتين.
class DialModel {
  DialModel._(
    this.index,
    this.astro,
    this.months,
    this.rings,
    this.cells,
    this.hasDurur,
  );

  factory DialModel.fromYearIndex(
    YearIndex index, {
    required AstroYear astro,
    Map<String, Item> items = const {},
  }) {
    final days = index.days;
    final n = days.length;
    int dayOf(DateTime d) => DateTime.utc(
      d.year,
      d.month,
      d.day,
    ).difference(DateTime.utc(index.year)).inDays;

    final months = <DialSegment>[];
    for (var m = 1; m <= 12; m++) {
      final start = dayOf(DateTime(index.year, m));
      final next = dayOf(DateTime(index.year, m + 1));
      months.add(
        DialSegment(
          ring: DialRing.months,
          start: start,
          length: next - start,
          month: m,
        ),
      );
    }

    List<DialSegment> group(
      ActivePeriod? Function(DayInfo) periodOf,
      DialSegment Function(DayInfo first, int start, int length) make,
    ) {
      final out = <DialSegment>[];
      var start = 0;
      for (var i = 1; i <= n; i++) {
        final a = periodOf(days[start]);
        final b = i < n ? periodOf(days[i]) : null;
        final same =
            i < n &&
            (a == null) == (b == null) &&
            (a == null || a.start == b!.start);
        if (same) continue;
        if (a != null) out.add(make(days[start], start, i - start));
        start = i;
      }
      return out;
    }

    String? seasonAt(int day) => days[day.clamp(0, n - 1)].majorSeason.itemId;
    final hasDurur = days.first.dar != null;

    // فترات فلكية بأيام محلية ← قطع داخل السنة (مقصوصة على حدّيها).
    List<DialSegment> astroSegments<T>(
      List<AstroPeriod<T>> periods,
      DialRing ring,
      DialSegment Function(T value, int start, int length) make,
    ) => [
      for (final p in periods)
        if (math.max(0, dayOf(p.start.day)) <
            math.min(n, dayOf(p.end.day)))
          make(
            p.value,
            math.max(0, dayOf(p.start.day)),
            math.min(n, dayOf(p.end.day)) - math.max(0, dayOf(p.start.day)),
          ),
    ];

    final durur = hasDurur
        ? group(
            (d) => d.dar,
            (d, s, l) => DialSegment(
              ring: DialRing.durur,
              start: s,
              length: l,
              dar: d.dar!.record,
              colorSeasonId: d.dar!.record.seasonId,
            ),
          )
        : const <DialSegment>[];
    final stars = group(
      (d) => d.star,
      (d, s, l) => DialSegment(
        ring: DialRing.stars,
        start: s,
        length: l,
        itemId: d.star.itemId,
        colorSeasonId: seasonAt(s + l ~/ 2),
      ),
    );

    // خلايا الإطار: فترة الدَّرّ (أو الطالع) كاملةً حتى لو عبرت نهاية السنة،
    // فلا تُقسم الخلية عند 1 يناير.
    final cells = <WeatherCell>[];
    final seen = <DateTime>{};
    for (final d in days) {
      final ActivePeriod period = d.dar ?? d.star;
      if (!seen.add(period.start)) continue;
      final start = dayOf(period.start);
      cells.add(
        WeatherCell(
          start: start,
          length: period.length,
          symbols: d.dar?.record.weather ??
              items[d.star.itemId]?.weather ??
              d.starWeather,
          dar: d.dar?.record,
          starItemId: d.dar == null ? d.star.itemId : null,
        ),
      );
    }
    // آخر فترة قد تكون بدأت في السنة السابقة وتتكرر في آخر السنة: تُترك
    // الخليتان (تتطابقان زاوياً بعد الالتفاف) إلا إن كانتا الفترة نفسها.
    if (cells.length > 1 &&
        cells.first.start < 0 &&
        cells.last.end > n &&
        cells.first.start + n == cells.last.start) {
      cells.removeLast();
    }

    return DialModel._(
      index,
      astro,
      months,
      {
        DialRing.weather: group(
          (d) => d.weatherSeason,
          (d, s, l) => DialSegment(
            ring: DialRing.weather,
            start: s,
            length: l,
            itemId: d.weatherSeason!.itemId,
            colorSeasonId: seasonAt(s + l ~/ 2),
          ),
        ),
        DialRing.months: months,
        DialRing.days: months,
        DialRing.durur: durur,
        DialRing.stars: stars,
        DialRing.zodiac: astroSegments(
          astro.zodiac,
          DialRing.zodiac,
          (z, s, l) => DialSegment(
            ring: DialRing.zodiac,
            start: s,
            length: l,
            zodiac: z,
          ),
        ),
        DialRing.seasons: astroSegments(
          astro.seasons,
          DialRing.seasons,
          (season, s, l) => DialSegment(
            ring: DialRing.seasons,
            start: s,
            length: l,
            astroSeason: season,
          ),
        ),
      },
      List.unmodifiable(cells),
      hasDurur,
    );
  }

  final YearIndex index;
  final AstroYear astro;
  final List<DialSegment> months;
  final Map<DialRing, List<DialSegment>> rings;

  /// خلايا رموز الجو في الإطار.
  final List<WeatherCell> cells;

  /// هل للمنطقة درور؟ (لا درور في السعودية، R3.10.)
  final bool hasDurur;

  int get year => index.year;
  int get dayCount => index.length;

  /// فهرس 21 ديسمبر، المثبّت عند الساعة 6 (R3.1-3).
  int get decemberSolsticeAnchor => dayIndexOf(DateTime(year, 12, 21));

  List<DialSegment> segments(DialRing ring) => rings[ring]!;

  /// قطع [ring] بعد دمج القطعتين اللتين تعبران نهاية السنة لنفس الفترة،
  /// فتصبح فترة واحدة دائرية (قد يتجاوز `end` طول السنة).
  List<DialSegment> cyclicSegments(DialRing ring) {
    final segs = rings[ring]!;
    if (segs.length < 2) return segs;
    final first = segs.first;
    final last = segs.last;
    final samePeriod = first.dar != null
        ? identical(first.dar, last.dar)
        : first.astroSeason != null
        ? first.astroSeason == last.astroSeason
        : first.zodiac != null
        ? first.zodiac == last.zodiac
        : first.itemId != null && first.itemId == last.itemId;
    if (first.start != 0 || last.end != dayCount || !samePeriod) return segs;
    return [
      for (final s in segs.sublist(1, segs.length - 1)) s,
      DialSegment(
        ring: ring,
        start: last.start,
        length: last.length + first.length,
        itemId: last.itemId,
        dar: last.dar,
        colorSeasonId: last.colorSeasonId,
        month: last.month,
        astroSeason: last.astroSeason,
        zodiac: last.zodiac,
      ),
    ];
  }

  /// القطعة في [ring] التي تحتوي اليوم [day]، أو null (فراغ مواسم الجو).
  DialSegment? segmentAt(DialRing ring, int day) {
    for (final s in rings[ring]!) {
      if (s.contains(day)) return s;
    }
    return null;
  }

  /// خلية الإطار التي تحتوي اليوم [day] (فهرس في السنة).
  WeatherCell? cellAt(int day) {
    for (final c in cells) {
      for (final shift in [0, dayCount, -dayCount]) {
        final d = day + shift;
        if (d >= c.start && d < c.end) return c;
      }
    }
    return null;
  }

  /// فهرس اليوم في السنة (0 = 1 يناير) لتاريخ من هذه السنة.
  int dayIndexOf(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(year)).inDays;

  /// الموسم الكبير (التراثي) الذي يحتوي منتصف الفصل الفلكي [season] في هذه
  /// السنة (R3.2)، أو null إن لم يكن للتقويم مواسم كبيرة.
  String? heritageFor(DialSegment season) {
    final period = astro.seasons.firstWhere(
      (p) =>
          p.value == season.astroSeason &&
          dayIndexOf(p.end.day) > season.start &&
          dayIndexOf(p.start.day) <= season.start,
      orElse: () => astro.seasons.firstWhere(
        (p) => p.value == season.astroSeason,
      ),
    );
    final mid =
        (dayIndexOf(period.start.day) + dayIndexOf(period.end.day)) ~/ 2;
    // الجدول دوري سنوياً: منتصف الشتاء (فبراير التالي) يُقرأ من فبراير هذه
    // السنة.
    final i = ((mid % dayCount) + dayCount) % dayCount;
    return index.days[i].majorSeason.itemId;
  }
}

/// نتيجة اللمس على الدائرة.
sealed class DialHit {
  const DialHit();
}

/// المحور (G).
class HubHit extends DialHit {
  const HubHit();
}

/// حلقة ويوم (فهرس في السنة).
class RingHit extends DialHit {
  const RingHit(this.ring, this.day);

  final DialRing ring;
  final int day;
}

/// هندسة الدائرة (DESIGN R3.1-4 وR3.10): أنصاف أقطار الحلقات كنسبة من R،
/// وتحويل اليوم إلى زاوية واللمس إلى (حلقة، يوم).
///
/// القرص ثابت (R3.1-3، D41): الزوايا مع عقارب الساعة من الأعلى (الساعة 12)،
/// والزمن يتقدّم **عكس** عقارب الساعة، ومنتصف 21 ديسمبر ([anchor] − 0.5)
/// عند الساعة 6. كل يوم 360° ÷ طول السنة.
class DialGeometry {
  const DialGeometry({
    required this.radius,
    required this.dayCount,
    required this.anchor,
    this.hasDurur = true,
  });

  /// الهندسة لنموذج.
  factory DialGeometry.of(DialModel model, double radius) => DialGeometry(
    radius: radius,
    dayCount: model.dayCount,
    anchor: model.decemberSolsticeAnchor,
    hasDurur: model.hasDurur,
  );

  /// حدود الحلقات في الخليج (R3.1-4، نسبة من R).
  static const Map<DialRing, (double outer, double inner)> gulfBands = {
    DialRing.weather: (1.00, 0.88),
    DialRing.months: (0.88, 0.76),
    DialRing.days: (0.76, 0.69),
    DialRing.durur: (0.69, 0.49),
    DialRing.stars: (0.49, 0.42),
    DialRing.zodiac: (0.42, 0.34),
    DialRing.seasons: (0.34, 0.07),
  };

  /// حدود الحلقات في منطقة بلا درور (R3.10): الطوالع مكان الدرور.
  static const Map<DialRing, (double outer, double inner)> noDururBands = {
    DialRing.weather: (1.00, 0.88),
    DialRing.months: (0.88, 0.76),
    DialRing.days: (0.76, 0.69),
    DialRing.stars: (0.69, 0.51),
    DialRing.zodiac: (0.51, 0.40),
    DialRing.seasons: (0.40, 0.07),
  };

  /// المحور G (قطره 28dp على 412).
  static const double hubFraction = 0.07;

  /// الحافة الخارجية لحلقة الدرور (أو الطوالع مكانها): حد الخط الرفيع
  /// للعقرب وموضع المثلث (R3.1-11).
  static const double needleLineFraction = 0.69;

  final double radius;
  final int dayCount;

  /// فهرس 21 ديسمبر في السنة.
  final int anchor;
  final bool hasDurur;

  Map<DialRing, (double, double)> get bands =>
      hasDurur ? gulfBands : noDururBands;

  /// الحلقات المرسومة بترتيبها من الخارج.
  List<DialRing> get rings => bands.keys.toList();

  double scale(double fraction) => fraction * radius;

  (double outer, double inner) band(DialRing ring) {
    final (o, i) = bands[ring] ?? (0, 0);
    return (o * radius, i * radius);
  }

  double get hubRadius => hubFraction * radius;

  /// منتصف الإطار A حيث تُرسم رموز الجو وأسماء مواسمه.
  double get weatherMid {
    final (o, i) = band(DialRing.weather);
    return (o + i) / 2;
  }

  /// نصف قطر قوس التقدّم (حافة المركز − 3dp).
  double get progressRadius => band(DialRing.seasons).$1 - 3;

  /// زاوية يوم واحد بالراديان.
  double get step => 2 * math.pi / dayCount;

  /// زاوية الموضع [day] (فهرس يوم، كسري مسموح؛ بداية اليوم d عند d) مع
  /// عقارب الساعة من الأعلى. تتناقص مع الزمن (عكس عقارب الساعة).
  double angleOf(num day) => math.pi - (day - (anchor + 0.5)) * step;

  /// زاوية منتصف اليوم [day].
  double centerAngle(num day) => angleOf(day + 0.5);

  /// فهرس اليوم (كسري) عند الزاوية [theta] (مع عقارب الساعة من الأعلى)،
  /// في المدى [0، dayCount).
  double dayAtAngle(double theta) {
    final d = anchor + 0.5 + (math.pi - theta) / step;
    final r = d % dayCount;
    return r < 0 ? r + dayCount : r;
  }

  /// نقطة بزاوية [angle] ونصف قطر [r] (بالنسبة للمركز، y للأسفل).
  static (double x, double y) polar(double angle, double r) =>
      (r * math.sin(angle), -r * math.cos(angle));

  /// زاوية نقطة (بالنسبة للمركز) مع عقارب الساعة من الأعلى في [0، 2π).
  static double angleAt(double dx, double dy) {
    var theta = math.atan2(dx, -dy);
    if (theta < 0) theta += 2 * math.pi;
    return theta;
  }

  /// يحوّل نقطة (بالنسبة لمركز الدائرة) إلى حلقة ويوم، أو null خارجها.
  DialHit? hitTest(double dx, double dy) {
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > radius) return null;
    // منطقة لمس المحور 48dp (R3.1-11).
    if (distance <= math.max(hubRadius, 24)) return const HubHit();
    DialRing? ring;
    for (final MapEntry(key: r, value: (o, i)) in bands.entries) {
      if (distance <= o * radius && distance > i * radius) {
        ring = r;
        break;
      }
    }
    if (ring == null) return null;
    final day = dayAtAngle(angleAt(dx, dy)).floor() % dayCount;
    return RingHit(ring, day);
  }
}
