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
    'من الإعدادات: المعاينة بالحجم الحقيقي في الأعلى، ثم اللوحة، ثم شريط عرضي بكل العناصر',
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
      expect(bg.height, closeTo(440, 0.5));
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
      for (final t in defaultLayout) {
        expect(tile(t.id.name), t.visible ? findsOneWidget : findsNothing);
      }
      for (final e in WidgetElement.values) {
        await revealChip(tester, find.byKey(ValueKey('chip-${e.name}')));
        expect(find.byKey(ValueKey('chip-${e.name}')), findsOneWidget);
      }
      await revealChip(tester, find.byKey(const ValueKey('chip-clock')));
      // الرقاقات بالترتيب من اليمين لليسار.
      final xs = [
        for (final t in defaultLayout.take(4))
          tester.getRect(find.byKey(ValueKey('chip-${t.id.name}'))).center.dx,
      ];
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], lessThan(xs[i - 1]));
      }
      // المختار افتراضياً أول عنصر، ولوحته وحدها ظاهرة.
      expect(find.byKey(const Key('visible-clock')), findsOneWidget);
      expect(find.byKey(const Key('visible-prayer')), findsNothing);
      // الترتيب الافتراضي (تصميم المالك ٣): الساعة يميناً ويسارها اليوم والطقس، ثم الهجري وتحته
      // الميلادي، ثم مواقيت الصلاة.
      final clock = tester.getRect(tile('clock'));
      final day = tester.getRect(tile('dayWeather'));
      final hijri = tester.getRect(tile('hijri'));
      final gregorian = tester.getRect(tile('gregorian'));
      final prayer = tester.getRect(tile('prayerTimes'));
      expect(clock.left, greaterThan(day.right));
      expect(hijri.top, greaterThan(clock.bottom));
      expect(gregorian.top, greaterThanOrEqualTo(hijri.bottom - 0.5));
      expect(gregorian.right, closeTo(hijri.right, 0.5));
      expect(prayer.top, greaterThan(gregorian.bottom));
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
    await select(tester, 'prayerTimes');
    await tapKey(tester, 'visible-prayerTimes');
    expect(tile('prayerTimes'), findsNothing);
    expect((bridge.last['visible'] as Map)['prayerTimes'], isFalse);
    expect(tileOf(bridge, 'prayerTimes')['visible'], isFalse);
    final faded = find.ancestor(
      of: find.byKey(const Key('chip-tap-prayerTimes')),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(faded.first).opacity, lessThan(1));
    // الإيداعات تصعد تحت التاريخين بعرض الصف.
    final g = tester.getRect(tile('gregorian'));
    final d = tester.getRect(tile('deposit'));
    expect(d.top, greaterThan(g.bottom));
    expect(d.width, closeTo(338 - 28, 0.5));
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
    expect(
      (saved['layout'] as List).cast<Map>().firstWhere(
        (t) => t['id'] == 'prayerTimes',
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
    expect(find.byKey(const Key('deposit-title')), findsNothing);
    await tapKey(tester, 'showsub-deposit');
    expect(tileOf(bridge, 'deposit')['showSub'], isFalse);
    expect(find.byKey(const Key('deposit-sub-0')), findsNothing);
    expect(find.byKey(const Key('deposit-name-0')), findsOneWidget);

    // القبلة: عنوانها كلمة «القبلة» في الدائرة، بلا سطر فرعي.
    await select(tester, 'qibla');
    expect(find.byKey(const Key('showsub-qibla')), findsNothing);
    await tapKey(tester, 'showtitle-qibla');
    expect(find.byKey(const Key('preview-qibla-title')), findsNothing);
    expect(find.byKey(const Key('preview-kaaba')), findsOneWidget);

    await select(tester, 'season');
    await tapKey(tester, 'primary-season-pink');
    await tapKey(tester, 'secondary-season-blue');
    expect(tileOf(bridge, 'season')['primaryColor'], TileColor.pink.argb);
    expect(tileOf(bridge, 'season')['secondaryColor'], TileColor.blue.argb);
    Color colorOf(String key) => tester
        .widget<Text>(
          find.descendant(of: tile('season'), matching: find.byKey(Key(key))),
        )
        .style!
        .color!;
    expect(colorOf('tile-value'), Color(TileColor.pink.argb));
    if (find.descendant(of: tile('season'), matching: find.byKey(const Key('tile-sub-0'))).evaluate().isNotEmpty) {
      expect(colorOf('tile-sub-0'), Color(TileColor.blue.argb));
    }
    // «تلقائي» يعيد لون السمة.
    await tapKey(tester, 'primary-season-auto');
    expect(tileOf(bridge, 'season')['primaryColor'], isNull);
    expect(colorOf('tile-value'), isNot(Color(TileColor.pink.argb)));
  });

  testWidgets(
    'السحب العرضي بالضغط المطوّل يعيد الترتيب، و«استعادة الافتراضي»',
    (tester) async {
      final bridge = await openCustomize(tester);
      // اليوم والطقس (الثاني) إلى أول الشريط (أقصى اليمين).
      final chip = find.byKey(const ValueKey('chip-dayWeather'));
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
      expect(layoutOf(bridge).first['id'], 'dayWeather');
      // اليوم والطقس أول الصف من اليمين، والساعة بعده (والتاريخان في صف جديد).
      expect(
        tester.getRect(tile('dayWeather')).left,
        greaterThan(tester.getRect(tile('clock')).right),
      );
      expect(
        tester.getRect(tile('hijri')).top,
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
      await tapKey(tester, 'span-clock-1');
      await tester.tap(find.byKey(const Key('reset-layout')));
      await tester.pumpAndSettle();
      expect(
        [for (final t in layoutOf(bridge)) t['id']],
        [for (final t in defaultLayout) t.id.name],
      );
      expect(tileOf(bridge, 'clock')['span'], 2);
    },
  );

  testWidgets('أكثر من خمسة صفوف: علامة على رقاقة ما لا يتسع ورسالة في لوحته', (
    tester,
  ) async {
    await openCustomize(tester);
    await select(tester, 'dayWeather');
    await tapKey(tester, 'span-dayWeather-3');
    // الساعة ثم اليوم والطقس في صف جديد، فالصف الأخير (الفصل والموسم ووصفه) خارج الودجت.
    await revealChip(tester, find.byKey(const Key('chip-overflow-season')));
    expect(find.byKey(const Key('chip-overflow-season')), findsOneWidget);
    await revealChip(tester, find.byKey(const ValueKey('chip-deposit')));
    expect(find.byKey(const Key('chip-overflow-deposit')), findsNothing);
    expect(tile('season'), findsNothing);
    expect(tile('deposit'), findsOneWidget);
    await select(tester, 'tradPoints');
    expect(find.byKey(const Key('overflow-tradPoints')), findsOneWidget);
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
          'dayWeather': false,
          'hijri': true,
          'gregorian': false,
          'qibla': false,
          'prayerTimes': true,
          'deposit': false,
          'season': true,
          'tradSeason': false,
          'tradPoints': false,
          'dates': false,
          'weather': false,
          'prayer': false,
        },
      );
      expect(tile('dayWeather'), findsNothing);
      expect(tile('season'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
      expect(saved.containsKey('visible'), isFalse);
      expect((saved['layout'] as List), hasLength(WidgetElement.values.length));
    },
  );
}
