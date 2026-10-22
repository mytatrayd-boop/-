import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/app/widget_preview.dart';
import 'package:lamha/src/engine/arabic.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'app_helpers.dart';

double sizeOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).style!.fontSize!;

void main() {
  group('حجم الخط', () {
    test('المعاملات والافتراضي', () {
      expect(
        [for (final f in FontScale.values) f.factor],
        [0.9, 1.0, 1.15, 1.3],
      );
      expect(FontScale.fallback, FontScale.medium);
      expect(FontScale.byName('xlarge'), FontScale.xlarge);
      expect(FontScale.byName(null), FontScale.medium);
      expect(FontScale.byName('huge'), FontScale.medium);
    });

    test('يُحفظ في الإعدادات ويُقرأ، والإعدادات القديمة بلاه = متوسط', () {
      final city = parseCities(readAsset('assets/cities.json')).first;
      final s = LamhaSettings.defaults(city, {
        'salary',
      }).copyWith(fontScale: FontScale.large);
      final back = LamhaSettings.fromJson(
        jsonDecode(s.encode()) as Map<String, dynamic>,
      );
      expect(back.fontScale, FontScale.large);
      expect(back.toEngine().fontScale, FontScale.large);
      final old = s.toJson()..remove('fontScale');
      expect(
        LamhaSettings.fromJson(old.cast<String, dynamic>()).fontScale,
        FontScale.medium,
      );
    });

    testWidgets(
      'الاختيار يحفظ fontScale في الجدول والإعدادات وتطبقه المعاينة',
      (tester) async {
        final bridge = await pumpApp(tester);
        expect(bridge.last['fontScale'], 1.0);
        // الهجري ١٦ × المعامل، يصغر فقط إن لم يتسع (الميزة ٥ب).
        final medium = sizeOf(tester, const Key('preview-hijri'));
        expect(medium, lessThanOrEqualTo(16));
        final chip = find.byKey(const Key('font-xlarge'));
        expect(find.text('كبير جداً'), findsOneWidget);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(bridge.last['fontScale'], 1.3);
        // خط الاختبار عريض فقد يحدّ العرضُ الهجري؛ الحرارة تكبر.
        expect(sizeOf(tester, const Key('preview-hijri')), greaterThanOrEqualTo(medium - 0.01));
        expect(sizeOf(tester, const Key('preview-temp')), greaterThan(28));
        expect(
          sizeOf(tester, const Key('preview-day')),
          lessThanOrEqualTo(22 * 1.3),
        );
        final prefs = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
        expect(saved['fontScale'], 'xlarge');
      },
    );

    testWidgets('الساعة أكبر عنصر بعرض عمودين، بلا يوم تحتها (الميزة ٦)', (
      tester,
    ) async {
      await pumpApp(tester);
      final clock = sizeOf(tester, const Key('preview-clock'));
      // ٥٢ × ٢ مطلوب، وتصغر بقدر مربعها فقط.
      expect(clock, lessThanOrEqualTo(104));
      expect(clock, greaterThan(sizeOf(tester, const Key('preview-day')) * 2));
      final cell = tester.getRect(
        find.descendant(
          of: find.byKey(const Key('preview-background')),
          matching: find.byKey(const Key('tile-clock')),
        ),
      );
      final face = tester.getRect(find.byKey(const Key('preview-clock')));
      expect(face.left, greaterThanOrEqualTo(cell.left - 0.5));
      expect(face.right, lessThanOrEqualTo(cell.right + 0.5));
      expect(find.byKey(const Key('preview-weekday')), findsNothing);
      // اليوم والطقس يسار الساعة، والعمودان متوسطان رأسياً في صفهما.
      final day = tester.getRect(find.byKey(const Key('tile-dayWeather')));
      expect(cell.left, greaterThan(day.right));
      expect(cell.center.dy, closeTo(day.center.dy, 0.5));
    });
  });

  group('دوال الملاءمة (مطابقة لـ LamhaLogic.kt)', () {
    test('fitTextSize يصغر فقط عند الحاجة وبحد أدنى', () {
      expect(fitTextSize(44, 120, 150, 28), 44);
      expect(fitTextSize(44, 200, 150, 28), 33);
      expect(fitTextSize(44, 400, 150, 28), 28);
      expect(fitTextSize(44, 0, 150, 28), 44);
    });

    test('fittingLines', () {
      expect(fittingLines(0, 17.5, 2), 1);
      expect(fittingLines(17.5, 17.5, 2), 2);
      expect(fittingLines(100, 17.5, 2), 2);
      expect(fittingLines(-5, 17.5, 2), 1);
    });
  });

  test('العدّاد بصيغة Chronometer', () {
    expect(
      countdownClock(const Duration(hours: 6, minutes: 4, seconds: 19)),
      '٦:٠٤:١٩',
    );
    expect(countdownClock(const Duration(minutes: 4, seconds: 9)), '٠٤:٠٩');
    expect(countdownClock(const Duration(seconds: -3)), '٠٠:٠٠');
  });
}
