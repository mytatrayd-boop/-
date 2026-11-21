import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/prayer.dart';
import 'package:timezone/timezone.dart' as tz;

import '../helpers.dart';

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

  group('أم القرى ورمضان (SOURCES.md: منهجية مواقيتي)', () {
    final hijri = loadEngineDataFromFiles().hijri;
    final calc = PrayerCalculator(
      latitude: 24.7136,
      longitude: 46.6753,
      isRamadan: (d) => hijri.convert(d).month == 9,
    );
    Duration ishaGap(DateTime d) {
      final p = calc.forDate(d);
      return p[PrayerName.isha].difference(p[PrayerName.maghrib]);
    }

    test('يوم عادي: العشاء بعد المغرب بـ٩٠ دقيقة', () {
      expect(hijri.convert(day).month, isNot(9));
      expect(ishaGap(day), const Duration(minutes: 90));
    });

    test('رمضان ١٤٤٨: العشاء بعد المغرب بـ١٢٠ دقيقة', () {
      // أول يوم من رمضان ١٤٤٨ في جدول أم القرى، ثم يوم في منتصفه.
      var d = DateTime(2027, 1, 1);
      while (!(hijri.convert(d).year == 1448 && hijri.convert(d).month == 9)) {
        d = DateTime(d.year, d.month, d.day + 1);
      }
      final mid = DateTime(d.year, d.month, d.day + 14);
      expect(hijri.convert(mid).month, 9);
      expect(ishaGap(d), const Duration(minutes: 120));
      expect(ishaGap(mid), const Duration(minutes: 120));
      // اليوم السابق لرمضان: ٩٠.
      expect(ishaGap(DateTime(d.year, d.month, d.day - 1)),
          const Duration(minutes: 90));
      // طريقة أخرى غير أم القرى لا تتأثر.
      final mwl = PrayerCalculator(
          latitude: 24.7136,
          longitude: 46.6753,
          method: 'muslimWorldLeague',
          isRamadan: (_) => true);
      final p = mwl.forDate(mid);
      expect(p[PrayerName.isha].difference(p[PrayerName.maghrib]),
          isNot(const Duration(minutes: 120)));
    });
  });
}
