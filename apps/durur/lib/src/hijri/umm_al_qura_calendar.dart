import '../domain/json_utils.dart';
import '../domain/record_meta.dart';
import 'hijri_date.dart';

/// تقويم أم القرى كبيانات (D22، ARCHITECTURE §16.6): جدول بدايات الأشهر
/// الهجرية من `assets/tables/hijri_umm_al_qura.json`. Dart صافٍ، بلا مكتبة.
///
/// `monthStarts[i]` = اليوم الميلادي لبداية الشهر رقم i بدءاً من
/// [firstYear]/[firstMonth]، والعنصر الأخير حارس لنهاية آخر شهر.
/// صحة الجدول (أطوال الأشهر والسنوات والتغطية) يفحصها `HijriTableValidator`.
class UmmAlQuraCalendar implements Sourced {
  UmmAlQuraCalendar({
    required this.calendar,
    required this.firstYear,
    required this.firstMonth,
    required List<DateTime> monthStarts,
    required this.source,
    required this.approval,
    this.verifiedThrough,
  }) : monthStarts = List.unmodifiable(monthStarts);

  factory UmmAlQuraCalendar.fromJson(Object? json, [String where = file]) {
    final map = asObject(json, where);
    final firstMonth = readField<int>(map, 'firstMonth', where);
    if (firstMonth < 1 || firstMonth > 12) {
      throw FormatException('$where: firstMonth $firstMonth خارج 1..12.');
    }
    final starts = [
      for (final (i, s) in asList(map['monthStarts'], '$where.monthStarts')
          .indexed)
        parseIsoDate(s, '$where.monthStarts[$i]'),
    ];
    if (starts.length < 2) {
      throw FormatException(
          '$where.monthStarts: يلزم شهر واحد على الأقل مع الحارس.');
    }
    final verified = map['verifiedThrough'];
    return UmmAlQuraCalendar(
      calendar: readField<String>(map, 'calendar', where),
      firstYear: readField<int>(map, 'firstYear', where),
      firstMonth: firstMonth,
      monthStarts: starts,
      source: Source.fromJson(map['source'], where),
      approval: Approval.fromJson(map['approval'], where),
      verifiedThrough:
          verified == null ? null : parseIsoDate(verified, '$where.verifiedThrough'),
    );
  }

  static const file = 'hijri_umm_al_qura.json';

  /// قيمة الحقل `calendar` المتوقعة.
  static const ummAlQura = 'umm_al_qura';

  final String calendar;
  final int firstYear;

  /// 1 = محرم.
  final int firstMonth;

  /// بدايات الأشهر (منتصف الليل UTC لكل يوم)، والأخير حارس.
  final List<DateTime> monthStarts;

  final Source source;

  @override
  final Approval approval;

  /// آخر يوم تحقق منه المراجع مقابل التقويم الرسمي (للمراجعة فقط؛ لا أثر
  /// له على العرض).
  final DateTime? verifiedThrough;

  @override
  String get recordPath => file;

  @override
  List<Source> get sources => [source];

  /// عدد الأشهر في الجدول (بلا الحارس).
  int get monthCount => monthStarts.length - 1;

  /// أول يوم يغطيه الجدول.
  DateTime get firstDay => monthStarts.first;

  /// آخر يوم يغطيه الجدول (اليوم السابق للحارس).
  DateTime get lastDay => monthStarts.last.subtract(const Duration(days: 1));

  /// (السنة، الشهر) للشهر رقم [index] في الجدول.
  (int year, int month) monthAt(int index) {
    final n = firstMonth - 1 + index;
    return (firstYear + n ~/ 12, n % 12 + 1);
  }

  /// رقم الشهر [year]/[month] في الجدول، أو null إن كان خارجه.
  int? indexOf(int year, int month) {
    final i = (year - firstYear) * 12 + (month - firstMonth);
    return i >= 0 && i < monthCount ? i : null;
  }

  /// بداية الشهر [year]/[month]، أو null إن كان خارج الجدول.
  DateTime? monthStart(int year, int month) {
    final i = indexOf(year, month);
    return i == null ? null : monthStarts[i];
  }

  /// يحوّل يوماً ميلادياً (التاريخ فقط بلا الوقت)، أو null خارج مدى الجدول.
  HijriDate? tryConvert(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    if (d.isBefore(monthStarts.first) || !d.isBefore(monthStarts.last)) {
      return null;
    }
    // بحث ثنائي: آخر بداية ≤ d.
    var lo = 0;
    var hi = monthCount - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (monthStarts[mid].isAfter(d)) {
        hi = mid - 1;
      } else {
        lo = mid;
      }
    }
    final (year, month) = monthAt(lo);
    return HijriDate(year, month, d.difference(monthStarts[lo]).inDays + 1);
  }

  /// مثل [tryConvert] لكن يرمي [RangeError] خارج مدى الجدول.
  HijriDate convert(DateTime date) =>
      tryConvert(date) ??
      (throw RangeError('التاريخ ${formatIsoDate(date)} خارج جدول أم القرى '
          '(${formatIsoDate(firstDay)} حتى ${formatIsoDate(lastDay)}).'));
}

/// يقرأ تاريخاً بصيغة `YYYY-MM-DD` بدقة (يرفض 2025-02-30 مثلاً).
DateTime parseIsoDate(Object? value, String where) {
  final match = value is String
      ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value)
      : null;
  if (match != null) {
    final y = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    final d = int.parse(match[3]!);
    final date = DateTime.utc(y, m, d);
    if (date.year == y && date.month == m && date.day == d) return date;
  }
  throw FormatException('$where: تاريخ غير صالح "$value" (المتوقع YYYY-MM-DD).');
}

/// `YYYY-MM-DD` ليوم (التاريخ فقط).
String formatIsoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
