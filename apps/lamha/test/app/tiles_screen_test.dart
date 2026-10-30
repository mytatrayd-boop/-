import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'app_helpers.dart';

/// شاشة «نوافذ الودجت» (٣٠/١٠/٢٠٢٦): تفعيل وإيقاف وترتيب بالسحب، والمعاينة فورية.
Finder previewTile(String id) => find.descendant(
      of: find.byKey(const Key('tiles-preview')),
      matching: find.byKey(Key('tile-$id')),
    );

Future<FakeBridge> openTiles(WidgetTester tester) async {
  final bridge = await pumpApp(tester);
  final b = find.byKey(const Key('tiles-button'));
  await tester.ensureVisible(b);
  await tester.tap(b);
  await tester.pumpAndSettle();
  return bridge;
}

List<String> order(FakeBridge b) =>
    [for (final t in (b.last['layout'] as List).cast<Map>()) t['id'] as String];

Map tileOf(FakeBridge b, String id) =>
    (b.last['layout'] as List).cast<Map>().firstWhere((t) => t['id'] == id);

void main() {
  testWidgets('كل النوافذ في قائمة بمفتاح تفعيل لكل منها، والظاهرة مفعّلة', (tester) async {
    await openTiles(tester);
    expect(find.text('نوافذ الودجت'), findsWidgets);
    for (final t in defaultLayout) {
      final sw = find.byKey(Key('tile-switch-${t.id.name}'));
      await tester.scrollUntilVisible(sw, 80, scrollable: find.descendant(of: find.byKey(const Key('tiles-list')), matching: find.byType(Scrollable)));
      expect(tester.widget<Switch>(sw).value, t.visible, reason: t.id.name);
    }
  });

  testWidgets('إلغاء الموسم: تختفي نافذته من المعاينة وتتمدد الباقية في صفها', (tester) async {
    final bridge = await openTiles(tester);
    expect(previewTile('season'), findsOneWidget);
    expect(previewTile('tradSeason'), findsOneWidget);
    final before = tester.getRect(previewTile('tradSeason')).width;

    final sw = find.byKey(const Key('tile-switch-season'));
    await tester.scrollUntilVisible(sw, 80, scrollable: find.descendant(of: find.byKey(const Key('tiles-list')), matching: find.byType(Scrollable)));
    await tester.tap(sw);
    await tester.pumpAndSettle();

    expect(tileOf(bridge, 'season')['visible'], false);
    expect((bridge.last['visible'] as Map)['season'], false);
    expect(previewTile('season'), findsNothing);
    expect(previewTile('tradSeason'), findsOneWidget);
    // المتبقية تملأ الصف كله بعد أن كانت تتقاسمه.
    expect(tester.getRect(previewTile('tradSeason')).width, greaterThan(before * 1.4));
  });

  testWidgets('لا يمكن إيقاف آخر نافذة ظاهرة', (tester) async {
    final bridge = await openTiles(tester);
    final scroll = find.descendant(of: find.byKey(const Key('tiles-list')), matching: find.byType(Scrollable));
    for (final t in defaultLayout.where((t) => t.visible).skip(1)) {
      final sw = find.byKey(Key('tile-switch-${t.id.name}'));
      await tester.scrollUntilVisible(sw, 80, scrollable: scroll);
      await tester.tap(sw);
      await tester.pumpAndSettle();
    }
    final visible = (bridge.last['layout'] as List).cast<Map>().where((t) => t['visible'] == true).toList();
    expect(visible.length, 1);
    final last = visible.single['id'] as String;
    final sw = find.byKey(Key('tile-switch-$last'));
    await tester.scrollUntilVisible(sw, 80, scrollable: scroll);
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(find.text('يجب أن تبقى نافذة واحدة على الأقل'), findsOneWidget);
    expect(tileOf(bridge, last)['visible'], true);
  });

  testWidgets('الترتيب بسحب المقبض يحفظ الترتيب الجديد في الجدول', (tester) async {
    final bridge = await openTiles(tester);
    final before = order(bridge);
    expect(before.first, 'clock');
    final handle = find.byKey(const Key('tile-handle-clock'));
    await tester.drag(handle, const Offset(0, 130));
    await tester.pumpAndSettle();
    final after = order(bridge);
    expect(after.first, isNot('clock'));
    expect(after.indexOf('clock'), greaterThan(0));
    expect(after.toSet(), before.toSet(), reason: 'لا نافذة تضيع');
  });

  testWidgets('إعادة الافتراضي ترجع الترتيب والإظهار', (tester) async {
    final bridge = await openTiles(tester);
    final sw = find.byKey(const Key('tile-switch-season'));
    await tester.scrollUntilVisible(sw, 80, scrollable: find.descendant(of: find.byKey(const Key('tiles-list')), matching: find.byType(Scrollable)));
    await tester.tap(sw);
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'season')['visible'], false);
    await tester.tap(find.byKey(const Key('tiles-reset')));
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'season')['visible'], true);
    expect(order(bridge), [for (final t in defaultLayout) t.id.name]);
  });

  testWidgets('التعديل الخفيف (الشفافية والتخطيط) يطابق بناء الجدول كاملاً', (tester) async {
    final bridge = await openTiles(tester);
    final sw = find.byKey(const Key('tile-switch-tradSeason'));
    await tester.scrollUntilVisible(sw, 80, scrollable: find.descendant(of: find.byKey(const Key('tiles-list')), matching: find.byType(Scrollable)));
    await tester.tap(sw);
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('tile-handle-clock')), const Offset(0, 130));
    await tester.pumpAndSettle();

    final saved = LamhaSettings.fromJson(
      jsonDecode((await SharedPreferences.getInstance()).getString(LamhaSettings.prefsKey)!) as Map<String, dynamic>,
    );
    final data = loadEngineDataFromFiles();
    final full = buildSchedule(
      testNow,
      saved.toEngine(withBackground: false),
      data,
      days: 30,
      generatedAt: testNow,
    );
    final expected = jsonDecode(jsonEncode(full)) as Map<String, dynamic>;
    final actual = Map<String, dynamic>.of(bridge.last);
    // الطقس فقط يختلف بين البناءين (القراءة بلا إنترنت في الاختبار).
    expect(actual['layout'], expected['layout']);
    expect(actual['visible'], expected['visible']);
    expect(actual['opacity'], expected['opacity']);
    expect(actual['prayerCountdown'], expected['prayerCountdown']);
    expect(actual['days'], expected['days']);
  });
}
