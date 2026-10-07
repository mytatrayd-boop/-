import '../../domain/day_info.dart';
import '../../domain/item.dart';
import '../../domain/localized_text.dart';
import '../../domain/month_day.dart';
import '../../domain/record_meta.dart';
import '../../domain/region_table.dart';
import '../../domain/tables.dart';
import '../../domain/weather_symbol.dart';
import '../../engine/calendar_engine.dart';
import '../../engine/period_finder.dart';
import '../home/dial/dial_model.dart';

/// ما تعرضه صفحة النجم/الموسم/الدَّرّ (الميزة 7، DESIGN 8.6). بلا Flutter.

/// هدف الصفحة: عنصر من items.json، أو دَرّ من سجله (D26).
sealed class DetailTarget {
  const DetailTarget();
}

/// نجم أو موسم كبير أو موسم جو: `/item/<itemId>`.
final class ItemTarget extends DetailTarget {
  const ItemTarget(this.itemId);

  final String itemId;

  @override
  bool operator ==(Object other) =>
      other is ItemTarget && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;

  @override
  String toString() => 'ItemTarget($itemId)';
}

/// دَرّ: `/dar/<regionId>/<MM-DD>`، و[regionId] جدول الدرور (D26). لا أهداف
/// دَرّ في منطقة بلا درور (السعودية، D50).
final class DarTarget extends DetailTarget {
  const DarTarget(this.regionId, this.start);

  final String regionId;
  final MonthDay start;

  @override
  bool operator ==(Object other) =>
      other is DarTarget && other.regionId == regionId && other.start == start;

  @override
  int get hashCode => Object.hash(regionId, start);

  @override
  String toString() => 'DarTarget($regionId, $start)';
}

/// طلب فتح صفحة: الهدف، والتاريخ المرجعي الذي تُعرض الفترة حوله
/// (الفترة التي تحتويه، وإلا التالية).
typedef DetailRequest = ({DetailTarget target, DateTime from});

enum DetailKind { star, season, weatherSeason, dar }

/// المحتوى المحسوب لصفحة.
class DetailData {
  const DetailData({
    required this.kind,
    required this.name,
    required this.period,
    required this.regionName,
    required this.datesRecord,
    required this.weather,
    required this.weatherNote,
    this.item,
    this.dar,
    this.seasonId,
  });

  final DetailKind kind;
  final String name;

  /// الفترة بتواريخها الفعلية (UTC منتصف الليل).
  final ActivePeriod period;

  /// اسم المنطقة التي جاءت التواريخ من جدولها.
  final String regionName;

  /// سجل الجدول الذي جاءت منه التواريخ (لمصدرها واعتمادها).
  final Sourced? datesRecord;

  final List<WeatherSymbol> weather;
  final LocalizedText? weatherNote;

  /// العنصر (التعريف والمثل ومصادرهما)؛ null لصفحة الدَّرّ.
  final Item? item;

  /// سجل الدَّرّ؛ null لغير الدَّرّ.
  final DarRecord? dar;

  /// شريحة الموسم: الموسم الكبير في بداية الفترة للنجم وموسم الجو، ومئة
  /// الدَّرّ للدَّرّ (D25)، وnull للموسم الكبير نفسه.
  final String? seasonId;

  /// سهيل والثريا: التاريخ محسوب فلكياً لمدينة المستخدم (الميزة 5).
  bool get isHeliacal => item?.dateMethod == DateMethod.heliacal;
}

/// يحسب محتوى الصفحة، أو null إن لم يوجد العنصر أو السجل (مسار قديم بعد
/// تحديث بيانات، D26) أو لم يظهر في الجدول.
///
/// [engine]: محرك منطقة المستخدم (لصفحات العناصر). صفحة الدَّرّ تبني محرك
/// جدولها من [DarTarget.regionId].
DetailData? resolveDetail({
  required Tables tables,
  required CalendarEngine? engine,
  required DetailRequest request,
}) {
  final from = request.from;
  switch (request.target) {
    case ItemTarget(:final itemId):
      final item = tables.items[itemId];
      if (item == null || engine == null) return null;
      final period = findItemPeriod(engine, item, from);
      if (period == null) return null;
      final start = period.start;
      return DetailData(
        kind: switch (item.kind) {
          ItemKind.star => DetailKind.star,
          ItemKind.majorSeason => DetailKind.season,
          ItemKind.weatherSeason => DetailKind.weatherSeason,
        },
        name: item.name.ar,
        period: period,
        regionName: engine.region.name.ar,
        datesRecord: period.record,
        weather: item.weather,
        weatherNote: item.weatherNote,
        item: item,
        seasonId: item.kind == ItemKind.majorSeason
            ? null
            : engine
                  .resolve(DateTime(start.year, start.month, start.day))
                  .majorSeason
                  .itemId,
      );
    case DarTarget(:final regionId, start: final darStart):
      final table = tables.regionTables[regionId];
      if (table == null || !table.hasDurur) return null;
      if (!table.durur.any((r) => r.start == darStart)) return null;
      final CalendarEngine darEngine;
      try {
        darEngine = CalendarEngine.fromTables(tables, regionId);
      } on ArgumentError {
        return null;
      }
      final period = findDarPeriod(darEngine, darStart, from);
      if (period == null) return null;
      final record = period.record;
      return DetailData(
        kind: DetailKind.dar,
        name: record.name.ar,
        period: period,
        regionName: darEngine.region.name.ar,
        datesRecord: record,
        weather: record.weather,
        weatherNote: record.weatherNote,
        dar: record,
        seasonId: record.seasonId,
      );
  }
}

/// طلب صفحة من جزء في الدائرة أو البطاقة ليوم [day]: النجم، أو الموسم
/// الكبير (ومنه حلقة الأشهر)، أو موسم الجو إن وُجد، وإلا الدَّرّ بجدوله
/// (D26). في منطقة بلا درور (D50) يحل الطالع محل الدَّرّ.
DetailRequest detailRequestFor(DialRing ring, DayInfo day) {
  final from = DateTime(day.date.year, day.date.month, day.date.day);
  final dar = day.dar;
  final DetailTarget target = switch (ring) {
    DialRing.stars => ItemTarget(day.star.itemId),
    DialRing.seasons ||
    DialRing.majorSeason ||
    DialRing.months ||
    DialRing.days ||
    DialRing.zodiac => ItemTarget(day.majorSeason.itemId),
    DialRing.weather when day.weatherSeason != null => ItemTarget(
      day.weatherSeason!.itemId,
    ),
    _ when dar != null => DarTarget(day.regionId, dar.record.start),
    _ => ItemTarget(day.star.itemId),
  };
  return (target: target, from: from);
}
