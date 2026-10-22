import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:lamha/src/engine/weather.dart';
import 'package:lamha/src/engine/widget_theme.dart';

import '../helpers.dart';
import 'app_helpers.dart';

/// لون التمييز في المعاينة: الصلاة القادمة (أول عمود في مواقيت الصلاة، الميزة ٦).
Color weekdayColor(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('prayer-name-0'))).style!.color!;

/// الحرارة في مربع اليوم والطقس (الميزة ٦).
String weatherLine(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('preview-temp'))).data!;

void main() {
  group('الطقس', () {
    testWidgets('يُجلب عند فتح التطبيق ويُحفظ في الجدول والإعدادات وتعرضه المعاينة', (tester) async {
      final weather = FakeWeather(temp: 31.4, code: 0);
      final bridge = await pumpApp(tester, weather: weather);
      expect(weather.calls, hasLength(1));
      expect(weatherLine(tester), '\u2066٣١°\u2069');
      final w = bridge.last['weather'] as Map;
      expect(w['emoji'], '☀️');
      expect(w['temp'], 31.4);
      expect(w['code'], 0);
      expect(w['fetchedAt'], testNow.toIso8601String());
    });

    testWidgets('بلا إنترنت ولا قراءة سابقة: «--°»', (tester) async {
      await pumpApp(tester);
      expect(weatherLine(tester), contains('--°'));
    });

    testWidgets('بلا إنترنت: آخر قراءة، وبعد ٣ ساعات «--°»', (tester) async {
      Map<String, Object> prefs(Duration age) => {
            weatherPrefsKey: jsonEncode(WeatherReading(
                    temp: 25,
                    code: 3,
                    fetchedAt: testNow.subtract(age),
                    latitude: 24.6877,
                    longitude: 46.7219)
                .toJson()),
          };
      await pumpApp(tester, prefs: prefs(const Duration(hours: 2)));
      expect(weatherLine(tester), '\u2066٢٥°\u2069');
    });

    testWidgets('قراءة أقدم من ٣ ساعات: «--°»', (tester) async {
      await pumpApp(tester, prefs: {
        weatherPrefsKey: jsonEncode(WeatherReading(
                temp: 25,
                code: 3,
                fetchedAt: testNow.subtract(const Duration(hours: 4)),
                latitude: 24.6877,
                longitude: 46.7219)
            .toJson()),
      });
      expect(weatherLine(tester), contains('--°'));
    });

    testWidgets('تغيير المدينة يجلب طقسها', (tester) async {
      final weather = FakeWeather();
      await pumpApp(tester, weather: weather);
      await tester.tap(find.byKey(const Key('city-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('أبها').last);
      await tester.pumpAndSettle();
      expect(weather.calls, hasLength(2));
      expect(weather.calls.last.latitude, closeTo(18.2, 0.1));
    });
  });

  group('السمات', () {
    testWidgets('الأسود افتراضي بتمييز ذهبي، والزر يغيّر لون التمييز ويحفظ السمة في الجدول', (tester) async {
      final bridge = await pumpApp(tester);
      expect(weekdayColor(tester), const Color(0xFFD6AA5C));
      expect((bridge.last['theme'] as Map)['id'], 'black');
      expect((bridge.last['theme'] as Map)['background'], 0xFF000000);
      expect(find.byKey(const Key('theme-system')), findsOneWidget);
      await tester.tap(find.byKey(const Key('theme-blue')));
      await tester.pumpAndSettle();
      expect(weekdayColor(tester), Color(WidgetTheme.blue.accent));
      expect((bridge.last['theme'] as Map)['id'], 'blue');
      expect((bridge.last['theme'] as Map)['accent'], WidgetTheme.blue.accent);
    });

    testWidgets('ألوان النظام إن توفرت، وإلا الذهبي', (tester) async {
      await pumpApp(tester,
          systemColors: FakeSystemColors((accent: 0xFF336699, background: 0xFF101820)));
      await tester.tap(find.byKey(const Key('theme-system')));
      await tester.pumpAndSettle();
      expect(weekdayColor(tester), const Color(0xFF336699));
    });

    testWidgets('ألوان النظام غير متاحة (أندرويد أقدم من ١٢): الذهبي', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('theme-system')));
      await tester.pumpAndSettle();
      expect(weekdayColor(tester), const Color(0xFFD6AA5C));
    });

    testWidgets('إعدادات قديمة بلا سمة ولا إشعار تُقرأ', (tester) async {
      final city = parseCities(readAsset('assets/cities.json')).first;
      final old = LamhaSettings.defaults(city, {'salary'}).toJson()
        ..remove('theme')
        ..remove('lockNotification');
      final bridge = await pumpApp(tester, prefs: {LamhaSettings.prefsKey: jsonEncode(old)});
      expect((bridge.last['theme'] as Map)['id'], 'gold');
      expect(bridge.last['lockNotification'], isFalse);
    });
  });

  group('إشعار شاشة القفل', () {
    Future<void> toggle(WidgetTester tester, {required bool proceed}) async {
      await tester.ensureVisible(find.byKey(const Key('lock-notification')));
      await tester.tap(find.byKey(const Key('lock-notification')));
      await tester.pumpAndSettle();
      expect(find.text('إذن الإشعارات'), findsOneWidget);
      await tester.tap(find.byKey(Key(proceed ? 'permission-continue' : 'permission-cancel')));
      await tester.pumpAndSettle();
    }

    bool switchValue(WidgetTester tester) =>
        tester.widget<SwitchListTile>(find.byKey(const Key('lock-notification'))).value;

    testWidgets('مطفأ افتراضياً، وتشغيله يشرح ثم يطلب الإذن ويحفظ في الجدول', (tester) async {
      final permission = FakePermission(true);
      final bridge = await pumpApp(tester, permission: permission);
      expect(switchValue(tester), isFalse);
      expect(bridge.last['lockNotification'], isFalse);
      await toggle(tester, proceed: true);
      expect(permission.requests, 1);
      expect(switchValue(tester), isTrue);
      expect(bridge.last['lockNotification'], isTrue);
      // الإطفاء بلا رسالة ولا طلب إذن.
      await tester.tap(find.byKey(const Key('lock-notification')));
      await tester.pumpAndSettle();
      expect(permission.requests, 1);
      expect(bridge.last['lockNotification'], isFalse);
    });

    testWidgets('رفض الإذن يبقي المفتاح مطفأ برسالة، والإلغاء لا يطلب الإذن', (tester) async {
      final permission = FakePermission(false);
      final bridge = await pumpApp(tester, permission: permission);
      await toggle(tester, proceed: false);
      expect(permission.requests, 0);
      expect(switchValue(tester), isFalse);
      await toggle(tester, proceed: true);
      expect(permission.requests, 1);
      expect(switchValue(tester), isFalse);
      expect(bridge.last['lockNotification'], isFalse);
      expect(find.textContaining('لم يُسمح بالإشعارات'), findsOneWidget);
    });
  });

  testWidgets('كل نصوص المعاينة محاذاة يمين', (tester) async {
    await pumpApp(tester, weather: FakeWeather());
    final paragraphs = tester
        .renderObjectList<RenderParagraph>(find.descendant(
            of: find.byKey(const Key('preview')), matching: find.byType(RichText)))
        .toList();
    expect(paragraphs.length, greaterThan(20));
    for (final p in paragraphs) {
      final right = p.textAlign == TextAlign.right ||
          (p.textAlign == TextAlign.start && p.textDirection == TextDirection.rtl);
      expect(right, isTrue, reason: p.text.toPlainText());
    }
    // اليوم والحرارة على يمين مربعهما، والهجري على يمين كبسولته (بعد حشوتها).
    final day = tester.getRect(find.byKey(const Key('preview-day')));
    final temp = tester.getRect(find.byKey(const Key('preview-temp')));
    final box = tester.getRect(find.byKey(const Key('tile-dayWeather')));
    expect(day.right, closeTo(box.right, 0.5));
    expect(temp.right, closeTo(box.right, 0.5));
    final hijri = tester.getRect(find.byKey(const Key('preview-hijri')));
    expect(hijri.right,
        closeTo(tester.getRect(find.byKey(const Key('tile-hijri'))).right - 12, 0.5));
  });
}
