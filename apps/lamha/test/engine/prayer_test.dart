import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/prayer.dart';
import 'package:timezone/timezone.dart' as tz;

// لم يتوفر مصدر موثوق قابل للاقتباس لأوقات أم القرى (الشبكة محجوبة في بيئة
// البناء)، فالاختبارات هنا للخصائص: الترتيب، والمنطقة الزمنية، وقاعدة
// العشاء = المغرب + ٩٠ دقيقة، والصلاة القادمة بعد العشاء = فجر الغد،
// ونطاقات معقولة للرياض في أكتوبر.

void main() {
  final riyadh = PrayerCalculator(latitude: 24.7136, longitude: 46.6753);
  final day = DateTime(2026, 10, 19);

  test('الترتيب: الفجر < الشروق < الظهر < العصر < المغرب < العشاء', () {
    final t = riyadh.forDate(day).times;
    expect(t.map((p) => p.name), PrayerName.values);
    for (var i = 1; i < t.length; i++) {
      expect(t[i].time.isAfter(t[i - 1].time), isTrue, reason: '${t[i].name}');
    }
  });

  test('التوقيت المحلي للرياض UTC+3 وفي اليوم نفسه', () {
    for (final p in riyadh.forDate(day).times) {
      expect(p.time.timeZoneOffset, const Duration(hours: 3));
      expect((p.time.year, p.time.month, p.time.day), (2026, 10, 19));
    }
    expect(riyadh.forDate(day)[PrayerName.fajr].toIso8601String(),
        endsWith('+0300'));
  });

  test('أم القرى: العشاء بعد المغرب بـ٩٠ دقيقة', () {
    final d = riyadh.forDate(day);
    expect(d[PrayerName.isha].difference(d[PrayerName.maghrib]),
        const Duration(minutes: 90));
  });

  test('نطاقات معقولة للرياض في ١٩ أكتوبر', () {
    final d = riyadh.forDate(day);
    bool between(tz.TZDateTime t, int h1, int m1, int h2, int m2) {
      final m = t.hour * 60 + t.minute;
      return m >= h1 * 60 + m1 && m <= h2 * 60 + m2;
    }

    expect(between(d[PrayerName.fajr], 4, 25, 4, 55), isTrue);
    expect(between(d[PrayerName.sunrise], 5, 45, 6, 10), isTrue);
    expect(between(d[PrayerName.dhuhr], 11, 35, 11, 55), isTrue);
    expect(between(d[PrayerName.asr], 14, 55, 15, 20), isTrue);
    expect(between(d[PrayerName.maghrib], 17, 15, 17, 40), isTrue);
  });

  test('الصلاة القادمة', () {
    final d = riyadh.forDate(day);
    final beforeDhuhr = d[PrayerName.dhuhr].subtract(const Duration(minutes: 34));
    expect(riyadh.nextPrayer(beforeDhuhr).name, PrayerName.dhuhr);
    expect(riyadh.nextPrayerRemainingText(beforeDhuhr), 'باقي ٣٤ دقيقة');
    // بعد الفجر وقبل الظهر: الشروق ليس صلاة.
    final afterFajr = d[PrayerName.fajr].add(const Duration(minutes: 1));
    expect(riyadh.nextPrayer(afterFajr).name, PrayerName.dhuhr);
  });

  test('بعد العشاء: الصلاة القادمة فجر الغد', () {
    final d = riyadh.forDate(day);
    final next = riyadh.nextPrayer(d[PrayerName.isha].add(const Duration(minutes: 5)));
    expect(next.name, PrayerName.fajr);
    expect(next.time, riyadh.forDate(DateTime(2026, 10, 20))[PrayerName.fajr]);
  });

  test('قبل الفجر: فجر اليوم نفسه', () {
    final d = riyadh.forDate(day);
    final next = riyadh.nextPrayer(d[PrayerName.fajr].subtract(const Duration(hours: 2)));
    expect(next.time, d[PrayerName.fajr]);
  });

  test('الطريقة قابلة للتغيير وتؤثر في الوقت', () {
    final mwl = PrayerCalculator(
        latitude: 24.7136, longitude: 46.6753, method: 'muslimWorldLeague');
    expect(mwl.forDate(day)[PrayerName.fajr],
        isNot(riyadh.forDate(day)[PrayerName.fajr]));
    expect(() => PrayerCalculator(latitude: 0, longitude: 0, method: 'x'),
        throwsArgumentError);
  });
}
