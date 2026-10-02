import '../domain/day_info.dart';
import '../domain/month_day.dart';
import '../domain/region.dart';
import '../domain/region_table.dart';
import '../domain/tables.dart';

/// محرك الحساب (الميزة 1): من تاريخ محلي إلى الدَّرّ والموسم والنجم والجو
/// في جدول منطقة واحدة. Dart صافٍ، بلا إنترنت، ويعمل لأي سنة.
///
/// يفترض جدولاً صحيحاً (انظر [TableValidator])؛ يكفي هنا ألا تكون
/// الطبقات المتصلة فارغة.
class CalendarEngine {
  /// [dururRegion] و[dururTable]: المنطقة المُعيرة وجدولها، إلزاميان إن كان
  /// للجدول `dururBorrow` (D24)، وممنوعان غير ذلك. الدَّرّ يُحسب من جدول
  /// المُعيرة وبقاعدة 29 فبراير الخاصة بها، وبقية الطبقات من [table].
  CalendarEngine({
    required this.region,
    required this.table,
    Region? dururRegion,
    RegionTable? dururTable,
  }) : dururRegion = dururRegion ?? region,
       _durur = _sorted((dururTable ?? table).durur, (r) => r.start),
       _majorSeasons = _sorted(table.majorSeasons, (r) => r.start),
       _stars = _sorted(table.stars, (r) => r.start) {
    if (region.id != table.regionId) {
      throw ArgumentError(
        'جدول ${table.regionId} لا يخص المنطقة ${region.id}.',
      );
    }
    final borrow = table.dururBorrow;
    if (borrow == null) {
      if (dururRegion != null || dururTable != null) {
        throw ArgumentError('جدول ${table.regionId} لا يستعير الدرور.');
      }
    } else {
      if (dururRegion == null || dururTable == null) {
        throw ArgumentError(
          'جدول ${table.regionId} يستعير درور '
          '${borrow.fromRegionId}: يلزم جدول المُعيرة.',
        );
      }
      if (dururRegion.id != borrow.fromRegionId ||
          dururTable.regionId != borrow.fromRegionId) {
        throw ArgumentError(
          'جدول ${table.regionId} يستعير درور '
          '${borrow.fromRegionId} لا ${dururTable.regionId}.',
        );
      }
      if (dururTable.borrowsDurur) {
        throw ArgumentError(
          '${dururTable.regionId} يستعير بدوره؛ '
          'سلاسل الاستعارة ممنوعة.',
        );
      }
    }
    if (_durur.isEmpty || _majorSeasons.isEmpty || _stars.isEmpty) {
      throw ArgumentError(
        'جدول ${table.regionId}: الدرور والمواسم الكبيرة '
        'والنجوم يجب ألا تكون فارغة.',
      );
    }
  }

  /// محرك منطقة من الجداول المحمّلة، مع جدول المُعيرة إن كانت تستعير الدرور.
  factory CalendarEngine.fromTables(Tables tables, String regionId) {
    final region = tables.region(regionId);
    final table = tables.regionTables[regionId];
    if (region == null || table == null) {
      throw ArgumentError('المنطقة $regionId غير موجودة.');
    }
    final borrow = table.dururBorrow;
    return CalendarEngine(
      region: region,
      table: table,
      dururRegion: borrow == null ? null : tables.region(borrow.fromRegionId),
      dururTable: borrow == null
          ? null
          : tables.regionTables[borrow.fromRegionId],
    );
  }

  final Region region;
  final RegionTable table;

  /// منطقة جدول الدرور الفعلي (المُعيرة عند الاستعارة، وإلا [region]).
  final Region dururRegion;
  final List<DarRecord> _durur;
  final List<LayerRecord> _majorSeasons;
  final List<LayerRecord> _stars;

  /// استعارة الدرور (D24) أو null.
  DururBorrow? get dururBorrow => table.dururBorrow;

  static List<T> _sorted<T>(List<T> list, MonthDay Function(T) startOf) =>
      [...list]..sort((a, b) => startOf(a).compareTo(startOf(b)));

  /// يُرجع نتيجة اليوم. يؤخذ من [localDate] السنة والشهر واليوم فقط،
  /// فاليوم يبدأ عند منتصف الليل بتوقيت الجهاز (SPEC الميزة 1، بند 8).
  DayInfo resolve(DateTime localDate) {
    final date = DateTime.utc(localDate.year, localDate.month, localDate.day);
    final key = lookupKey(date);
    final darKey = _lookupKey(date, dururRegion.leapDayRule);

    final dar = _resolveContinuous(_durur, (r) => r.start, date, darKey);
    final season = _resolveContinuous(_majorSeasons, (r) => r.start, date, key);
    final star = _resolveContinuous(_stars, (r) => r.start, date, key);

    return DayInfo(
      date: date,
      regionId: region.id,
      dururRegionId: dururRegion.id,
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
        record: season.record,
      ),
      weatherSeason: _resolveWeatherSeason(date, key),
      star: ItemPeriod(
        itemId: star.record.itemId,
        start: star.start,
        end: star.end,
        dayNumber: star.dayNumber,
        record: star.record,
      ),
    );
  }

  /// (شهر، يوم) المستخدم للبحث في الجدول بعد تطبيق قاعدة 29 فبراير.
  MonthDay lookupKey(DateTime date) => _lookupKey(date, region.leapDayRule);

  static MonthDay _lookupKey(DateTime date, LeapDayRule rule) {
    final md = MonthDay.of(date);
    if (!md.isFeb29) return md;
    switch (rule) {
      case LeapDayRule.extendFeb28:
        return const MonthDay(2, 28);
    }
  }

  ({T record, DateTime start, DateTime end, int dayNumber}) _resolveContinuous<
    T
  >(List<T> sorted, MonthDay Function(T) startOf, DateTime date, MonthDay key) {
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
    if (!nextStart.isAfter(start)) {
      nextStart = startOf(next).inYear(startYear + 1);
    }

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
      final startYear = season.wrapsYear && key <= season.end
          ? date.year - 1
          : date.year;
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
        record: season,
      );
    }
    return null;
  }

  static bool _isLeap(int year) =>
      (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
}
