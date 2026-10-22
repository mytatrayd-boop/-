import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/arabic.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:lamha/src/engine/weather.dart';
import 'package:lamha/src/engine/widget_theme.dart';

import '../helpers.dart';

/// جدول اختبار لقطات الودجت على محاكي أندرويد (androidTest/assets)، مولّد من المحرك.
/// يُعاد توليده بـ: LAMHA_UPDATE_FIXTURES=1 flutter test test/app/android_fixture_test.dart
const _dir = 'android/app/src/androidTest/assets';

/// اللحظة الثابتة للاختبار (LamhaScreensTest.NOW_MILLIS): ٣:٠٠ ص بتوقيت أبها، قبل الفجر.
final fixtureNow = DateTime.utc(2026, 10, 19, 0, 0);

String fixture(WidgetTheme theme, {DigitStyle digits = DigitStyle.arabic}) {
  // قرب أبها، حيث القبلة ٣٢٤° (كلقطة المالك؛ مركز أبها ٣٢٢°).
  const lat = 18.20, lon = 42.33;
  final schedule = buildSchedule(
    fixtureNow,
    Settings(
      latitude: lat,
      longitude: lon,
      cityName: 'أبها',
      deposits: {'salary', 'housing_support', 'citizen_account'},
      opacity: 80,
      theme: theme,
      digits: digits,
    ),
    loadEngineDataFromFiles(),
    days: 2,
    generatedAt: fixtureNow,
    weather: WeatherReading(
        temp: 26.2,
        code: 0,
        fetchedAt: fixtureNow.subtract(const Duration(minutes: 20)),
        latitude: lat,
        longitude: lon),
  );
  return '${const JsonEncoder.withIndent('  ').convert(schedule)}\n';
}

void main() {
  // الأسود الافتراضي والذهبي والأزرق، ونسخة بالأرقام الإنجليزية (الميزة ٦).
  for (final (name, theme, digits) in [
    ('black', WidgetTheme.black, DigitStyle.arabic),
    ('gold', WidgetTheme.gold, DigitStyle.arabic),
    ('blue', WidgetTheme.blue, DigitStyle.arabic),
    ('latin', WidgetTheme.black, DigitStyle.latin),
  ]) {
    test('جدول لقطات أندرويد ($name) مطابق للمحرك', () {
      final file = File('$_dir/schedule_$name.json');
      final json = fixture(theme, digits: digits);
      if (Platform.environment['LAMHA_UPDATE_FIXTURES'] == '1') {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(json);
      }
      expect(file.readAsStringSync(), json);

      final day = (jsonDecode(json)['days'] as List).first as Map;
      expect(day['tradSeason']['name'], 'الوسم');
      expect(day['season']['name'], 'الخريف');
      expect(jsonDecode(json)['qibla']['text'],
          digits == DigitStyle.latin ? '324° شمال غرب' : '٣٢٤° شمال غرب');
      expect([for (final d in day['deposits'] as List) d['label']],
          ['الدعم السكني', 'راتب أكتوبر', 'حساب المواطن']);
    });
  }
}
