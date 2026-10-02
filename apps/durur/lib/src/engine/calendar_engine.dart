import '../domain/day_info.dart';
import '../domain/month_day.dart';
import '../domain/region.dart';
import '../domain/region_table.dart';

/// محرك الحساب (الميزة 1): من تاريخ محلي إلى الدَّرّ والموسم والنجم والجو
/// في جدول منطقة واحدة. Dart صافٍ، بلا إنترنت، ويعمل لأي سنة.
///
/// يفترض جدولاً صحيحاً (انظر [TableValidator])؛ يكفي هنا ألا تكون
/// الطبقات المتصلة فارغة.
class CalendarEngine {
  CalendarEngine({required this.region, required this.table})
      : _durur = _sorted(table.durur, (r) => r.start),
        _majorSeasons = _sorted(table.majorSeasons, (r) => r.start),
        _stars = _sorted(table.stars, (r) => r.start) {
    if (region.id != table.regionId) {
      throw ArgumentError('جدول ${table.regionId} لا يخص المنطقة ${region.id}.');
    }
    if (_durur.isEmpty || _majorSeasons.isEmpty || _stars.isEmpty) {
      throw ArgumentError('جدول ${table.regionId}: الدرور والمواسم الكبيرة '
          'والنجوم يجب ألا تكون فارغة.');
    }
  }

  final Region region;
  final RegionTable table;
  final List<DarRecord> _durur;
  final List<LayerRecord> _majorSeasons;
  final List<LayerRecord> _stars;

  static List<T> _sorted<T>(List<T> list, MonthDay Function(T) startOf) =>
      [...list]..sort((a, b) => startOf(a).compareTo(startOf(b)));

  /// يُرجع نتيجة اليوم. يؤخذ من [localDate] السنة والشهر واليوم فقط،
  /// فاليوم يبدأ عند منتصف الليل بتوقيت الجهاز (SPEC الميزة 1، بند 8).
  DayInfo resolve(DateTime localDate) {
    final date = DateTime.utc(localDate.year, localDate.month, localDate.day);
    final key = lookupKey(date);

    final dar = _resolveContinuous(_durur, (r) => r.start, date, key);
    final season =
        _resolveContinuous(_majorSeasons, (r) => r.start, date, key);
    final star = _resolveContinuous(_stars, (r) => r.start, date, key);

    return DayInfo(
      date: date,
      regionId: region.id,
      dar: DarPeriod(
        record: dar.record,
        start: dar.start,
        end: dar.end,
        dayNumber: dar.dayNumber,
      ),
      majorSeason: ItemPeriod(
        itemId: season.record.itemId,
        start: season.start,
        end: season.end,
        dayNumber: season.dayNumber,
      ),
      weatherSeason: _resolveWeatherSeason(date, key),
      star: ItemPeriod(
        itemId: star.record.itemId,
        start: star.start,
        end: star.end,
        dayNumber: star.dayNumber,
      ),
    );
  }

  /// (شهر، يوم) المستخدم للبحث في الجدول بعد تطبيق قاعدة 29 فبراير.
  MonthDay lookupKey(DateTime date) {
    final md = MonthDay.of(date);
    if (!md.isFeb29) return md;
    switch (region.leapDayRule) {
      case LeapDayRule.extendFeb28:
        return const MonthDay(2, 28);
    }
  }

  ({T record, DateTime start, DateTime end, int dayNumber})
      _resolveContinuous<T>(
    List<T> sorted,
    MonthDay Function(T) startOf,
    DateTime date,
    MonthDay key,
  ) {
    // آخر بداية ≤ اليوم، وإلا آخر سجل في السنة السابقة (التفاف).
    var index = -1;
    for (var i = 0; i < sorted.length; i++) {
      if (startOf(sorted[i]) <= key) {
        index = i;
      } else {
        break;
      }
    }
    final startYear = index == -1 ? date.year - 1 : date.year;
    if (index == -1) index = sorted.length - 1;

    final record = sorted[index];
    final start = startOf(record).inYear(startYear);
    final next = sorted[(index + 1) % sorted.length];
    var nextStart = startOf(next).inYear(startYear);
    if (!nextStart.isAfter(start)) nextStart = startOf(next).inYear(startYear + 1);

    return (
      record: record,
      start: start,
      end: nextStart.subtract(const Duration(days: 1)),
      dayNumber: date.difference(start).inDays + 1,
    );
  }

  ItemPeriod? _resolveWeatherSeason(DateTime date, MonthDay key) {
    for (final season in table.weatherSeasons) {
      if (!season.contains(key)) continue;
      final startYear =
          season.wrapsYear && key <= season.end ? date.year - 1 : date.year;
      final start = season.start.inYear(startYear);
      final endYear = season.wrapsYear ? startYear + 1 : startYear;
      var end = season.end.inYear(endYear);
      // قاعدة extend_feb28: موسم ينتهي في 28 فبراير يشمل 29 فبراير.
      if (season.end == const MonthDay(2, 28) && _isLeap(endYear)) {
        end = DateTime.utc(endYear, 2, 29);
      }
      return ItemPeriod(
        itemId: season.itemId,
        start: start,
        end: end,
        dayNumber: date.difference(start).inDays + 1,
      );
    }
    return null;
  }

  static bool _isLeap(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}
