import 'dart:math' as math;

import '../../../domain/day_info.dart';
import '../../../domain/region_table.dart';
import '../../../engine/year_index.dart';

/// حلقات الدائرة من الخارج إلى الداخل (DESIGN R2.5): مواسم الجو ورموزه (A)،
/// الأشهر (B)، الدرور (C)، الطوالع (D)، والمواسم الأربعة في المركز (F).
/// حلقة الزراعة (E) مكانها محجوز في [DialGeometry] وتُخفى بلا بيانات (R2.7).
enum DialRing { weather, months, durur, stars, seasons }

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
  });

  final DialRing ring;

  /// أول يوم (فهرس من 0 = 1 يناير).
  final int start;
  final int length;

  /// عنصر الموسم أو النجم أو موسم الجو.
  final String? itemId;

  /// سجل الدَّرّ (حلقة الدرور).
  final DarRecord? dar;

  /// الموسم الكبير الذي يحدد لون القطعة (DESIGN R2.2).
  final String? colorSeasonId;

  /// الشهر 1–12 (حلقة الأشهر).
  final int? month;

  /// أول يوم بعد القطعة (غير شامل).
  int get end => start + length;

  bool contains(int day) => day >= start && day < end;
}

/// قطع حلقات الدائرة لسنة واحدة، مبنية من [YearIndex] (Dart صافٍ).
/// الفترة التي تعبر نهاية السنة تظهر قطعتين: في أولها وآخرها.
class DialModel {
  DialModel._(this.index, this.months, this.rings);

  factory DialModel.fromYearIndex(YearIndex index) {
    final days = index.days;
    final months = <DialSegment>[];
    for (var m = 1; m <= 12; m++) {
      final start = DateTime.utc(
        index.year,
        m,
      ).difference(DateTime.utc(index.year)).inDays;
      final next = DateTime.utc(
        index.year,
        m + 1,
      ).difference(DateTime.utc(index.year)).inDays;
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
      for (var i = 1; i <= days.length; i++) {
        final a = periodOf(days[start]);
        final b = i < days.length ? periodOf(days[i]) : null;
        final same =
            i < days.length &&
            (a == null) == (b == null) &&
            (a == null || a.start == b!.start);
        if (same) continue;
        if (a != null) out.add(make(days[start], start, i - start));
        start = i;
      }
      return out;
    }

    String? seasonAt(int day) => days[day].majorSeason.itemId;

    return DialModel._(index, months, {
      // مواسم الجو بنغمة الموسم الكبير الذي تقع فيه (منتصفها)، والفراغات بلا قطع.
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
      // الدرور تُلوَّن بمئتها (seasonId، D25).
      DialRing.durur: group(
        (d) => d.dar,
        (d, s, l) => DialSegment(
          ring: DialRing.durur,
          start: s,
          length: l,
          dar: d.dar.record,
          colorSeasonId: d.dar.record.seasonId,
        ),
      ),
      DialRing.stars: group(
        (d) => d.star,
        (d, s, l) => DialSegment(
          ring: DialRing.stars,
          start: s,
          length: l,
          itemId: d.star.itemId,
          colorSeasonId: seasonAt(s),
        ),
      ),
      DialRing.seasons: group(
        (d) => d.majorSeason,
        (d, s, l) => DialSegment(
          ring: DialRing.seasons,
          start: s,
          length: l,
          itemId: d.majorSeason.itemId,
          colorSeasonId: d.majorSeason.itemId,
        ),
      ),
    });
  }

  final YearIndex index;
  final List<DialSegment> months;
  final Map<DialRing, List<DialSegment>> rings;

  int get year => index.year;
  int get dayCount => index.length;

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

  /// فهرس اليوم في السنة (0 = 1 يناير) لتاريخ من هذه السنة.
  int dayIndexOf(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(year)).inDays;
}

/// نتيجة اللمس على الدائرة.
sealed class DialHit {
  const DialHit();
}

/// المحور (المقبض في المركز، G).
class HubHit extends DialHit {
  const HubHit();
}

/// حلقة ويوم (فهرس في السنة).
class RingHit extends DialHit {
  const RingHit(this.ring, this.day);

