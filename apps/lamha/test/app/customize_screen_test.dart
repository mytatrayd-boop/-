import 'dart:convert';

import 'package:flutter/gestures.dart';
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
  matching: find.byKey(Key('tile-$id')),
);

Future<FakeBridge> openCustomize(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  final bridge = await pumpApp(tester, prefs: prefs);
  final button = find.byKey(const Key('customize-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  return bridge;
}

List<Map> layoutOf(FakeBridge b) => (b.last['layout'] as List).cast<Map>();

Map tileOf(FakeBridge b, String id) =>
    layoutOf(b).firstWhere((t) => t['id'] == id);

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// يمرر الشريط العرضي (يُبنى كسولاً) حتى تظهر الرقاقة.
Future<void> revealChip(WidgetTester tester, Finder chip) async {
  final strip = find.descendant(
    of: find.byKey(const Key('tile-list')),
    matching: find.byType(Scrollable),
  );
  for (final delta in [80.0, -80.0]) {
    if (chip.evaluate().isNotEmpty) break;
    await tester
        .scrollUntilVisible(
          chip,
          delta,
          scrollable: strip.first,
          maxScrolls: 30,
        )
        .catchError((Object _) {});
  }
  await tester.ensureVisible(chip);
}

/// يختار عنصراً من الشريط العرضي فتظهر إعداداته.
Future<void> select(WidgetTester tester, String id) async {
  final chip = find.byKey(Key('chip-tap-$id'));
  await revealChip(tester, chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'من الإعدادات: المعاينة بالحجم الحقيقي في الأعلى، ثم اللوحة، ثم شريط عرضي بالعناصر الثمانية',
    (tester) async {
      await openCustomize(tester);
      expect(find.text('تخصيص الودجت'), findsWidgets);
      expect(find.text('استعادة الافتراضي'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byKey(const Key('tile-list')))),
        TextDirection.rtl,
      );
      final bg = tester.getSize(
        find.descendant(
          of: find.byKey(const Key('customize-preview')),
          matching: find.byKey(const Key('preview-background')),
        ),
      );
      expect(bg.width, closeTo(338, 0.5));
      expect(bg.height, closeTo(354, 0.5));
      final preview = tester.getRect(
        find.byKey(const Key('customize-preview')),
      );
      final panel = tester.getRect(find.byKey(const Key('tile-panel')));
      final strip = tester.getRect(find.byKey(const Key('tile-list')));
      expect(panel.top, greaterThanOrEqualTo(preview.bottom));
      expect(strip.top, greaterThanOrEqualTo(panel.bottom));
      expect(
        tester
            .widget<ReorderableListView>(find.byKey(const Key('tile-list')))
            .scrollDirection,
        Axis.horizontal,
      );
      for (final e in WidgetElement.values) {
        expect(tile(e.name), findsOneWidget);
      }
      for (final e in WidgetElement.values) {
        await revealChip(tester, find.byKey(ValueKey('chip-${e.name}')));
        expect(find.byKey(ValueKey('chip-${e.name}')), findsOneWidget);
      }
      await revealChip(tester, find.byKey(const ValueKey('chip-clock')));
      // الرقاقات بالترتيب من اليمين لليسار.
      final xs = [
        for (final e in WidgetElement.values.take(4))
          tester.getRect(find.byKey(ValueKey('chip-${e.name}'))).center.dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], lessThan(xs[i - 1]));
      }
      // المختار افتراضياً أول عنصر، ولوحته وحدها ظاهرة.
      expect(find.byKey(const Key('visible-clock')), findsOneWidget);
      expect(find.byKey(const Key('visible-prayer')), findsNothing);
      // الترتيب الافتراضي كالشكل السابق: الساعة يميناً، ويسارها التاريخان وتحتهما المدينة والطقس.
      final clock = tester.getRect(tile('clock'));
      final dates = tester.getRect(tile('dates'));
      final weather = tester.getRect(tile('weather'));
      final prayer = tester.getRect(tile('prayer'));
      expect(clock.left, greaterThan(dates.right));
      expect(weather.top, greaterThanOrEqualTo(dates.bottom - 0.5));
      expect(weather.right, closeTo(dates.right, 0.5));
      expect(prayer.top, greaterThan(clock.bottom));
    },
  );

  testWidgets('الضغط على رقاقة أو على مربع في المعاينة يختاره، واللوحة تتغير', (
    tester,
  ) async {
    await openCustomize(tester);
    await select(tester, 'qibla');
    expect(find.byKey(const Key('visible-qibla')), findsOneWidget);
    expect(find.byKey(const Key('visible-clock')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('panel-name'))).data,
      'القبلة',
    );
    await tester.tap(tile('season'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('panel-name'))).data,
      'الفصل',
    );
    expect(find.byKey(const Key('span-season')), findsOneWidget);
    // العنوان والسطر الفرعي لمربعات المعلومات، ولا عنوان لمربع الساعة.
    expect(find.byKey(const Key('showtitle-season')), findsOneWidget);
    await select(tester, 'clock');
    expect(find.byKey(const Key('showtitle-clock')), findsNothing);
    expect(find.byKey(const Key('showsub-clock')), findsOneWidget);
  });

  testWidgets('الإظهار يحفظ في الجدول، والمخفي باهت في الشريط', (tester) async {
    final bridge = await openCustomize(tester);
    await select(tester, 'prayer');
    await tapKey(tester, 'visible-prayer');
    expect(tile('prayer'), findsNothing);
    expect((bridge.last['visible'] as Map)['prayer'], isFalse);
    expect(tileOf(bridge, 'prayer')['visible'], isFalse);
    final faded = find.ancestor(
      of: find.byKey(const Key('chip-tap-prayer')),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(faded.first).opacity, lessThan(1));
    // القبلة والإيداع والفصل في صف، والموسم وحده يمتد بعرض الصف.
    final q = tester.getRect(tile('qibla'));
    final s = tester.getRect(tile('season'));
    final t = tester.getRect(tile('tradSeason'));
    expect(s.top, q.top);
    expect(t.top, greaterThan(q.bottom));
    expect(t.width, closeTo(338 - 28, 0.5));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
    expect(
      (saved['layout'] as List).cast<Map>().firstWhere(
        (t) => t['id'] == 'prayer',
      )['visible'],
      isFalse,
    );
  });

  testWidgets('العرض وشريط حجم الخط ومفتاحا العنوان والسطر الفرعي واللونان', (
    tester,
  ) async {
    final bridge = await openCustomize(tester);
    await select(tester, 'qibla');
    final before = tester.getRect(tile('qibla')).width;
    await tapKey(tester, 'span-qibla-3');
    expect(tileOf(bridge, 'qibla')['span'], 3);
    expect(tester.getRect(tile('qibla')).width, greaterThan(before * 2));
    await tapKey(tester, 'span-qibla-1');

    // شريط ٠٫٨–٢٫٠ بخطوة ٠٫١، والقيمة معروضة.
    await select(tester, 'deposit');
    final slider = tester.widget<Slider>(
      find.byKey(const Key('tilefont-deposit')),
    );
    expect(
      (slider.min, slider.max, slider.divisions, slider.value),
      (0.8, 2.0, 12, 1.0),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('tilefont-value-deposit'))).data,
      '١.٠',
    );
    final mid = tester.getCenter(find.byKey(const Key('tilefont-deposit')));
    final width = tester
        .getSize(find.byKey(const Key('tilefont-deposit')))
        .width;
    // أقصى الشريط (يسار في RTL) = ٢٫٠.
    await tester.tapAt(Offset(mid.dx - width / 2 + 4, mid.dy));
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'deposit')['fontScale'], 2.0);
    expect(
      tester.widget<Text>(find.byKey(const Key('tilefont-value-deposit'))).data,
      '٢.٠',
    );

    await tapKey(tester, 'showtitle-deposit');
    expect(tileOf(bridge, 'deposit')['showTitle'], isFalse);
    expect(
      find.descendant(
        of: tile('deposit'),
        matching: find.byKey(const Key('tile-title')),
      ),
      findsNothing,
    );
    await tapKey(tester, 'showsub-deposit');
    expect(tileOf(bridge, 'deposit')['showSub'], isFalse);
    expect(
      find.descendant(
        of: tile('deposit'),
        matching: find.byKey(const Key('tile-sub-0')),
      ),
      findsNothing,
    );

    await select(tester, 'qibla');
    await tapKey(tester, 'primary-qibla-pink');
    await tapKey(tester, 'secondary-qibla-blue');
    expect(tileOf(bridge, 'qibla')['primaryColor'], TileColor.pink.argb);
    expect(tileOf(bridge, 'qibla')['secondaryColor'], TileColor.blue.argb);
    Color colorOf(String key) => tester
        .widget<Text>(
          find.descendant(of: tile('qibla'), matching: find.byKey(Key(key))),
        )
        .style!
        .color!;
    expect(colorOf('tile-value'), Color(TileColor.pink.argb));
    expect(colorOf('tile-sub-0'), Color(TileColor.blue.argb));
    // «تلقائي» يعيد لون السمة.
    await tapKey(tester, 'primary-qibla-auto');
    expect(tileOf(bridge, 'qibla')['primaryColor'], isNull);
    expect(colorOf('tile-value'), isNot(Color(TileColor.pink.argb)));
  });

  testWidgets(
    'السحب العرضي بالضغط المطوّل يعيد الترتيب، و«استعادة الافتراضي»',
    (tester) async {
      final bridge = await openCustomize(tester);
      // الصلاة (الرابعة) إلى أول الشريط (أقصى اليمين).
      final chip = find.byKey(const ValueKey('chip-prayer'));
      final target = tester.getRect(find.byKey(const ValueKey('chip-clock')));
      final start = tester.getCenter(chip);
      final g = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
      final dx = target.right + 20 - start.dx;
      for (var i = 0; i < 20; i++) {
        await g.moveBy(Offset(dx / 20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(layoutOf(bridge).first['id'], 'prayer');
      // الصلاة أول الصف من اليمين، والساعة بعدها تمتد لتملأه (والتاريخان في صف جديد).
      expect(
        tester.getRect(tile('prayer')).left,
        greaterThan(tester.getRect(tile('clock')).right),
      );
      expect(
        tester.getRect(tile('dates')).top,
        greaterThan(tester.getRect(tile('clock')).bottom),
      );

      // سحب قصير بلا ضغط مطوّل لا يعيد الترتيب.
      final before = [for (final t in layoutOf(bridge)) t['id']];
      await revealChip(tester, find.byKey(const ValueKey('chip-qibla')));
      await tester.drag(
        find.byKey(const ValueKey('chip-qibla')),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      expect([for (final t in layoutOf(bridge)) t['id']], before);

      await select(tester, 'clock');
      await tapKey(tester, 'span-clock-2');
      await tester.tap(find.byKey(const Key('reset-layout')));
      await tester.pumpAndSettle();
      expect(
        [for (final t in layoutOf(bridge)) t['id']],
        [for (final e in WidgetElement.values) e.name],
      );
      expect(tileOf(bridge, 'clock')['span'], 1);
    },
  );

  testWidgets('أكثر من خمسة صفوف: علامة على رقاقة ما لا يتسع ورسالة في لوحته', (
    tester,
  ) async {
    await openCustomize(tester);
    for (final e in ['clock', 'dates', 'prayer']) {
      await select(tester, e);
      await tapKey(tester, 'span-$e-3');
    }
    // أربعة صفوف بعرض ٣، ثم القبلة والإيداع والفصل، والموسم خارج الودجت.
    expect(find.byKey(const Key('chip-overflow-season')), findsNothing);
    expect(find.byKey(const Key('chip-overflow-tradSeason')), findsOneWidget);
    expect(tile('tradSeason'), findsNothing);
    expect(tile('season'), findsOneWidget);
    await select(tester, 'tradSeason');
    expect(find.byKey(const Key('overflow-tradSeason')), findsOneWidget);
  });

  testWidgets('كل نصوص الشاشة والمعاينة محاذاة يمين', (tester) async {
    await openCustomize(tester);
    for (final p in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    )) {
      final right =
          p.textAlign == TextAlign.right ||
          (p.textAlign == TextAlign.start &&
              p.textDirection == TextDirection.rtl);
      expect(right, isTrue, reason: p.text.toPlainText());
    }
  });

  testWidgets(
    'الترحيل: إعدادات قديمة (visible) تصبح تخطيطاً افتراضياً يطابقها',
    (tester) async {
      final city = parseCities(readAsset('assets/cities.json')).first;
      final old = LamhaSettings.defaults(city, {'salary'}).toJson()
        ..remove('layout')
        ..['visible'] = ['hijri', 'prayer', 'season'];
      final bridge = await openCustomize(
        tester,
        prefs: {LamhaSettings.prefsKey: jsonEncode(old)},
      );
      expect(
        {for (final t in layoutOf(bridge)) t['id']: t['visible']},
        {
          'clock': true,
          'dates': true,
          'weather': false,
          'prayer': true,
          'qibla': false,
          'deposit': false,
          'season': true,
          'tradSeason': false,
        },
      );
      expect(tile('weather'), findsNothing);
      expect(tile('season'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
      expect(saved.containsKey('visible'), isFalse);
      expect((saved['layout'] as List), hasLength(8));
    },
  );
}
