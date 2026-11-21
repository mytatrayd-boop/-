/// نصوص العرض العربية التي يولّدها المحرك في الجدول (النسخة الأولى عربية فقط،
/// SPEC §8). كلها هنا في مكان واحد ليسهل نقلها لملفات الترجمة لاحقاً.
library;

const gregorianMonthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const hijriMonthNames = [
  'محرم',
  'صفر',
  'ربيع الأول',
  'ربيع الآخر',
  'جمادى الأولى',
  'جمادى الآخرة',
  'رجب',
  'شعبان',
  'رمضان',
  'شوال',
  'ذو القعدة',
  'ذو الحجة',
];

/// بترتيب `DateTime.weekday` (1 = الإثنين ... 7 = الأحد).
const weekdayNames = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const todayText = 'اليوم';

const _western = '0123456789';
const _eastern = '٠١٢٣٤٥٦٧٨٩';

/// شكل الأرقام في نصوص الودجت (إعداد «الأرقام»): عربية شرقية (١٢٣، الافتراضي) أو إنجليزية (123).
enum DigitStyle {
  arabic,
  latin;

  static const fallback = DigitStyle.arabic;

  static DigitStyle byName(String? name) => DigitStyle.values.firstWhere(
    (d) => d.name == name,
    orElse: () => fallback,
  );
}

/// يحوّل الأرقام في [input] (لاتينية أو عربية شرقية) إلى شكل [style].
String formatDigits(Object input, [DigitStyle style = DigitStyle.arabic]) {
  final s = input.toString();
  final from = style == DigitStyle.arabic ? _western : _eastern;
  final to = style == DigitStyle.arabic ? _eastern : _western;
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

/// كل نص في شجرة JSON [json] بأرقام [style] (نصوص الجدول الجاهزة). المفاتيح والأرقام كما هي.
Object? localizeDigits(Object? json, DigitStyle style) => switch (json) {
  final String s => formatDigits(s, style),
  final Map m => <String, Object?>{
    for (final e in m.entries) '${e.key}': localizeDigits(e.value, style),
  },
  final List l => [for (final v in l) localizeDigits(v, style)],
  _ => json,
};

/// «اليوم» أو «باقي يوم» أو «باقي يومان» أو «باقي ٣ أيام» أو «باقي ١١ يوماً».
String remainingDaysText(int days) {
  if (days <= 0) return todayText;
  if (days == 1) return 'باقي يوم';
  if (days == 2) return 'باقي يومان';
  if (days <= 10) return 'باقي ${formatDigits(days)} أيام';
  return 'باقي ${formatDigits(days)} يوماً';
}

/// «اليوم» أو «يوم واحد» أو «يومان» أو «٣ أيام» أو «١٤ يوماً» (أعمدة الإيداعات، الميزة ٦).
String daysCountText(int days) {
  if (days <= 0) return todayText;
  if (days == 1) return 'يوم واحد';
  if (days == 2) return 'يومان';
  if (days <= 10) return '${formatDigits(days)} أيام';
  return '${formatDigits(days)} يوماً';
}

/// «اليوم» أو «بعد يوم» أو «بعد يومين» أو «بعد ٨ أيام» أو «بعد ١١ يوماً» (لسطر الإشعار).
String afterDaysText(int days) {
  if (days <= 0) return todayText;
  if (days == 1) return 'بعد يوم';
  if (days == 2) return 'بعد يومين';
  if (days <= 10) return 'بعد ${formatDigits(days)} أيام';
  return 'بعد ${formatDigits(days)} يوماً';
}

/// «باقي دقيقة» أو «باقي دقيقتان» أو «باقي ٣ دقائق» أو «باقي ٣٤ دقيقة».
String remainingMinutesText(int minutes) {
  if (minutes <= 0) return 'الآن';
  if (minutes == 1) return 'باقي دقيقة';
  if (minutes == 2) return 'باقي دقيقتان';
  if (minutes <= 10) return 'باقي ${formatDigits(minutes)} دقائق';
  return 'باقي ${formatDigits(minutes)} دقيقة';
}

/// العدّاد كما يعرضه Chronometer في أندرويد: «٦:٠٤:١٩» بساعات، و«٠٤:١٩» دونها.
String countdownClock(Duration d) {
  final s = d.isNegative ? 0 : d.inSeconds;
  String two(int n) => formatDigits(n.toString().padLeft(2, '0'));
  final h = s ~/ 3600, m = s % 3600 ~/ 60, sec = s % 60;
  return h > 0
      ? '${formatDigits(h)}:${two(m)}:${two(sec)}'
      : '${two(m)}:${two(sec)}';
}

/// «ص» قبل الظهر و«م» بعده.
const amText = 'ص';
const pmText = 'م';

/// الساعة بنظام ١٢ ساعة بالأرقام العربية الشرقية بلا لاحقة، مثل «٤:٣٥».
String arabicClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${formatDigits(h)}:${formatDigits(t.minute.toString().padLeft(2, '0'))}';
}

/// «ص» أو «م» للحظة [t].
String amPm(DateTime t) => t.hour < 12 ? amText : pmText;

/// الوقت جاهزاً للعرض، مثل «٤:٣٥ ص».
String arabicTimeText(DateTime t) => '${arabicClock(t)} ${amPm(t)}';

/// عدد الأيام التقويمية من [from] إلى [to] (التاريخ فقط، بلا أثر للتوقيت الصيفي).
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

/// `YYYY-MM-DD`.
String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
