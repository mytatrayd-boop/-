import 'package:hijri/hijri_calendar.dart';

/// تاريخ هجري حسب تقويم أم القرى (جدول مضمّن في مكتبة hijri، بلا إنترنت).
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  /// يحوّل يوماً ميلادياً (يُؤخذ التاريخ فقط، بلا الوقت) إلى أم القرى.
  factory HijriDate.fromGregorian(DateTime date) {
    final h = HijriCalendar.fromDate(DateTime(date.year, date.month, date.day));
    return HijriDate(h.hYear, h.hMonth, h.hDay);
  }

  final int year;

  /// 1 = محرم ... 12 = ذو الحجة.
  final int month;
  final int day;

  @override
  bool operator ==(Object other) =>
      other is HijriDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}
