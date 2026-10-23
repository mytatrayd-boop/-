import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/arabic.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';

import '../helpers.dart';

void main() {
  final data = loadEngineDataFromFiles();
  Settings settings({Set<String>? deposits}) => Settings(
        latitude: 24.7136,
        longitude: 46.6753,
        cityName: 'الرياض',
        deposits: deposits ?? {'salary', 'citizen_account'},
        layout: [
          for (final t in defaultLayout)
            t.copyWith(
                visible: t.id == WidgetElement.dates ||
                    t.id == WidgetElement.prayer),
        ],
        opacity: 40,
      );

  final schedule = buildSchedule(
    DateTime.utc(2026, 10, 19, 9),
    settings(),
    data,
    generatedAt: DateTime.utc(2026, 10, 19, 9),
  );
  final days = schedule['days']! as List;

  test('٣٠ يوماً متتالية من ١٩ أكتوبر ٢٠٢٦', () {
    expect(days, hasLength(30));
    expect((days.first as Map)['date'], '2026-10-19');
    expect((days.last as Map)['date'], '2026-11-17');
  });

  test('مفاتيح المستوى الأعلى', () {
    expect(schedule.keys, containsAll([
      'schemaVersion', 'generatedAt', 'city', 'qibla', 'visible', 'layout', 'opacity',
      'prayerMethod', 'days',
    ]));
    expect(schedule['schemaVersion'], 1);
    expect(schedule['opacity'], 40);
    expect(schedule['generatedAt'], '2026-10-19T09:00:00.000Z');
    expect((schedule['city']! as Map)['name'], 'الرياض');
    final qibla = schedule['qibla']! as Map;
    expect(qibla['degrees'] as double, closeTo(244, 1));
    expect(qibla['direction'], 'جنوب غرب');
    expect(schedule['visible'], {
      for (final e in WidgetElement.values)
        e.name: e == WidgetElement.dates || e == WidgetElement.prayer,
    });
    // التخطيط بترتيبه وقيمه الجاهزة (الميزة ٥)، والترتيب الافتراضي للميزة ٦.
    final layout = (schedule['layout']! as List).cast<Map>();
    expect(layout.map((t) => t['id']), [for (final t in defaultLayout) t.id.name]);
    expect(layout.first, {
      'id': 'clock', 'visible': false, 'span': 2, 'fontScale': 2.0,
      'showTitle': true, 'showSub': false,
      'primaryColor': null, 'secondaryColor': null,
    });
    expect(schedule['digits'], 'arabic');
  });

  test('مفاتيح كل يوم وقيم اليوم الأول', () {
    for (final d in days.cast<Map>()) {
      expect(d.keys, containsAll([
        'date', 'weekday', 'gregorian', 'hijri', 'prayers', 'season',
        'tradSeason', 'deposits',
      ]));
      expect((d['prayers'] as Map).keys,
          ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']);
      expect((d['deposits'] as List).length, inInclusiveRange(1, 3));
    }
    final first = days.first as Map;
    expect(first['weekday'], 'الإثنين');
    expect((first['gregorian'] as Map)['text'], '١٩ أكتوبر ٢٠٢٦');
    expect((first['hijri'] as Map)['text'], '٨ جمادى الأولى ١٤٤٨');
    expect((first['season'] as Map)['name'], 'الخريف');
    expect((first['tradSeason'] as Map)['name'], 'الوسم');
    final deps = (first['deposits'] as List).cast<Map>();
    expect(deps.map((e) => e['label']), ['راتب أكتوبر', 'حساب المواطن']);
    expect(deps.first['remainingText'], 'باقي ٨ أيام');
    final fajr = (first['prayers'] as Map)['fajr'] as Map;
    expect(fajr['name'], 'الفجر');
    expect(DateTime.parse(fajr['time'] as String).isUtc, isTrue);
    expect(fajr['time'] as String, startsWith('2026-10-19T04:'));
  });

  test('يوم الراتب: «اليوم»', () {
    final d = days.cast<Map>().firstWhere((d) => d['date'] == '2026-10-27');
    final dep = (d['deposits'] as List).first as Map;
    expect(dep['daysRemaining'], 0);
    expect(dep['remainingText'], 'اليوم');
  });

  test('قابل للترميز JSON ذهاباً وإياباً', () {
    final text = jsonEncode(schedule);
    expect(jsonDecode(text), schedule);
  });

  test('الإعدادات ترفض الإيداعات الفارغة والشفافية خارج المدى', () {
    expect(() => settings(deposits: {}), throwsArgumentError);
    expect(
        () => Settings(
            latitude: 0, longitude: 0, cityName: 'x', deposits: {'salary'},
            opacity: 101),
        throwsRangeError);
    expect(() => buildSchedule(DateTime(2026), settings(deposits: {'x'}), data),
        throwsArgumentError);
  });

  test('نص الوقت جاهز بالأرقام العربية الشرقية بجانب ISO', () {
    final first = days.first as Map;
    final prayers = first['prayers'] as Map;
    final fajr = prayers['fajr'] as Map;
    final t = DateTime.parse(fajr['time'] as String).add(const Duration(hours: 3));
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    expect(fajr['text'], arabicTimeText(DateTime(2026, 1, 1, t.hour, t.minute)));
    expect(fajr['text'], matches(RegExp(r'^[٠-٩]{1,2}:[٠-٩]{2} ص$')));
    expect(fajr['text'], startsWith(formatDigits(h)));
    expect((prayers['maghrib'] as Map)['text'], endsWith(' م'));
    expect(arabicTimeText(DateTime(2026, 1, 1, 0, 5)), '١٢:٠٥ ص');
    expect(arabicTimeText(DateTime(2026, 1, 1, 12, 0)), '١٢:٠٠ م');
    expect(arabicTimeText(DateTime(2026, 1, 1, 16, 35)), '٤:٣٥ م');
  });

  test('بعد منتصف الليل بتوقيت الرياض وقبله في UTC: يبدأ الجدول باليوم التالي', () {
    // 22:30 UTC يوم ١٩ = 01:30 بتوقيت الرياض يوم ٢٠.
    final s = buildSchedule(DateTime.utc(2026, 10, 19, 22, 30), settings(), data,
        days: 2);
    final d = (s['days']! as List).cast<Map>();
    expect(d.first['date'], '2026-10-20');
    expect(d.first['weekday'], 'الثلاثاء');
    expect(d.last['date'], '2026-10-21');
    final fajr = (d.first['prayers'] as Map)['fajr'] as Map;
    expect(fajr['time'] as String, startsWith('2026-10-20T04:'));
    // وقبل منتصف الليل بدقيقة بتوقيت الرياض: اليوم نفسه.
    final before = buildSchedule(
        DateTime.utc(2026, 10, 19, 20, 59), settings(), data, days: 1);
    expect(((before['days']! as List).first as Map)['date'], '2026-10-19');
  });

  test('background: null افتراضياً، واسم الملف إن وُجد', () {
    expect(schedule.containsKey('background'), isTrue);
    expect(schedule['background'], isNull);
    final withBg = buildSchedule(
      DateTime.utc(2026, 10, 19, 9),
      Settings(
        latitude: 24.7136,
        longitude: 46.6753,
        cityName: 'الرياض',
        deposits: {'salary'},
        background: 'wallpaper.png',
      ),
      data,
      days: 1,
    );
    expect(withBg['background'], 'wallpaper.png');
    // generatedAt افتراضياً = لحظة البناء الممررة، لا ساعة الجهاز.
    expect(withBg['generatedAt'], '2026-10-19T09:00:00.000Z');
  });

  // الميزة ٦: الإيداعات بأيامها (حتى ستة)، ونقاط الموسم، و«بعد» للفصل والموسم، والأرقام الإنجليزية.
  test('الإيداعات الأقرب أولاً، ونقاط الوسم، و«بعد ٦٣ يوماً»', () {
    final s3 = buildSchedule(
      DateTime.utc(2026, 10, 19, 9),
      settings(deposits: {'salary', 'citizen_account', 'housing_support', 'social_security'}),
      data,
      days: 1,
    );
    final day = (s3['days']! as List).first as Map;
    final deps = (day['deposits'] as List).cast<Map>();
    expect([for (final d in deps) d['label']],
        ['الدعم السكني', 'راتب أكتوبر', 'الضمان الاجتماعي', 'حساب المواطن']);
    expect([for (final d in deps) d['daysText']],
        ['٦ أيام', '٨ أيام', '١٣ يوماً', '٢٢ يوماً']);

    // الستة كلها (طلب المالك): التأهيل الشامل ٢٦ أكتوبر، والمعاشات مع الضمان.
    final all = buildSchedule(
      DateTime.utc(2026, 10, 19, 9),
      settings(deposits: data.deposits.ids),
      data,
      days: 1,
    );
    final six = (((all['days']! as List).first as Map)['deposits'] as List).cast<Map>();
    expect([for (final d in six) d['label']], [
      'الدعم السكني', 'التأهيل الشامل', 'راتب أكتوبر', 'الضمان الاجتماعي',
      'معاشات المتقاعدين', 'حساب المواطن',
    ]);
    expect(six[1]['daysText'], '٧ أيام');
    final trad = day['tradSeason'] as Map;
    expect(trad['points'], [
      'تتدنى درجات الحرارة خلال الليل.',
      'ترتفع فيه فرص هطول الأمطار النافعة.',
    ]);
    expect((day['season'] as Map)['afterText'], startsWith('بعد '));
    expect(trad['afterText'], startsWith('بعد '));
  });

  test('الأرقام الإنجليزية: كل النصوص الجاهزة، وISO كما هو', () {
    Settings latin() => Settings(
          latitude: 24.7136,
          longitude: 46.6753,
          cityName: 'الرياض',
          deposits: {'salary'},
          digits: DigitStyle.latin,
        );
    final s = buildSchedule(DateTime.utc(2026, 10, 19, 9), latin(), data,
        days: 1, generatedAt: DateTime.utc(2026, 10, 19, 9));
    final text = jsonEncode(s);
    expect(RegExp('[٠-٩]').hasMatch(text), isFalse);
    expect(s['digits'], 'latin');
    final day = (s['days']! as List).first as Map;
    expect((day['hijri'] as Map)['text'], '8 جمادى الأولى 1448');
    expect((day['gregorian'] as Map)['text'], '19 أكتوبر 2026');
    expect(((day['prayers'] as Map)['fajr'] as Map)['text'], matches(RegExp(r'^\d:\d\d ص$')));
    expect(((day['prayers'] as Map)['fajr'] as Map)['time'], startsWith('2026-10-19T'));
    expect(s['generatedAt'], '2026-10-19T09:00:00.000Z');
    expect((day['deposits'] as List).first['remainingText'], 'باقي 8 أيام');
  });
}
