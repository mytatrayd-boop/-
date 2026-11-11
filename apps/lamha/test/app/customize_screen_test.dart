import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/engine/schedule.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'app_helpers.dart';

/// شاشة «الودجت» الواحدة: المعاينة، ثم «ألوان جاهزة»، ثم قائمة العناصر، ولوحة سفلية بتبويبات.
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

List<String> order(FakeBridge b) => [for (final t in layoutOf(b)) t['id'] as String];

Map tileOf(FakeBridge b, String id) =>
    layoutOf(b).firstWhere((t) => t['id'] == id);

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// يغلق اللوحة السفلية إن كانت مفتوحة.
Future<void> closeSheet(WidgetTester tester) async {
  final panel = find.byKey(const Key('tile-panel'));
  if (panel.evaluate().isEmpty) return;
  Navigator.of(tester.element(panel)).pop();
  await tester.pumpAndSettle();
}

/// يفتح لوحة عنصر من القائمة.
Future<void> select(WidgetTester tester, String id) async {
  await closeSheet(tester);
  await tapKey(tester, 'chip-tap-$id');
  expect(find.byKey(const Key('tile-panel')), findsOneWidget);
}

/// ينتقل إلى تبويب في اللوحة: size أو colors أو content.
Future<void> tab(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(Key('tab-$name')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'من الإعدادات: المعاينة ثابتة في الأعلى، ثم الألوان الجاهزة، ثم قائمة العناصر بالترتيب',
    (tester) async {
      await openCustomize(tester);
      expect(find.text('الودجت'), findsWidgets);
      expect(find.text('استعادة الافتراضي'), findsOneWidget);
      expect(find.byKey(const Key('tiles-button')), findsNothing);
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
      final preview = tester.getRect(find.byKey(const Key('customize-preview')));
      final presets = tester.getRect(find.byKey(const Key('color-presets')));
      final list = tester.getRect(find.byKey(const Key('tile-list')));
      expect(presets.top, greaterThanOrEqualTo(preview.bottom));
      expect(list.top, greaterThanOrEqualTo(presets.bottom));
      expect(
        tester.widget<ReorderableListView>(find.byKey(const Key('tile-list'))).scrollDirection,
        Axis.vertical,
      );
      // لا لوحة قبل اختيار عنصر.
      expect(find.byKey(const Key('tile-panel')), findsNothing);
      for (final t in defaultLayout) {
        expect(tile(t.id.name), t.visible ? findsOneWidget : findsNothing);
        expect(
          tester.widget<Switch>(find.byKey(Key('tile-switch-${t.id.name}'))).value,
          t.visible,
          reason: t.id.name,
        );
      }
      // الصفوف بترتيب التخطيط من الأعلى للأسفل، والمقبض على اليمين.
      final ys = [
        for (final t in defaultLayout)
          tester.getRect(find.byKey(ValueKey('tile-row-${t.id.name}'))).top,
      ];
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]));
      }
      expect(
        tester.getCenter(find.byKey(const Key('tile-handle-clock'))).dx,
        greaterThan(tester.getCenter(find.byKey(const Key('tile-switch-clock'))).dx),
      );
      for (final p in colorPresets) {
        expect(find.byKey(Key('preset-${p.name}')), findsOneWidget);
      }
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

  testWidgets('الضغط على عنصر في القائمة أو في المعاينة يفتح لوحته بثلاثة تبويبات', (
    tester,
  ) async {
    await openCustomize(tester);
    await select(tester, 'qibla');
    expect(find.byKey(const Key('visible-qibla')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('panel-name'))).data, 'القبلة');
    for (final t in ['size', 'colors', 'content']) {
      expect(find.byKey(Key('tab-$t')), findsOneWidget);
    }
    expect(find.text('الحجم'), findsOneWidget);
    expect(find.text('الألوان'), findsOneWidget);
    expect(find.text('المحتوى'), findsOneWidget);
    // المعاينة ظاهرة فوق اللوحة.
    expect(
      tester.getRect(find.byKey(const Key('customize-preview'))).bottom,
      lessThan(tester.getRect(find.byKey(const Key('tile-panel'))).top),
    );
    await closeSheet(tester);
    await tester.tap(tile('season'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('panel-name'))).data, 'الفصل');
    // الحجم أولاً: العرض وحجم الخط، بلا ألوان ولا مفاتيح محتوى.
    expect(find.byKey(const Key('tilefont-season')), findsOneWidget);
    expect(find.byKey(const Key('tilefont-season')), findsOneWidget);
    expect(find.byKey(const Key('primary-season-auto')), findsNothing);
    expect(find.byKey(const Key('showtitle-season')), findsNothing);
    await tab(tester, 'colors');
    expect(find.byKey(const Key('primary-season-auto')), findsOneWidget);
    expect(find.byKey(const Key('secondary-season-auto')), findsOneWidget);
    await tab(tester, 'content');
    // العنوان والسطر الفرعي لمربعات المعلومات، ولا عنوان لمربع الساعة.
    expect(find.byKey(const Key('showtitle-season')), findsOneWidget);
    await select(tester, 'clock');
    await tab(tester, 'content');
    expect(find.byKey(const Key('showtitle-clock')), findsNothing);
    expect(find.byKey(const Key('showsub-clock')), findsOneWidget);
    // عنصر بلا عنوان ولا سطر فرعي: رسالة بدل المفاتيح.
    await select(tester, 'hijri');
    await tab(tester, 'content');
    expect(find.text('لا خيارات محتوى لهذا العنصر'), findsOneWidget);
  });

  testWidgets('بمقاس آيفون: اللوحة تقف تحت المعاينة فلا تحجب أسفل الودجت', (tester) async {
    await openCustomize(tester);
    for (final size in const [Size(375, 667), Size(390, 844), Size(430, 932)]) {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      await tester.pumpAndSettle();
      // من المعاينة نفسها: أعلى الودجت وأسفله.
      for (final id in ['clock', 'season']) {
        await tester.tap(tile(id));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tile-panel')), findsOneWidget);
        final preview = tester.getRect(find.byKey(const Key('customize-preview')));
        final sheet = tester.getRect(find.ancestor(
          of: find.byKey(const Key('tile-panel')),
          matching: find.byType(BottomSheet),
        ));
        expect(sheet.top, greaterThanOrEqualTo(preview.bottom), reason: '$size $id');
        await closeSheet(tester);
      }
    }
  });

  testWidgets('مفتاح الإظهار في الصف يحفظ في الجدول، والمخفي باهت', (tester) async {
    final bridge = await openCustomize(tester);
    await tapKey(tester, 'tile-switch-prayerTimes');
    expect(tile('prayerTimes'), findsNothing);
    expect((bridge.last['visible'] as Map)['prayerTimes'], isFalse);
    expect(tileOf(bridge, 'prayerTimes')['visible'], isFalse);
    final faded = find.ancestor(
      of: find.descendant(
        of: find.byKey(const ValueKey('tile-row-prayerTimes')),
        matching: find.text('مواقيت الصلاة'),
      ),
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
    // ومفتاح اللوحة يعيده.
    await select(tester, 'prayerTimes');
    await tapKey(tester, 'visible-prayerTimes');
    expect(tileOf(bridge, 'prayerTimes')['visible'], isTrue);
    expect(tile('prayerTimes'), findsOneWidget);
  });

  testWidgets('لا يمكن إيقاف آخر عنصر ظاهر', (tester) async {
    final bridge = await openCustomize(tester);
    for (final t in defaultLayout.where((t) => t.visible).skip(1)) {
      await tapKey(tester, 'tile-switch-${t.id.name}');
    }
    final visible = layoutOf(bridge).where((t) => t['visible'] == true).toList();
    expect(visible.length, 1);
    final last = visible.single['id'] as String;
    await tapKey(tester, 'tile-switch-$last');
    expect(find.text('يجب أن تبقى نافذة واحدة على الأقل'), findsOneWidget);
    expect(tileOf(bridge, last)['visible'], true);
    await select(tester, last);
    expect(tester.widget<Switch>(find.byKey(Key('visible-$last'))).onChanged, isNull);
  });

  testWidgets('تبويب الحجم: أيقونة القبلة، وحجم الخط؛ والمحتوى؛ والألوان', (
    tester,
  ) async {
    final bridge = await openCustomize(tester);
    await select(tester, 'qibla');
    // أيقونة القبلة بشريط حجم لا بـ«صغير/وسط/عريض».
    expect(find.byKey(const Key('span-qibla')), findsNothing);
    final iconSlider = tester.widget<Slider>(find.byKey(const Key('qibla-icon-size')));
    expect((iconSlider.min, iconSlider.max, iconSlider.divisions, iconSlider.value), (0.5, 1.6, 22, 1.0));
    Finder icon() => find.descendant(of: tile('qibla'), matching: find.byKey(const Key('preview-qibla-icon')));
    final before = tester.getSize(icon()).width;
    final sliderBox = find.byKey(const Key('qibla-icon-size'));
    final c = tester.getCenter(sliderBox);
    final w = tester.getSize(sliderBox).width;
    // السحب إلى أقصى الشريط (يسار في RTL) دون إفلات: المعاينة تتغير فوراً ولا حفظ للودجت بعد.
    final saves = bridge.saved.length;
    final g = await tester.startGesture(c);
    await g.moveTo(Offset(c.dx - w / 2 + 2, c.dy));
    await tester.pump();
    expect(tester.getSize(icon()).width, greaterThanOrEqualTo(before), reason: 'الأيقونة لا تصغر بالتكبير');
    expect(bridge.saved.length, saves, reason: 'لا حفظ أثناء السحب');
    await g.up();
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'qibla')['iconScale'], 1.6);
    await tester.tapAt(Offset(c.dx + w / 2 - 2, c.dy));
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'qibla')['iconScale'], 0.5);
    expect(tester.getSize(icon()).width, lessThan(before), reason: 'الأيقونة تصغر داخل مربعها');

    // شريط ٠٫٨–٢٫٠ بخطوة ٠٫١، والقيمة معروضة.
    await select(tester, 'deposit');
    final slider = tester.widget<Slider>(find.byKey(const Key('tilefont-deposit')));
    expect((slider.min, slider.max, slider.divisions, slider.value), (0.8, 2.0, 12, 1.0));
    expect(tester.widget<Text>(find.byKey(const Key('tilefont-value-deposit'))).data, '١.٠');
    final mid = tester.getCenter(find.byKey(const Key('tilefont-deposit')));
    final width = tester.getSize(find.byKey(const Key('tilefont-deposit'))).width;
    // أقصى الشريط (يسار في RTL) = ٢٫٠.
    await tester.tapAt(Offset(mid.dx - width / 2 + 4, mid.dy));
    await tester.pumpAndSettle();
    expect(tileOf(bridge, 'deposit')['fontScale'], 2.0);
    expect(tester.widget<Text>(find.byKey(const Key('tilefont-value-deposit'))).data, '٢.٠');

    // الإيداعات بلا عنوان (طلب المالك): لا مفتاح للعنوان.
    await tab(tester, 'content');
    expect(find.byKey(const Key('showtitle-deposit')), findsNothing);
    expect(find.byKey(const Key('deposit-title')), findsNothing);
    await tapKey(tester, 'showsub-deposit');
    expect(tileOf(bridge, 'deposit')['showSub'], isFalse);
    // ستة إيداعات افتراضياً = شبكة: بلا السطر الفرعي يبقى الاسم وحده.
    expect(find.byKey(const Key('deposit-days-0')), findsNothing);
    expect(find.byKey(const Key('deposit-name-0')), findsOneWidget);

    // القبلة: عنوانها كلمة «القبلة» في الدائرة، بلا سطر فرعي.
    await select(tester, 'qibla');
    await tab(tester, 'content');
    expect(find.byKey(const Key('showsub-qibla')), findsNothing);
    await tapKey(tester, 'showtitle-qibla');
    expect(find.byKey(const Key('preview-qibla-title')), findsNothing);
    expect(find.byKey(const Key('preview-qibla-icon')), findsOneWidget);

    await select(tester, 'season');
    await tab(tester, 'colors');
    await tapKey(tester, 'primary-season-pink');
    await tapKey(tester, 'secondary-season-blue');
    expect(tileOf(bridge, 'season')['primaryColor'], TileColor.pink.argb);
    expect(tileOf(bridge, 'season')['secondaryColor'], TileColor.blue.argb);
    Color colorOf(String key) => tester
        .widget<Text>(find.descendant(of: tile('season'), matching: find.byKey(Key(key))))
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

  testWidgets('«ألوان جاهزة» تلوّن كل العناصر، و«تلقائي» يمسحها', (tester) async {
    final bridge = await openCustomize(tester);
    await tapKey(tester, 'preset-gold');
    for (final t in layoutOf(bridge)) {
      expect(t['primaryColor'], TileColor.gold.argb, reason: '${t['id']}');
      expect(t['secondaryColor'], TileColor.cream.argb, reason: '${t['id']}');
    }
    final value = tester.widget<Text>(
      find.descendant(of: tile('season'), matching: find.byKey(const Key('tile-value'))),
    );
    expect(value.style!.color, Color(TileColor.gold.argb));
    await tapKey(tester, 'preset-auto');
    for (final t in layoutOf(bridge)) {
      expect(t['primaryColor'], isNull);
      expect(t['secondaryColor'], isNull);
    }
  });

  testWidgets('الترتيب بسحب المقبض، و«استعادة الافتراضي»', (tester) async {
    final bridge = await openCustomize(tester);
    final before = order(bridge);
    expect(before.first, 'clock');
    await tester.drag(find.byKey(const Key('tile-handle-clock')), const Offset(0, 130));
    await tester.pumpAndSettle();
    final after = order(bridge);
    expect(after.first, isNot('clock'));
    expect(after.indexOf('clock'), greaterThan(0));
    expect(after.toSet(), before.toSet(), reason: 'لا عنصر يضيع');

    // سحب الصف نفسه (لا المقبض) لا يعيد الترتيب.
    await tester.drag(find.byKey(const ValueKey('tile-row-qibla')), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(order(bridge), after);

    await tester.tap(find.byKey(const Key('reset-layout')));
    await tester.pumpAndSettle();
    expect(order(bridge), [for (final t in defaultLayout) t.id.name]);
    expect(tileOf(bridge, 'clock')['rect'], [0, 0, 4, 2]);
  });

  testWidgets('التعديل الخفيف (الإظهار والترتيب) يطابق بناء الجدول كاملاً', (tester) async {
    final bridge = await openCustomize(tester);
    await tapKey(tester, 'tile-switch-tradSeason');
    await tester.drag(find.byKey(const Key('tile-handle-clock')), const Offset(0, 130));
    await tester.pumpAndSettle();
    final saved = LamhaSettings.fromJson(
      jsonDecode((await SharedPreferences.getInstance()).getString(LamhaSettings.prefsKey)!)
          as Map<String, dynamic>,
    );
    final full = buildSchedule(
      testNow,
      saved.toEngine(withBackground: false),
      loadEngineDataFromFiles(),
      days: 30,
      generatedAt: testNow,
    );
    final expected = jsonDecode(jsonEncode(full)) as Map<String, dynamic>;
    final actual = Map<String, dynamic>.of(bridge.last);
    // الطقس فقط يختلف بين البناءين (القراءة بلا إنترنت في الاختبار).
    expect(actual['layout'], expected['layout']);
    expect(actual['visible'], expected['visible']);
    expect(actual['opacity'], expected['opacity']);
    expect(actual['days'], expected['days']);
  });

  /// سحب تدريجي (يتجاوز حد بدء السحب) من مركز [key] بإزاحة [by].
  Future<void> dragKey(WidgetTester tester, String key, Offset by) async {
    final g = await tester.startGesture(tester.getCenter(find.byKey(Key(key))));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(by / 10);
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('المحرر الحر: سحب مربع يحرّكه، ومقبضه يكبّره، والباقي يصعد بلا فجوات', (tester) async {
    final bridge = await openCustomize(tester);
    final cell = tester.getSize(find.byKey(const Key('free-box-hijri'))).height + 4;
    // المواقيت إلى أعلى الودجت: تأخذ الصف الأول وينزل الباقي.
    await dragKey(tester, 'free-box-prayerTimes', Offset(0, -4 * cell));
    expect(tileOf(bridge, 'prayerTimes')['rect'], [0, 0, 6, 2]);
    expect(tileOf(bridge, 'clock')['rect'], [0, 2, 4, 2]);
    expect(tester.getRect(tile('prayerTimes')).bottom, lessThan(tester.getRect(tile('clock')).top));
    // تكبير البوصلة من مقبضها: أعرض بخلية (يساراً) وأطول بخليتين.
    await dragKey(tester, 'free-handle-qibla', Offset(-cell * 1.6, 2 * cell));
    final q = (tileOf(bridge, 'qibla')['rect'] as List).cast<int>();
    expect(q[3], 4, reason: 'أطول بخليتين');
    // لا تداخل بين ما في الجدول، والودجت ترسم الشجرة نفسها.
    expect(bridge.last['tree'], isNotNull);
  });

  testWidgets('ما يتجاوز أسفل الشبكة: علامة على صفه ورسالة في لوحته', (tester) async {
    await openCustomize(tester);
    final cell = tester.getSize(find.byKey(const Key('free-box-hijri'))).height + 4;
    // اليوم والطقس أطول بخليتين: يدفع ما تحته فيخرج آخر صف (الفصل والموسم).
    await dragKey(tester, 'free-handle-dayWeather', Offset(0, 2 * cell));
    expect(find.byKey(const Key('chip-overflow-season')), findsOneWidget);
    expect(find.byKey(const Key('chip-overflow-deposit')), findsNothing);
    expect(tile('season'), findsNothing);
    expect(tile('deposit'), findsOneWidget);
    await select(tester, 'tradSeason');
    expect(find.byKey(const Key('overflow-tradSeason')), findsOneWidget);
  });

  testWidgets('كل نصوص الشاشة واللوحة محاذاة يمين', (tester) async {
    await openCustomize(tester);
    void check() {
      for (final p in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
        final right =
            p.textAlign == TextAlign.right ||
            (p.textAlign == TextAlign.start && p.textDirection == TextDirection.rtl) ||
            // عناوين التبويبات في وسطها.
            p.textAlign == TextAlign.center;
        expect(right, isTrue, reason: p.text.toPlainText());
        expect(p.textDirection, TextDirection.rtl, reason: p.text.toPlainText());
      }
    }

    check();
    await select(tester, 'season');
    check();
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
