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
        expect(sizeOf(tester, const Key('preview-weekday')), 18);
        final chip = find.byKey(const Key('font-xlarge'));
        expect(find.text('كبير جداً'), findsOneWidget);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(bridge.last['fontScale'], 1.3);
        expect(
          sizeOf(tester, const Key('preview-weekday')),
          closeTo(18 * 1.3, 1e-9),
        );
        // المدينة والطقس ١٦ × المعامل، أو أصغر قليلاً إن لم يتسع (حتى ٧٥٪).
        expect(
          sizeOf(tester, const Key('preview-weather')),
          inInclusiveRange(16 * 1.3 * 0.75, 16 * 1.3),
        );
        final prefs = await SharedPreferences.getInstance();
        final saved =
            jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
        expect(saved['fontScale'], 'xlarge');
      },
    );

    testWidgets('الساعة ٥٢ في الحجم المتوسط، والعمودان متوسطان رأسياً', (
      tester,
    ) async {
      await pumpApp(tester);
      final clock = sizeOf(tester, const Key('preview-clock'));
      expect(clock, lessThanOrEqualTo(52));
      expect(clock, greaterThanOrEqualTo(clockMinSize));
      final right = tester.getRect(
        find.byKey(const Key('preview-clock-column')),
      );
      final left = tester.getRect(find.byKey(const Key('preview-date-column')));
      expect(right.center.dy, closeTo(left.center.dy, 0.5));
      // اليوم تحت الساعة مباشرة.
      final gap =
          tester.getRect(find.byKey(const Key('preview-weekday'))).top -
          tester.getRect(find.byKey(const Key('preview-clock'))).bottom;
      expect(gap, inInclusiveRange(-0.5, 2));
    });
  });

  group('دوال الملاءمة (مطابقة لـ LamhaLogic.kt)', () {
    test('fitTextSize يصغر فقط عند الحاجة وبحد أدنى', () {
      expect(fitTextSize(44, 120, 150, 28), 44);
      expect(fitTextSize(44, 200, 150, 28), 33);
      expect(fitTextSize(44, 400, 150, 28), 28);
      expect(fitTextSize(44, 0, 150, 28), 44);
    });

    test('clockAvailableWidth: ما يبقى بعد العمود الأيسر، و٤٠٪ على الأقل', () {
      expect(clockAvailableWidth(310, 150, 20), 310 - 8 - 150 - 20 - 4);
      expect(clockAvailableWidth(310, 280, 20), 310 * 0.4 - 20 - 4);
    });

    test('leftColumnWidth من الأعرض بين سطر الساعة واليوم', () {
      expect(leftColumnWidth(310, 120, 80), 310 - 8 - 120);
      expect(leftColumnWidth(310, 60, 80), 310 - 8 - 80);
    });

    test('tileFitScale: معامل المستخدم إن اتسع، وإلا أصغر بحد ٠٫٦', () {
      const lines = [13.0, 20.0, 14.0, 14.0];
      // (13+20+14+14) × 1.25 = 76.25، وثلاثة فواصل = 9.
      expect(tileFitScale(1.0, 97.5, lines), 1.0);
      expect(tileFitScale(1.3, 90.5, lines), closeTo((90.5 - 9) / 76.25, 1e-9));
      expect(tileFitScale(1.3, 10, lines), 0.6);
      expect(tileFitScale(1.3, 0, lines), 1.3);
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