  final DialRing ring;
  final int day;
}

/// هندسة الدائرة (DESIGN R2.5): أنصاف أقطار الحلقات كنسبة من نصف القطر R،
/// وتحويل اليوم إلى زاوية واللمس إلى (حلقة، يوم).
///
/// الزوايا مع عقارب الساعة من الأعلى (موضع الساعة 12)، والزمن يتقدّم مع
/// عقارب الساعة. [rotation] = فهرس اليوم (قد يكون كسرياً أثناء السحب) الواقع
/// تحت الإبرة في الأعلى.
class DialGeometry {
  const DialGeometry({
    required this.radius,
    required this.dayCount,
    this.agri = false,
  });

  /// حدود الحلقات من الخارج إلى الداخل (نسبة من R) بلا حلقة زراعة.
  static const Map<DialRing, (double outer, double inner)> bands = {
    DialRing.weather: (1.00, 0.87),
    DialRing.months: (0.87, 0.73),
    DialRing.durur: (0.73, 0.58),
    DialRing.stars: (0.58, 0.43),
    DialRing.seasons: (0.43, 0.13),
  };

  /// حلقة الزراعة E (R2.7) حين توجد بيانات معتمدة: الطوالع تنتهي عند 0.45،
  /// والمركز يبدأ من 0.36.
  static const (double, double) agriBandFraction = (0.45, 0.36);

  /// المقبض (المحور G).
  static const double hubFraction = 0.13;

  final double radius;
  final int dayCount;

  /// هل تُرسم حلقة الزراعة؟ (لا بيانات زراعية معتمدة بعد، فهي مخفية.)
  final bool agri;

  double scale(double fraction) => fraction * radius;

  (double outer, double inner) band(DialRing ring) {
    var (o, i) = bands[ring]!;
    if (agri && ring == DialRing.stars) i = agriBandFraction.$1;
    if (agri && ring == DialRing.seasons) o = agriBandFraction.$2;
    return (o * radius, i * radius);
  }

  /// حلقة الزراعة بالـ dp، أو null إن كانت مخفية.
  (double outer, double inner)? get agriBand => agri
      ? (agriBandFraction.$1 * radius, agriBandFraction.$2 * radius)
      : null;

  double get hubRadius => hubFraction * radius;

  /// منتصف الحلقة A حيث تُرسم رموز الجو وأسماء مواسمه.
  double get weatherMid {
    final (o, i) = band(DialRing.weather);
    return (o + i) / 2;
  }

  /// نصف قطر قوس تقدّم الموسم (حد المركز الخارجي − 3dp).
  double get progressRadius => band(DialRing.seasons).$1 - 3;

  /// زاوية يوم واحد بالراديان.
  double get step => 2 * math.pi / dayCount;

  /// زاوية بداية اليوم [day] مع عقارب الساعة من الأعلى، حين يكون اليوم
  /// [rotation] تحت المؤشر (منتصف شريحته في الأعلى).
  double angleOf(num day, double rotation) => (day - rotation - 0.5) * step;

  /// نقطة بزاوية [angle] مع عقارب الساعة من الأعلى ونصف قطر [r]
  /// (بالنسبة للمركز، y للأسفل).
  static (double x, double y) polar(double angle, double r) =>
      (r * math.sin(angle), -r * math.cos(angle));

  /// يحوّل نقطة (بالنسبة لمركز الدائرة) إلى حلقة ويوم، أو null خارج الدائرة
  /// أو على حلقة الزراعة المخفية.
  DialHit? hitTest(double dx, double dy, double rotation) {
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > radius) return null;
    if (distance <= hubRadius) return const HubHit();
    DialRing? ring;
    for (final r in DialRing.values) {
      final (outer, inner) = band(r);
      if (distance <= outer && distance > inner) {
        ring = r;
        break;
      }
    }
    if (ring == null) return null;
    // atan2(dx, -dy): الزاوية مع عقارب الساعة من الأعلى (y للأسفل).
    var theta = math.atan2(dx, -dy);
    if (theta < 0) theta += 2 * math.pi;
    final day = (theta / step + rotation + 0.5).floor() % dayCount;
    return RingHit(ring, day);
  }
}
