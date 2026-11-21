import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:lamha/src/engine/weather.dart';

import '../helpers.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);
  WeatherReading reading({double temp = 31.4, int code = 0, Duration age = Duration.zero}) =>
      WeatherReading(
          temp: temp, code: code, fetchedAt: now.subtract(age), latitude: 24.69, longitude: 46.72);

  test('رمز WMO إلى رمز تعبيري ونص عربي', () {
    expect(weatherCondition(0), (emoji: '☀️', text: 'صحو'));
    expect(weatherCondition(3).text, 'غائم');
    expect(weatherCondition(63).text, 'مطر');
    expect(weatherCondition(95).emoji, '⛈️');
    expect(weatherCondition(45).text, 'ضباب');
    // كل رموز Open-Meteo لها نص، والمجهول ميزان حرارة.
    for (final c in [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77,
      80, 81, 82, 85, 86, 95, 96, 99]) {
      expect(weatherConditions[c]!.text, isNotEmpty, reason: '$c');
    }
    expect(weatherCondition(42), (emoji: '🌡️', text: ''));
  });

  test('الحرارة بالأرقام العربية وتقريب Dart', () {
    // معزولة باتجاه LTR فتبقى الدرجة يمين الرقم «٢٦°» (الميزة ٦).
    expect(temperatureText(31.4), '\u2066٣١°\u2069');
    expect(temperatureText(31.5), '\u2066٣٢°\u2069');
    expect(temperatureText(-2.5), '\u2066-٣°\u2069');
    expect(temperatureText(-0.4), '\u2066٠°\u2069');
  });

  test('عمر القراءة: حتى ٣ ساعات، وبعدها «--°» (null)', () {
    expect(weatherText(reading(), now), '☀️ \u2066٣١°\u2069');
    expect(weatherText(reading(age: const Duration(hours: 3)), now), '☀️ \u2066٣١°\u2069');
    expect(weatherText(reading(age: const Duration(hours: 3, minutes: 1)), now), isNull);
    expect(weatherText(null, now), isNull);
  });

  test('قراءة رد Open-Meteo', () {
    final r = parseOpenMeteo({
      'current': {'time': '2026-10-19T15:00', 'temperature_2m': 29.8, 'weather_code': 2},
    }, now, 18.2, 42.5);
    expect(r.temp, 29.8);
    expect(r.code, 2);
    expect(r.fetchedAt, now);
    expect(() => parseOpenMeteo({'error': true}, now, 0, 0), throwsFormatException);
    final u = openMeteoUri(18.2, 42.5).toString();
    expect(u, contains('latitude=18.2&longitude=42.5'));
    expect(u, contains('current=temperature_2m,weather_code'));
    expect(u, contains('timezone=auto'));
  });

  test('الجدول يحمل القراءة وجدول الرموز، وقراءة مدينة أخرى لا تُكتب', () {
    Map<String, Object?> build(WeatherReading? w) => buildSchedule(
          now,
          Settings(latitude: 24.69, longitude: 46.72, cityName: 'الرياض', deposits: {'salary'}),
          loadEngineDataFromFiles(),
          days: 1,
          weather: w,
        );
    final w = build(reading(code: 3))['weather']! as Map;
    expect(w['temp'], 31.4);
    expect(w['code'], 3);
    expect(w['fetchedAt'], now.toIso8601String());
    expect(w['emoji'], '☁️');
    expect(w['text'], 'غائم');
    expect(w['maxAgeMinutes'], 180);
    expect((w['icons'] as Map)['95'], '⛈️');
    final other = WeatherReading(
        temp: 20, code: 0, fetchedAt: now, latitude: 18.2, longitude: 42.5);
    expect((build(other)['weather']! as Map).containsKey('temp'), isFalse);
    expect((build(null)['weather']! as Map).containsKey('temp'), isFalse);
    // الرحلة ذهاباً وإياباً.
    final back = WeatherReading.fromJson(reading().toJson().cast<String, dynamic>());
    expect(back.fetchedAt, now);
  });
}
