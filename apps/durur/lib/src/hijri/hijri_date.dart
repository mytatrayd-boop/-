import 'umm_al_qura_calendar.dart';

/// تاريخ هجري حسب تقويم أم القرى. التحويل من جدول بيانات
/// (`assets/tables/hijri_umm_al_qura.json`، D22) لا من مكتبة.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  /// يحوّل يوماً ميلادياً (يُؤخذ التاريخ فقط، بلا الوقت) إلى أم القرى
  /// بجدول [calendar]. يرمي [RangeError] خارج مدى الجدول.
  factory HijriDate.fromGregorian(
    DateTime date,
    UmmAlQuraCalendar calendar,
  ) =>
      calendar.convert(date);

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
