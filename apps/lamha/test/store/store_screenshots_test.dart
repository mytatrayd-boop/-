import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/l10n/app_localizations.dart';
import 'package:lamha/src/app/widget_preview.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:lamha/src/engine/weather.dart';
import 'package:lamha/src/engine/widget_theme.dart';

import '../app/app_helpers.dart';
import '../app/customize_screen_test.dart' show openCustomize, select;
import '../helpers.dart';

/// صور المتجرين: Google Play في store/play (لقطات ١٠٨٠×١٩٢٠، وصورة العرض ١٠٢٤×٥٠٠)، وApp Store
/// في store/appstore (لقطات آيفون ٦٫٩ بوصة ١٢٩٠×٢٧٩٦، وآيباد ١٣ بوصة ٢٠٤٨×٢٧٣٢ في store/appstore/ipad).
/// لا تعمل في الاختبارات العادية: تُولَّد بـ
///   LAMHA_STORE=1 flutter test test/store/store_screenshots_test.dart --update-goldens
final _enabled = Platform.environment['LAMHA_STORE'] == '1';

Future<void> _loadFonts() async {
  final loader = FontLoader('Tajawal');
  for (final p in [
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Tajawal-Medium.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
  ]) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
  const emoji = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
  if (File(emoji).existsSync()) {
    final e = FontLoader('NotoColorEmoji')
      ..addFont(Future.value(ByteData.sublistView(File(emoji).readAsBytesSync())));
    await e.load();
  }
}

// ٤:١١ م بالرياض: الصلاة القادمة المغرب، والإيداعات الستة.
final _now = DateTime.utc(2026, 10, 19, 13, 11);

Map<String, Object?> _schedule(WidgetTheme theme) {
  final data = loadEngineDataFromFiles();
  return buildSchedule(
    _now,
    Settings(
      latitude: 24.6877,
      longitude: 46.7219,
      cityName: 'الرياض',
      deposits: data.deposits.ids,
      opacity: 85,
      theme: theme,
    ),
    data,
    days: 2,
    generatedAt: _now,
    weather: WeatherReading(
      temp: 31.4,
      code: 0,
      fetchedAt: _now.subtract(const Duration(minutes: 20)),
      latitude: 24.6877,
      longitude: 46.7219,
    ),
  );
}

const _bgTop = Color(0xFF0B1220);
const _bgBottom = Color(0xFF1E2B3F);
const _gold = Color(0xFFD6AA5C);
const _text = Color(0xFFF4EFE6);

Widget _app(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        platform: TargetPlatform.android,
        fontFamily: 'Tajawal',
        fontFamilyFallback: const ['NotoColorEmoji'],
      ),
      home: Material(child: child),
    );

/// إطار لقطة: عنوان ذهبي وسطر تحته، ثم معاينة الودجت بحجمها الحقيقي مكبّرة لتملأ العرض.
Widget _frame(String title, String sub, WidgetTheme theme) => DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _gold, fontSize: 34, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 10),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _text, fontSize: 17, height: 1.5)),
            const SizedBox(height: 24),
            Expanded(
              child: FittedBox(
                child: SizedBox(
                  width: 370,
                  height: 472,
                  child: WidgetPreview(schedule: _schedule(theme), now: _now),
                ),
              ),
            ),
          ],
        ),
      ),
    );

Future<void> _shot(WidgetTester tester, Size logical, double dpr, Widget child, String file,
    {String dir = 'play'}) async {
  await _loadFonts();
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child));
  await tester.pumpAndSettle();
  await loadImages(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../store/$dir/$file'));
}

void main() {
  // (المجلد، المقاس المنطقي، الكثافة): ١٠٨٠×١٩٢٠ لـ Play، و١٢٩٠×٢٧٩٦ لآيفون ٦٫٩ بوصة،
  // و٢٠٤٨×٢٧٣٢ لآيباد ١٣ بوصة (أبل تشترطها لأن التطبيق يعمل على آيباد).
  for (final (dir, logical, dpr) in [
    ('play', const Size(1080 / 2.625, 1920 / 2.625), 2.625),
    ('appstore', const Size(430, 932), 3.0),
    ('appstore/ipad', const Size(1024, 1366), 2.0),
  ]) {
    for (final (file, title, sub, theme) in [
      ('01-widget.png', 'يومك كله في لمحة',
          'الساعة والتاريخان والطقس والصلاة والإيداعات والمواسم في ودجت عربية واحدة',
          WidgetTheme.black),
      ('02-deposits.png', 'مواعيد الإيداعات',
          'الراتب والضمان وحساب المواطن والدعم السكني والتأهيل الشامل والمعاشات، مع الأيام المتبقية',
          WidgetTheme.blue),
      ('03-colors.png', 'بالألوان التي تحبها',
          'سبع سمات وشفافية تختارها، وأيقونة القبلة تتلون معها',
          WidgetTheme.green),
    ]) {
      testWidgets('store $dir/$file', (tester) async {
        await _shot(tester, logical, dpr, _frame(title, sub, theme), file, dir: dir);
      }, skip: !_enabled);
    }

    testWidgets('store $dir/04-customize.png', (tester) async {
      await _loadFonts();
      await openCustomize(tester);
      tester.view.physicalSize = logical * dpr;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      await select(tester, 'deposit');
      await loadImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../store/$dir/04-customize.png'));
    }, skip: !_enabled);

    testWidgets('store $dir/05-settings.png', (tester) async {
      await _loadFonts();
      await pumpApp(tester);
      tester.view.physicalSize = logical * dpr;
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      await loadImages(tester);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../../store/$dir/05-settings.png'));
    }, skip: !_enabled);
  }

  testWidgets('store feature-graphic.png', (tester) async {
    await _shot(
      tester,
      const Size(512, 250),
      2,
      DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_bgBottom, _bgTop]),
        ),
        child: Row(
          children: [
            const SizedBox(width: 36),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('لمحة',
                      style: TextStyle(color: _gold, fontSize: 56, fontWeight: FontWeight.w700, height: 1.1)),
                  SizedBox(height: 8),
                  Text('ودجت عربية تجمع يومك:\nالصلاة والقبلة والإيداعات والمواسم',
                      style: TextStyle(color: _text, fontSize: 17, height: 1.5)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: FittedBox(
                child: SizedBox(
                  width: 370,
                  height: 472,
                  child: WidgetPreview(schedule: _schedule(WidgetTheme.black), now: _now),
                ),
              ),
            ),
            const SizedBox(width: 30),
          ],
        ),
      ),
      'feature-graphic.png',
    );
  }, skip: !_enabled);
}
