import 'umm_al_qura_calendar.dart';

/// مدقق جدول أم القرى (ARCHITECTURE §16.6، D22). Dart صافٍ.
///
/// يُستخدم على الجدول المضمّن (validate_tables والاختبارات)، ولاحقاً لقبول
/// جدول من حزمة تحديث (الميزة 11) مع تمرير الجدول المضمّن في [embedded].
class HijriTableValidator {
  const HijriTableValidator();

  /// المدى الذي يجب أن يغطيه الجدول كاملاً (SPEC: 2025–2040).
  static final coverFrom = DateTime.utc(2025, 1, 1);
  static final coverThrough = DateTime.utc(2040, 12, 31);

  /// أقصى فرق مسموح (بالأيام) بين بداية شهر في التحديث وبدايته في المضمّن.
  static const maxShiftFromEmbedded = 1;

  /// يعيد قائمة الأخطاء؛ فارغة = الجدول سليم.
  /// [embedded]: الجدول المضمّن في التطبيق؛ إن مُرِّر فأي بداية شهر مشتركة
  /// تختلف عنه بأكثر من [maxShiftFromEmbedded] يوم ← خطأ.
  List<String> validate(
    UmmAlQuraCalendar table, {
    UmmAlQuraCalendar? embedded,
  }) {
    final where = table.recordPath;
    final errors = <String>[];

    if (table.calendar != UmmAlQuraCalendar.ummAlQura) {
      errors.add('$where: calendar "${table.calendar}" '
          'والمتوقع "${UmmAlQuraCalendar.ummAlQura}".');
    }
    if (table.firstMonth != 1 || table.monthCount % 12 != 0) {
      errors.add('$where: الجدول يجب أن يتكون من سنوات هجرية كاملة '
          '(يبدأ بمحرم و${table.monthCount} شهراً ليس من مضاعفات 12).');
    }

    // كل شهر 29 أو 30 يوماً (ويضمن هذا التزايد وعدم وجود فجوات، لأن نهاية
    // كل شهر هي بداية التالي بالبناء).
    for (var i = 0; i < table.monthCount; i++) {
      final length =
          table.monthStarts[i + 1].difference(table.monthStarts[i]).inDays;
      if (length != 29 && length != 30) {
        final (y, m) = table.monthAt(i);
        errors.add('$where: الشهر $m/$y طوله $length يوماً '
            '(${formatIsoDate(table.monthStarts[i])}؛ المسموح 29 أو 30).');
      }
    }

    // كل سنة كاملة 354 أو 355 يوماً.
    for (var i = 0; i + 12 <= table.monthCount; i += 12) {
      if (table.monthAt(i).$2 != 1) continue;
      final length =
          table.monthStarts[i + 12].difference(table.monthStarts[i]).inDays;
      if (length != 354 && length != 355) {
        errors.add('$where: السنة ${table.monthAt(i).$1} طولها $length يوماً '
            '(المسموح 354 أو 355).');
      }
    }

    // التغطية.
    if (table.firstDay.isAfter(coverFrom) ||
        table.lastDay.isBefore(coverThrough)) {
      errors.add('$where: الجدول يغطي ${formatIsoDate(table.firstDay)} حتى '
          '${formatIsoDate(table.lastDay)}، والمطلوب '
          '${formatIsoDate(coverFrom)} حتى ${formatIsoDate(coverThrough)} '
          'كاملاً.');
    }

    final verified = table.verifiedThrough;
    if (verified != null &&
        (verified.isBefore(table.firstDay) || verified.isAfter(table.lastDay))) {
      errors.add('$where: verifiedThrough ${formatIsoDate(verified)} '
          'خارج مدى الجدول.');
    }

    if (embedded != null) {
      _checkShift(table, embedded, errors);
    }
    return errors;
  }

  void _checkShift(
    UmmAlQuraCalendar table,
    UmmAlQuraCalendar embedded,
    List<String> errors,
  ) {
    // كل الأشهر مع الحارس (بداية الشهر التالي لآخر شهر).
    for (var i = 0; i <= table.monthCount; i++) {
      final (y, m) = table.monthAt(i);
      final j = (y - embedded.firstYear) * 12 + (m - embedded.firstMonth);
      if (j < 0 || j > embedded.monthCount) continue;
      final shift = table.monthStarts[i]
          .difference(embedded.monthStarts[j])
          .inDays
          .abs();
      if (shift > maxShiftFromEmbedded) {
        errors.add('${table.recordPath}: بداية الشهر $m/$y '
            '${formatIsoDate(table.monthStarts[i])} تختلف عن المضمّن '
            '${formatIsoDate(embedded.monthStarts[j])} بـ $shift أيام '
            '(الحد $maxShiftFromEmbedded).');
      }
    }
  }
}
