import '../domain/day_info.dart';
import '../domain/item.dart';
import '../domain/month_day.dart';
import 'calendar_engine.dart';

/// البحث عن فترة عنصر أو دَرّ حول تاريخ مرجعي (الميزة 7). Dart صافٍ.
///
/// القاعدة: الفترة التي تحتوي [from] إن وُجدت، وإلا أقرب فترة تبدأ بعده
/// خلال سنة كاملة. null إن لم يظهر العنصر في جدول المنطقة أصلاً.

/// أطول من أي سنة (366 يوماً)، فيمر البحث على دورة كاملة على الأقل.
const _horizonDays = 370;

/// فترة العنصر [item] في جدول [engine] حول [from] (تاريخ محلي).
ItemPeriod? findItemPeriod(CalendarEngine engine, Item item, DateTime from) {
  ItemPeriod? layer(DayInfo day) => switch (item.kind) {
    ItemKind.star => day.star,
    ItemKind.majorSeason => day.majorSeason,
    ItemKind.weatherSeason => day.weatherSeason,
  };
  return _scan(engine, from, layer, (p) => p.itemId == item.id);
}

/// فترة الدَّرّ الذي يبدأ في [start] في جدول [engine] حول [from].
/// [engine] محرك جدول الدرور الفعلي (المُعيرة عند الاستعارة، D26).
DarPeriod? findDarPeriod(
  CalendarEngine engine,
  MonthDay start,
  DateTime from,
) => _scan(engine, from, (day) => day.dar, (p) => p.record.start == start);

T? _scan<T extends ActivePeriod>(
  CalendarEngine engine,
  DateTime from,
  T? Function(DayInfo) layer,
  bool Function(T) matches,
) {
  final first = DateTime(from.year, from.month, from.day);
  var day = first;
  while (_daysFrom(first, day) <= _horizonDays) {
    final period = layer(engine.resolve(day));
    if (period == null) {
      day = DateTime(day.year, day.month, day.day + 1);
      continue;
    }
    if (matches(period)) return period;
    // القفز إلى اليوم التالي لنهاية الفترة الحالية.
    final end = period.end;
    day = DateTime(end.year, end.month, end.day + 1);
  }
  return null;
}

int _daysFrom(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
