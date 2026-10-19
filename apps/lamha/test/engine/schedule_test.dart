import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
        visible: {WidgetElement.hijri, WidgetElement.prayer},
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
      'schemaVersion', 'generatedAt', 'city', 'qibla', 'visible', 'opacity',
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
      'hijri': true, 'gregorian': false, 'weather': false, 'prayer': true,
      'qibla': false, 'deposit': false, 'season': false, 'tradSeason': false,
    });
  });

  test('مفاتيح كل يوم وقيم اليوم الأول', () {
    for (final d in days.cast<Map>()) {
      expect(d.keys, containsAll([
        'date', 'weekday', 'gregorian', 'hijri', 'prayers', 'season',
        'tradSeason', 'deposits',
      ]));
      expect((d['prayers'] as Map).keys,
          ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha']);
      expect((d['deposits'] as List).length, inInclusiveRange(1, 2));
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
}
