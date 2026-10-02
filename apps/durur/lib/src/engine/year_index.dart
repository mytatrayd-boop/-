import '../domain/day_info.dart';
import 'calendar_engine.dart';

/// نتائج كل أيام سنة ميلادية (365 أو 366) لمنطقة، تُبنى مرة وتُخزَّن.
class YearIndex {
  YearIndex(CalendarEngine engine, this.year)
      : days = List.unmodifiable([
          for (var d = DateTime.utc(year, 1, 1);
              d.year == year;
              d = d.add(const Duration(days: 1)))
            engine.resolve(d),
        ]);

  final int year;

  /// days[0] = 1 يناير.
  final List<DayInfo> days;

  int get length => days.length;

  /// نتيجة يوم من هذه السنة.
  DayInfo dayOf(DateTime date) {
    if (date.year != year) {
      throw ArgumentError('التاريخ $date خارج السنة $year.');
    }
    final index = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(year, 1, 1))
        .inDays;
    return days[index];
  }
}
