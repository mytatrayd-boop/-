import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/app/widget_preview.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:lamha/src/engine/weather.dart';

import '../helpers.dart';

/// لقطة المعاينة بخط Tajawal (تُحدَّث بـ --update-goldens، وتُنسخ يدوياً إلى
/// mockups/settings_preview.png).
Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(
        ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  // الحجم المتوسط (mockups/settings_preview.png)، و«كبير جداً» للتأكد من أن لا قص ولا تداخل.
  for (final (scale, file) in [
    (FontScale.medium, 'settings_preview.png'),
    (FontScale.xlarge, 'settings_preview_xlarge.png'),
  ]) {
  testWidgets('لقطة المعاينة (أندرويد، ذهبي، شفافية ٨٠، طقس، خط ${scale.name})', (tester) async {
    await _loadFont('Tajawal', [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
    ]);
    const emoji = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
    final hasEmoji = File(emoji).existsSync();
    if (hasEmoji) await _loadFont('NotoColorEmoji', [emoji]);

    final now = DateTime.utc(2026, 10, 19, 13, 11); // ٤:١١ م بالرياض.
    final schedule = buildSchedule(
      now,
      Settings(
        latitude: 24.6877,
        longitude: 46.7219,
        cityName: 'الرياض',
        deposits: {'salary', 'citizen_account'},
        opacity: 80,
        fontScale: scale,
      ),
      loadEngineDataFromFiles(),
      days: 2,
      generatedAt: now,
      weather: WeatherReading(
          temp: 31.4,
          code: 0,
          fetchedAt: now.subtract(const Duration(minutes: 20)),
          latitude: 24.6877,
          longitude: 46.7219),
    );

    const size = Size(370, 386);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        platform: TargetPlatform.android,
        fontFamily: 'Tajawal',
        fontFamilyFallback: hasEmoji ? const ['NotoColorEmoji'] : null,
      ),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(
          key: const Key('golden'),
          child: WidgetPreview(schedule: schedule, now: now),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byKey(const Key('golden')),
        matchesGoldenFile('goldens/$file'));
  }, tags: ['golden']);
  }
}
