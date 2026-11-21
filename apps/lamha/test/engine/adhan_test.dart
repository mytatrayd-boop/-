import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/adhan.dart';
import 'package:lamha/src/engine/prayer.dart';
import 'package:timezone/timezone.dart' as tz;

PrayerCalculator riyadh() => PrayerCalculator(
      latitude: 24.7136,
      longitude: 46.6753,
      timeZoneName: 'Asia/Riyadh',
    );

void main() {
  // ٦ صباحاً بتوقيت الرياض: الفجر مضى، والظهر قادم.
  final now = DateTime.utc(2026, 11, 12, 3);
  const on = AdhanSettings(enabled: true);

  test('مطفأ أو بلا صلوات: لا تنبيهات', () {
    expect(planAdhan(riyadh(), now, const AdhanSettings()), isEmpty);
    expect(planAdhan(riyadh(), now, on.copyWith(prayers: {})), isEmpty);
    expect(planAdhan(riyadh(), now, on, max: 0), isEmpty);
  });

  test('الصلوات الخمس: ٦٠ تنبيهاً قادماً بترتيب زمني، أولها الظهر، بلا الشروق', () {
    final events = planAdhan(riyadh(), now, on);
    expect(events, hasLength(adhanMaxEvents));
    expect(events.first.prayer, PrayerName.dhuhr);
    expect(events.every((e) => e.prayer != PrayerName.sunrise), isTrue);
    expect(events.every((e) => e.time.isAfter(now)), isTrue);
    for (var i = 1; i < events.length; i++) {
      expect(events[i].time.isAfter(events[i - 1].time), isTrue, reason: '$i');
    }
    expect(events.map((e) => e.id).toSet(), hasLength(events.length), reason: 'معرّفات فريدة');
    // ١٢ يوماً × ٥ صلوات (اليوم ناقص الفجر): آخر تنبيه بعد ١٢ يوماً.
    expect(events.last.time.difference(events.first.time).inDays, inInclusiveRange(11, 12));
  });

  test('صلوات مختارة فقط، وتمتد الأيام لتبلغ الحد', () {
    final events = planAdhan(
        riyadh(), now, on.copyWith(prayers: {PrayerName.fajr, PrayerName.isha}));
    expect(events.map((e) => e.prayer).toSet(), {PrayerName.fajr, PrayerName.isha});
    expect(events, hasLength(adhanMaxEvents));
    final one = planAdhan(riyadh(), now, on.copyWith(prayers: {PrayerName.maghrib}), max: 5);
    expect(one, hasLength(5));
    expect(one.map((e) => e.time.day).toSet(), hasLength(5), reason: 'يوم لكل مغرب');
  });

  test('بعد وقت صلاة اليوم لا يُعاد تنبيهها، وقبل العشاء تأتي بقية اليوم', () {
    final lateNight = tz.TZDateTime(tz.getLocation('Asia/Riyadh'), 2026, 11, 12, 23).toUtc();
    final events = planAdhan(riyadh(), lateNight, on);
    expect(events.first.prayer, PrayerName.fajr);
    expect(events.first.time.day, 13);
  });

  test('المعرّف ثابت: تاريخ اليوم ثم ترتيب الصلاة', () {
    expect(adhanId(DateTime(2026, 11, 12), PrayerName.fajr), 202611120);
    expect(adhanId(DateTime(2026, 11, 12), PrayerName.isha), 202611125);
    expect(adhanId(DateTime(2026, 12, 31), PrayerName.isha), lessThan(1 << 31));
    final a = planAdhan(riyadh(), now, on).first;
    final b = planAdhan(riyadh(), now, on).first;
    expect(a.id, b.id);
    expect(a.title, 'أذان الظهر');
    expect(a.body('أبها'), contains('الظهر'));
    expect(a.body('أبها'), contains('أبها'));
  });

  test('الإعدادات تُحفظ وتُقرأ، والقديمة بلا أذان مطفأة', () {
    const a = AdhanSettings(
        enabled: true, prayers: {PrayerName.dhuhr, PrayerName.asr}, sound: AdhanSound.takbeer);
    expect(AdhanSettings.fromJson(a.toJson()), a);
    final legacy = AdhanSettings.fromJson(null);
    expect(legacy.enabled, isFalse);
    expect(legacy.prayers, hasLength(5));
    expect(legacy.sound, AdhanSound.full);
    // اسم صوت أو صلاة غير معروف لا يكسر القراءة.
    final odd = AdhanSettings.fromJson({'enabled': true, 'prayers': ['dhuhr', 'sunrise', 'x'], 'sound': 'x'});
    expect(odd.prayers, {PrayerName.dhuhr});
    expect(odd.sound, AdhanSound.full);
    expect(a, isNot(a.copyWith(sound: AdhanSound.silent)));
    expect(a.hashCode, AdhanSettings.fromJson(a.toJson()).hashCode);
  });

  test('آيفون يستبدل الأذان الكامل بالتكبيرتين (حد ٣٠ ثانية)', () {
    expect(AdhanSound.full.forPlatform(ios: true), AdhanSound.takbeer);
    expect(AdhanSound.full.forPlatform(ios: false), AdhanSound.full);
    expect(AdhanSound.silent.forPlatform(ios: true), AdhanSound.silent);
    expect(AdhanSound.takbeer.forPlatform(ios: true), AdhanSound.takbeer);
  });

  test('البصمة تتغير بالصوت والمدينة والأوقات فقط', () {
    final events = planAdhan(riyadh(), now, on, max: 5);
    final sig = adhanSignature(events, AdhanSound.full, 'الرياض');
    expect(adhanSignature(events, AdhanSound.full, 'الرياض'), sig);
    expect(adhanSignature(events, AdhanSound.takbeer, 'الرياض'), isNot(sig));
    expect(adhanSignature(events, AdhanSound.full, 'أبها'), isNot(sig));
    expect(adhanSignature(events.skip(1).toList(), AdhanSound.full, 'الرياض'), isNot(sig));
  });
}
