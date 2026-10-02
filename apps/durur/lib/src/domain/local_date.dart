/// أدوات «اليوم المحلي»: اليوم يبدأ منتصف الليل بتوقيت الجهاز (SPEC 1.8).
library;

/// التاريخ مقرّباً لمنتصف الليل المحلي. يُستخدم مفتاحاً لـ `dayInfoProvider`
/// وغيره من مزوّدات family حتى لا يُنشأ مدخل جديد مع كل لحظة (ARCHITECTURE §3).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// المدى المتاح للتصفح (DESIGN 7.4 و8.5): من 1 يناير 2025 إلى 31 ديسمبر 2040.
abstract final class DateRange {
  static final DateTime first = DateTime(2025, 1, 1);
  static final DateTime last = DateTime(2040, 12, 31);

  /// يحصر [d] (مقرّباً لمنتصف الليل) داخل المدى.
  static DateTime clamp(DateTime d) {
    final day = dateOnly(d);
    if (day.isBefore(first)) return first;
    if (day.isAfter(last)) return last;
    return day;
  }
}

/// اليوم بعد [days] يوماً (بالتقويم لا بالساعات، فلا يتأثر بالتوقيت الصيفي).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// عدد الأيام بين يومين محليين (بلا أثر للتوقيت الصيفي).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
