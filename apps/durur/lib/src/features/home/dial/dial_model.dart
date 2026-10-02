import 'dart:math' as math;

import '../../../domain/day_info.dart';
import '../../../domain/region_table.dart';
import '../../../engine/year_index.dart';

/// حلقات الدائرة من الخارج إلى الداخل (DESIGN 7.2).
enum DialRing { months, seasons, durur, stars, weather }

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

  /// الموسم الكبير الذي يحدد لون القطعة (DESIGN 2.3–2.4).
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
      DialRing ring,
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
      DialRing.months: months,
      DialRing.seasons: group(
        DialRing.seasons,
        (d) => d.majorSeason,
        (d, s, l) => DialSegment(
          ring: DialRing.seasons,
          start: s,
          length: l,
          itemId: d.majorSeason.itemId,
          colorSeasonId: d.majorSeason.itemId,
        ),
      ),
      // الدرور تُلوَّن بمئتها (seasonId، D25).
      DialRing.durur: group(
        DialRing.durur,
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
        DialRing.stars,
        (d) => d.star,
        (d, s, l) => DialSegment(
          ring: DialRing.stars,
          start: s,
          length: l,
          itemId: d.star.itemId,
          colorSeasonId: seasonAt(s),
        ),
      ),
      // مواسم الجو بلون الموسم الكبير الذي تقع فيه (منتصفها)، والفراغات بلا قطع.
      DialRing.weather: group(
        DialRing.weather,
        (d) => d.weatherSeason,
        (d, s, l) => DialSegment(
          ring: DialRing.weather,
          start: s,
          length: l,
          itemId: d.weatherSeason!.itemId,
          colorSeasonId: seasonAt(s + l ~/ 2),
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

/// المحور (المركز).
class HubHit extends DialHit {
  const HubHit();
}

/// حلقة ويوم (فهرس في السنة).
class RingHit extends DialHit {
  const RingHit(this.ring, this.day);

  final DialRing ring;
  final int day;
}

/// هندسة الدائرة (DESIGN 7.2): أنصاف أقطار الحلقات بالنسبة لدائرة مرجعية
/// نصف قطرها 170، وتحويل اليوم إلى زاوية واللمس إلى (حلقة، يوم).
///
/// الزوايا مع عقارب الساعة من الأعلى (موضع الساعة 12)، والزمن يتقدّم مع
/// عقارب الساعة. [rotation] = فهرس اليوم (قد يكون كسرياً أثناء السحب) الواقع
/// تحت المؤشر في الأعلى.
class DialGeometry {
  const DialGeometry({required this.radius, required this.dayCount});

  static const double refRadius = 170;

  /// الحدود من الخارج إلى الداخل بالقياس المرجعي.
  static const Map<DialRing, (double outer, double inner)> refBands = {
    DialRing.months: (170, 146),
    DialRing.seasons: (146, 130),
    DialRing.durur: (130, 102),
    DialRing.stars: (102, 78),
    DialRing.weather: (78, 60),
  };
  static const double refHub = 58;

  final double radius;
  final int dayCount;

  double scale(double ref) => ref / refRadius * radius;

  (double outer, double inner) band(DialRing ring) {
    final (o, i) = refBands[ring]!;
    return (scale(o), scale(i));
  }

  double get hubRadius => scale(refHub);

  /// زاوية يوم واحد بالراديان.
  double get step => 2 * math.pi / dayCount;

  /// زاوية بداية اليوم [day] مع عقارب الساعة من الأعلى، حين يكون اليوم
  /// [rotation] تحت المؤشر (منتصف شريحته في الأعلى).
  double angleOf(num day, double rotation) => (day - rotation - 0.5) * step;

  /// يحوّل نقطة (بالنسبة لمركز الدائرة) إلى حلقة ويوم، أو null خارج الدائرة.
  DialHit? hitTest(double dx, double dy, double rotation) {
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > radius) return null;
    if (distance <= scale(59)) return const HubHit();
    DialRing? ring;
    for (final e in refBands.entries) {
      if (distance <= scale(e.value.$1) && distance > scale(e.value.$2)) {
        ring = e.key;
        break;
      }
    }
    // الفاصل الرفيع بين المحور وحلقة مواسم الجو يتبع الحلقة.
    ring ??= DialRing.weather;
    // atan2(dx, -dy): الزاوية مع عقارب الساعة من الأعلى (y للأسفل).
    var theta = math.atan2(dx, -dy);
    if (theta < 0) theta += 2 * math.pi;
    final day = (theta / step + rotation + 0.5).floor() % dayCount;
    return RingHit(ring, day);
  }
}
