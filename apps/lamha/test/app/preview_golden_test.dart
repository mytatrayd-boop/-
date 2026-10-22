import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  // الحجم المتوسط (mockups/settings_preview.png)، و«كبير جداً» للتأكد من أن لا قص ولا تداخل.
  for (final (scale, file) in [
    (FontScale.medium, 'settings_preview.png'),
    (FontScale.xlarge, 'settings_preview_xlarge.png'),
  ]) {
    testWidgets(
      'لقطة المعاينة (أندرويد، ذهبي، شفافية ٨٠، طقس، خط ${scale.name})',
      (tester) async {
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
            longitude: 46.7219,
          ),
        );

        const size = Size(370, 386);
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
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
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('golden')),
          matchesGoldenFile('goldens/$file'),
        );
      },
      tags: ['golden'],
    );
  }

  // الميزة ٥ب: حجم مربع واحد يُحترم داخل مقاسه، كحالات لقطات أندرويد (LamhaScreens).
  for (final (id, scale) in [
    (WidgetElement.prayerTimes, 2.0),
    (WidgetElement.tradSeason, 1.8),
    (WidgetElement.clock, 1.5),
    (WidgetElement.deposit, 2.0),
  ]) {
    testWidgets(
      '${id.name} بحجم $scale: القيمة ≥ ٩٠٪ من المطلوب إن اتسعت كلمة، وكاملة بلا «…»',
      (tester) async {
        await _loadFont('Tajawal', [
          'assets/fonts/Tajawal-Regular.ttf',
          'assets/fonts/Tajawal-Bold.ttf',
        ]);
        final now = DateTime.utc(2026, 10, 19, 0); // ٣:٠٠ ص بالرياض.
        final schedule = buildSchedule(
          now,
          Settings(
            latitude: 24.6877,
            longitude: 46.7219,
            cityName: 'الرياض',
            deposits: {'salary', 'citizen_account'},
            layout: [
              for (final t in defaultLayout)
                t.id == id ? t.copyWith(fontScale: scale) : t,
            ],
          ),
          loadEngineDataFromFiles(),
          days: 2,
          generatedAt: now,
        );
        tester.view.physicalSize = const Size(370, 386) * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: ThemeData(fontFamily: 'Tajawal'),
            home: Material(
              child: WidgetPreview(schedule: schedule, now: now),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final values = find.byKey(const Key('tile-value'));
        // مربعات المعلومات الظاهرة في الترتيب الافتراضي: الفصل والموسم.
        expect(values, findsNWidgets(2));
        for (final e in values.evaluate()) {
          final text = e.widget as Text;
          final p = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byWidget(text),
              matching: find.byType(RichText),
            ),
          );
          expect(p.didExceedMaxLines, isFalse, reason: text.data);
        }
        final valueFinder = find.descendant(
          of: find.byKey(Key('tile-${id.name}')),
          matching: find.byKey(const Key('tile-value')),
        );
        // مربعات الأعمدة: كل الأعمدة ظاهرة بحجم واحد، والاسم سطر واحد كامل.
        if (id == WidgetElement.prayerTimes || id == WidgetElement.deposit) {
          final prefix = id == WidgetElement.prayerTimes ? 'prayer' : 'deposit';
          final n = id == WidgetElement.prayerTimes ? 5 : 2;
          final sizes = <double?>{};
          for (var i = 0; i < n; i++) {
            final f = find.byKey(Key('$prefix-name-$i'));
            expect(f, findsOneWidget);
            sizes.add(tester.widget<Text>(f).style!.fontSize);
            final p = tester.renderObject<RenderParagraph>(
              find.descendant(of: f, matching: find.byType(RichText)),
            );
            expect(p.didExceedMaxLines, isFalse);
            expect(p.size.width, lessThanOrEqualTo(tester.getSize(f).width + 0.5));
          }
          expect(sizes, hasLength(1));
          expect(sizes.single, lessThanOrEqualTo(20 * scale));
          return;
        }
        if (id == WidgetElement.clock) {
          final clock = tester.widget<Text>(
            find.byKey(const Key('preview-clock')),
          );
          // الساعة بعرض ١ محدودة بعرض مربعها: تصغر بقدره فقط، ولا تتجاوزه.
          expect(clock.style!.fontSize, lessThanOrEqualTo(52 * scale));
          final cell = tester.getRect(find.byKey(const Key('tile-clock')));
          expect(
            tester.getRect(find.byKey(const Key('preview-clock'))).right,
            lessThanOrEqualTo(cell.right + 0.5),
          );
          return;
        }
        final text = tester.widget<Text>(valueFinder);
        final requested = 20 * scale;
        final painter = TextPainter(textDirection: TextDirection.rtl);
        var widest = 0.0;
        for (final w in text.data!.split(' ')) {
          painter
            ..text = TextSpan(
              text: w,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: requested,
                fontWeight: FontWeight.w700,
              ),
            )
            ..layout();
          widest = widest < painter.width ? painter.width : widest;
        }
        painter.dispose();
        final width = tester.getSize(valueFinder).width;
        if (widest <= width - 2) {
          expect(
            text.style!.fontSize,
            greaterThanOrEqualTo(requested * 0.9),
            reason: text.data,
          );
        }
      },
    );
  }
}
