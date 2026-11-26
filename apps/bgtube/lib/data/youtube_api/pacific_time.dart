/// يوم الحصة بتوقيت المحيط الهادئ (America/Los_Angeles)، حيث تُصفَّر حصة
/// YouTube Data API عند منتصف الليل. قاعدة التوقيت الصيفي الأمريكية (منذ 2007):
/// يبدأ ثاني أحد من مارس 02:00 محلياً وينتهي أول أحد من نوفمبر 02:00 محلياً.
/// بلا قاعدة بيانات مناطق زمنية (لا حزمة إضافية).
library;

/// مفتاح اليوم `YYYY-MM-DD` بتوقيت المحيط الهادئ للحظة [t].
String pacificDayKey(DateTime t) {
  final u = t.toUtc();
  final local = u.add(pacificOffset(u));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}';
}

/// فرق التوقيت: −7 ساعات صيفاً (PDT) و−8 شتاءً (PST).
Duration pacificOffset(DateTime utc) =>
    _isDaylight(utc.toUtc()) ? const Duration(hours: -7) : const Duration(hours: -8);

bool _isDaylight(DateTime u) {
  DateTime nthSunday(int month, int n) {
    var d = DateTime.utc(u.year, month, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * (n - 1)));
  }

  // 02:00 PST = 10:00 UTC، و02:00 PDT = 09:00 UTC.
  final start = nthSunday(3, 2).add(const Duration(hours: 10));
  final end = nthSunday(11, 1).add(const Duration(hours: 9));
  return !u.isBefore(start) && u.isBefore(end);
}
