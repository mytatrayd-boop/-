import 'dart:ui' as ui;

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/domain/weather_symbol.dart';
import 'package:durur/src/features/common/weather_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// D23: مجموعة رموز الجو الموحّدة المغلقة (17 رمزاً)، ولكل رمز أيقونة ونص.
void main() {
  const d23 = [
    'hot',
    'very_hot',
    'mild',
    'cool',
    'cold',
    'very_cold',
    'wind',
    'wind_strong',
    'rain',
    'heavy_rain',
    'thunder',
    'cloud',
    'dust',
    'humidity',
    'fog',
    'sea_calm',
    'sea_rough',
  ];

  test('المجموعة = قائمة D23 بالضبط (17 رمزاً)', () {
    expect(WeatherSymbol.values.map((s) => s.code).toList(), d23);
  });

  test('كل رمز يُحلَّل من JSON، وما خارج المجموعة مرفوض', () {
    for (final code in d23) {
      expect(WeatherSymbol.parse(code, 't').code, code);
    }
    // star_rise أيقونة واجهة لا رمز جو (D23).
    for (final bad in ['star_rise', 'snow', '']) {
      expect(() => WeatherSymbol.parse(bad, 't'), throwsFormatException);
    }
  });

  test('لكل رمز اسم عربي غير فارغ ومختلف في ملف الترجمة', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final names = {
      for (final s in WeatherSymbol.values) weatherSymbolLabel(l10n, s),
    };
    expect(names, hasLength(17));
    expect(names.every((n) => n.trim().isNotEmpty), isTrue);
    expect(weatherSymbolLabel(l10n, WeatherSymbol.veryCold), 'برد شديد');
    expect(weatherSymbolLabel(l10n, WeatherSymbol.seaRough), 'بحر هائج');
  });

  test('لكل رمز أيقونة ترسم بلا خطأ', () {
    for (final s in WeatherSymbol.values) {
      final recorder = ui.PictureRecorder();
      WeatherIconPainter(
        s,
        Colors.black,
      ).paint(Canvas(recorder), const Size.square(24));
      expect(recorder.endRecording(), isNotNull, reason: s.code);
    }
  });
}
