import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'app_helpers.dart';

/// الميزة ٥: شاشة «تخصيص الودجت».
Finder tile(String id) => find.descendant(
    of: find.byKey(const Key('customize-preview')),
    matching: find.byKey(Key('tile-$id')));

Future<FakeBridge> openCustomize(WidgetTester tester,
    {Map<String, Object> prefs = const {}}) async {
  final bridge = await pumpApp(tester, prefs: prefs);
  final button = find.byKey(const Key('customize-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  return bridge;
}

List<Map> layoutOf(FakeBridge b) => (b.last['layout'] as List).cast<Map>();

Map tileOf(FakeBridge b, String id) => layoutOf(b).firstWhere((t) => t['id'] == id);

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('من الإعدادات: معاينة بالحجم الحقيقي وبطاقة لكل عنصر من الثمانية', (tester) async {
    await openCustomize(tester);
    expect(find.text('تخصيص الودجت'), findsWidgets);
    expect(Directionality.of(tester.element(find.byKey(const Key('tile-list')))),
        TextDirection.rtl);
    final bg = tester.getSize(find.descendant(
        of: find.byKey(const Key('customize-preview')),
        matching: find.byKey(const Key('preview-background'))));
    expect(bg.width, closeTo(338, 0.5));
    expect(bg.height, closeTo(354, 0.5));
    for (final e in WidgetElement.values) {
      expect(find.byKey(ValueKey('card-${e.name}')), findsOneWidget);
      expect(tile(e.name), findsOneWidget);
    }
    // الترتيب الافتراضي: الساعة يمين التاريخين، ثم المدينة والطقس بعرض الصف، ثم الخمسة.
    final clock = tester.getRect(tile('clock'));
    final dates = tester.getRect(tile('dates'));
    final weather = tester.getRect(tile('weather'));
    final prayer = tester.getRect(tile('prayer'));
    expect(clock.left, greaterThan(dates.right));
    expect(clock.top, dates.top);
    expect(weather.top, greaterThan(clock.bottom));
    expect(weather.width, closeTo(338 - 28, 0.5));
    expect(prayer.top, greaterThan(weather.bottom));
  });

  testWidgets('الإظهار يحفظ في الجدول، والمربعات الباقية تملأ الصف', (tester) async {
    final bridge = await openCustomize(tester);
    await tapKey(tester, 'visible-prayer');
    expect(tile('prayer'), findsNothing);
    expect((bridge.last['visible'] as Map)['prayer'], isFalse);
    expect(tileOf(bridge, 'prayer')['visible'], isFalse);
    // القبلة والإيداع والفصل في صف، والموسم وحده يمتد بعرض الصف.
    final q = tester.getRect(tile('qibla'));
    final s = tester.getRect(tile('season'));
    final t = tester.getRect(tile('tradSeason'));
    expect(s.top, q.top);
    expect(t.top, greaterThan(q.bottom));
    expect(t.width, closeTo(338 - 28, 0.5));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
    expect((saved['layout'] as List).cast<Map>().firstWhere(
        (t) => t['id'] == 'prayer')['visible'], isFalse);
  });

  testWidgets('العرض وحجم الخط واللونان لكل مربع', (tester) async {
    final bridge = await openCustomize(tester);
    final before = tester.getRect(tile('qibla')).width;
    await tapKey(tester, 'span-qibla-3');
    expect(tileOf(bridge, 'qibla')['span'], 3);
    expect(tester.getRect(tile('qibla')).width, greaterThan(before * 2));

    double valueSize(String id) => tester
        .widget<Text>(find.descendant(of: tile(id), matching: find.byKey(const Key('tile-value'))))
        .style!
        .fontSize!;
    final small = valueSize('deposit');
    await tapKey(tester, 'tilefont-deposit-xlarge');
    expect(tileOf(bridge, 'deposit')['fontScale'], 1.3);
    expect(valueSize('deposit'), greaterThan(small));

    await tapKey(tester, 'primary-qibla-pink');
    await tapKey(tester, 'secondary-qibla-blue');
    expect(tileOf(bridge, 'qibla')['primaryColor'], TileColor.pink.argb);
    expect(tileOf(bridge, 'qibla')['secondaryColor'], TileColor.blue.argb);
    Color colorOf(String key) => tester
        .widget<Text>(find.descendant(of: tile('qibla'), matching: find.byKey(Key(key))))
        .style!
        .color!;
    expect(colorOf('tile-value'), Color(TileColor.pink.argb));
    expect(colorOf('tile-title'), Color(TileColor.blue.argb));
    expect(colorOf('tile-sub-0'), Color(TileColor.blue.argb));
    // «تلقائي» يعيد لون السمة.
    await tapKey(tester, 'primary-qibla-auto');
    expect(tileOf(bridge, 'qibla')['primaryColor'], isNull);
    expect(colorOf('tile-value'), isNot(Color(TileColor.pink.argb)));
  });

  testWidgets('السحب يعيد الترتيب، و«استعادة الترتيب الافتراضي»', (tester) async {
    final bridge = await openCustomize(tester);
    // الصلاة (الرابعة) إلى الأعلى.
    final handle = find.byKey(const Key('drag-prayer'));
    final target = tester.getCenter(find.byKey(const Key('drag-clock')));
    final start = tester.getCenter(handle);
    final g = await tester.startGesture(start);
    await tester.pump();
    final dy = target.dy - 40 - start.dy;
    for (var i = 0; i < 20; i++) {
      await g.moveBy(Offset(0, dy / 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(layoutOf(bridge).first['id'], 'prayer');
    // الصلاة أول الصف من اليمين، والساعة بعدها تمتد لتملأه (والتاريخان في صف جديد).
    expect(tester.getRect(tile('prayer')).left,
        greaterThan(tester.getRect(tile('clock')).right));
    expect(tester.getRect(tile('dates')).top,
        greaterThan(tester.getRect(tile('clock')).bottom));

    await tapKey(tester, 'span-clock-2');
    await tester.tap(find.byKey(const Key('reset-layout')));
    await tester.pumpAndSettle();
    expect([for (final t in layoutOf(bridge)) t['id']],
        [for (final e in WidgetElement.values) e.name]);
    expect(tileOf(bridge, 'clock')['span'], 1);
  });

  testWidgets('الضغط على مربع في المعاينة يفتح إعداداته', (tester) async {
    final bridge = await openCustomize(tester);
    await tester.tap(tile('season'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tile-sheet')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('tile-sheet')), matching: find.text('الفصل')),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('sheet-span-season-2')));
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'season')['span'], 2);
    await tester.tap(find.byKey(const Key('sheet-visible-season')));
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'season')['visible'], isFalse);
    // النافذة تبقى مفتوحة بالحالة الجديدة.
    expect(tester.widget<Switch>(find.byKey(const Key('sheet-visible-season'))).value, isFalse);
  });

  testWidgets('أكثر من خمسة صفوف: رسالة في بطاقة ما لا يتسع', (tester) async {
    await openCustomize(tester);
    for (final e in ['clock', 'dates', 'prayer']) {
      await tapKey(tester, 'span-$e-3');
    }
    // أربعة صفوف بعرض ٣، ثم القبلة والإيداع والفصل، والموسم خارج الودجت.
    expect(find.byKey(const Key('overflow-season')), findsNothing);
    expect(find.byKey(const Key('overflow-tradSeason')), findsOneWidget);
    expect(tile('tradSeason'), findsNothing);
    expect(tile('season'), findsOneWidget);
  });

  testWidgets('كل نصوص الشاشة والمعاينة محاذاة يمين', (tester) async {
    await openCustomize(tester);
    for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
      final right = p.textAlign == TextAlign.right ||
          (p.textAlign == TextAlign.start && p.textDirection == TextDirection.rtl);
      expect(right, isTrue, reason: p.text.toPlainText());
    }
  });

  testWidgets('الترحيل: إعدادات قديمة (visible) تصبح تخطيطاً افتراضياً يطابقها', (tester) async {
    final city = parseCities(readAsset('assets/cities.json')).first;
    final old = LamhaSettings.defaults(city, {'salary'}).toJson()
      ..remove('layout')
      ..['visible'] = ['hijri', 'prayer', 'season'];
    final bridge = await openCustomize(tester,
        prefs: {LamhaSettings.prefsKey: jsonEncode(old)});
    expect({for (final t in layoutOf(bridge)) t['id']: t['visible']}, {
      'clock': true, 'dates': true, 'weather': false, 'prayer': true,
      'qibla': false, 'deposit': false, 'season': true, 'tradSeason': false,
    });
    expect(tile('weather'), findsNothing);
    expect(tile('season'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
    expect(saved.containsKey('visible'), isFalse);
    expect((saved['layout'] as List), hasLength(8));
  });
}
