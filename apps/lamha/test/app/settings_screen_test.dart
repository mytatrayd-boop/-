import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/app/places.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:lamha/src/app/services.dart';
import 'package:lamha/src/app/widget_preview.dart' show withLam;
import 'package:lamha/src/engine/qibla.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'app_helpers.dart';

Finder tile(WidgetElement e) => find.byKey(Key('tile-${e.name}'));

/// العناصر الظاهرة في الترتيب الافتراضي (الميزة ٦) بترتيبها.
final shownTiles = [
  for (final t in defaultLayout)
    if (t.visible) t.id,
];

double bgAlpha(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(find.byKey(const Key('preview-background')));
  return (box.decoration as BoxDecoration).color!.a;
}

void main() {
  testWidgets('من اليمين لليسار، والمعاينة بترتيب تصميم المالك ٣', (tester) async {
    await pumpApp(tester);
    final dir = Directionality.of(tester.element(find.byType(Scaffold)));
    expect(dir, TextDirection.rtl);
    for (final e in WidgetElement.values) {
      expect(tile(e), shownTiles.contains(e) ? findsOneWidget : findsNothing,
          reason: e.name);
    }
    Rect at(WidgetElement e) => tester.getRect(tile(e));
    // الصف ١: الساعة (عرض ٢) يميناً ثم اليوم والطقس.
    expect(at(WidgetElement.clock).left, greaterThan(at(WidgetElement.dayWeather).right));
    expect(at(WidgetElement.clock).width / at(WidgetElement.dayWeather).width,
        inInclusiveRange(1.99, 2.15));
    // الصف ٢: الهجري فوق الميلادي، والقبلة يسارهما.
    expect(at(WidgetElement.hijri).bottom,
        lessThanOrEqualTo(at(WidgetElement.gregorian).top + 0.5));
    expect(at(WidgetElement.hijri).left, greaterThan(at(WidgetElement.qibla).right));
    expect(at(WidgetElement.hijri).top, greaterThan(at(WidgetElement.clock).bottom));
    // الصف ٣ و٤: مواقيت الصلاة ثم الإيداعات، بعرض الودجت.
    expect(at(WidgetElement.prayerTimes).top, greaterThan(at(WidgetElement.gregorian).bottom));
    expect(at(WidgetElement.deposit).top, greaterThan(at(WidgetElement.prayerTimes).bottom));
    expect(at(WidgetElement.prayerTimes).width, closeTo(at(WidgetElement.deposit).width, 0.5));
    // الصف ٥: الفصل ثم الموسم بعرض ٢ (ووصفه داخله؛ مربع «وصف الموسم» مخفي بطلب المالك).
    expect(at(WidgetElement.season).left, greaterThan(at(WidgetElement.tradSeason).right));
    expect(at(WidgetElement.tradSeason).width / at(WidgetElement.season).width, greaterThan(1.9));
    expect(at(WidgetElement.season).top, greaterThan(at(WidgetElement.deposit).bottom));
  });

  testWidgets('لا يمكن إلغاء آخر إيداع', (tester) async {
    final bridge = await pumpApp(tester);
    // الستة مفعّلة افتراضياً (طلب المالك).
    expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('deposit-retirement')))
            .value,
        isTrue);
    expect(
        find.descendant(
            of: find.byKey(const Key('deposit-retirement')),
            matching: find.text('معاشات المتقاعدين')),
        findsOneWidget);
    for (final id in [
      'salary', 'citizen_account', 'social_security', 'comprehensive_rehab', 'retirement',
    ]) {
      final sw = find.byKey(Key('deposit-$id'));
      await tester.ensureVisible(sw);
      await tester.pumpAndSettle();
      await tester.tap(sw);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(const Key('deposit-housing_support')));
    await tester.pumpAndSettle();
    final saves = bridge.saved.length;
    await tester.tap(find.byKey(const Key('deposit-housing_support')));
    await tester.pump();
    expect(find.text('يلزم إيداع واحد على الأقل. لإخفاء المربع استخدم «تخصيص الودجت».'),
        findsOneWidget);
    final sw = tester.widget<SwitchListTile>(
        find.byKey(const Key('deposit-housing_support')));
    expect(sw.value, isTrue);
    expect(bridge.saved.length, saves);
    final day = (bridge.last['days'] as List).first as Map;
    expect((day['deposits'] as List).map((e) => (e as Map)['id']),
        ['housing_support']);
  });

  testWidgets('الشريط يغيّر شفافية خلفية المعاينة', (tester) async {
    final bridge = await pumpApp(tester);
    expect(bgAlpha(tester), closeTo(1, 0.01));
    final slider = find.byKey(const Key('opacity-slider'));
    // الشريط يعرض الشفافية، ومن اليمين لليسار القيمة الكبرى (شفافية ١٠٠٪) في الطرف الأيسر.
    final r = tester.getRect(slider);
    await tester.tapAt(Offset(r.left + 2, r.center.dy));
    await tester.pumpAndSettle();
    expect(bgAlpha(tester), closeTo(0, 0.02));
    expect(bridge.last['opacity'], lessThan(5));
    await tester.tapAt(Offset(r.right - 2, r.center.dy));
    await tester.pumpAndSettle();
    expect(bgAlpha(tester), closeTo(1, 0.02));
    expect(bridge.last['opacity'], greaterThan(95));
    await tester.tapAt(r.center);
    await tester.pumpAndSettle();
    expect(bgAlpha(tester), closeTo(0.5, 0.03));
    expect(find.text('٥٠٪'), findsOneWidget);
  });

  testWidgets('الحفظ يستدعي طبقة home_widget بعد كل تغيير', (tester) async {
    final bridge = await pumpApp(tester);
    // عند الفتح: حفظ وتحديث.
    expect(bridge.saved, hasLength(1));
    expect(bridge.updates, 1);
    expect(bridge.last['days'], hasLength(30));
    final retirement = find.byKey(const Key('deposit-retirement'));
    await tester.ensureVisible(retirement);
    await tester.tap(retirement);
    await tester.pumpAndSettle();
    expect(bridge.saved, hasLength(2));
    expect(bridge.updates, 2);

    await tester.tap(find.byKey(const Key('method-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الهيئة المصرية العامة للمساحة').last);
    await tester.pumpAndSettle();
    expect(bridge.last['prayerMethod'], 'egyptian');
    expect(bridge.updates, 3);
  });

  testWidgets('«موقعي» يحسب بالإحداثيات الفعلية والاسم من geocoding', (tester) async {
    final bridge = await pumpApp(tester,
        location: FakeLocation((latitude: 18.3, longitude: 42.6)),
        geocoder: FakeGeocoder(name: 'خميس مشيط'));
    await tester.tap(find.byKey(const Key('my-location')));
    await tester.pumpAndSettle();
    final city = bridge.last['city'] as Map;
    expect(city['name'], 'خميس مشيط');
    expect(city['latitude'], 18.3);
    expect(city['longitude'], 42.6);
    expect(city['timeZone'], 'Asia/Riyadh');
    // القبلة من الإحداثيات نفسها لا من أقرب مدينة.
    expect((bridge.last['qibla'] as Map)['degrees'],
        double.parse(qiblaDegrees(18.3, 42.6).toStringAsFixed(1)));
    // الاسم يظهر في القائمة تلميحاً لأنه ليس من المدن الجاهزة.
    expect(find.text('خميس مشيط'), findsWidgets);
  });

  testWidgets('«موقعي» بلا إنترنت: اسم أقرب مدينة مع «قرب»', (tester) async {
    final bridge = await pumpApp(tester,
        location: FakeLocation((latitude: 21.5, longitude: 39.2)),
        geocoder: FakeGeocoder(error: Exception('offline')));
    await tester.tap(find.byKey(const Key('my-location')));
    await tester.pumpAndSettle();
    final city = bridge.last['city'] as Map;
    expect(city['name'], 'قرب جدة');
    expect(city['latitude'], 21.5);
    expect(find.textContaining('أقرب مدينة'), findsOneWidget);
  });

  testWidgets('الإعدادات تحفظ المكان المختار وتعيده عند الفتح', (tester) async {
    final bridge = await pumpApp(tester,
        location: FakeLocation((latitude: 18.3, longitude: 42.6)),
        geocoder: FakeGeocoder(name: 'خميس مشيط'));
    await tester.tap(find.byKey(const Key('my-location')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(LamhaSettings.prefsKey)!) as Map;
    expect(saved['cityName'], 'خميس مشيط');
    expect(saved['latitude'], 18.3);
    expect(saved['cityId'], gpsPlaceId);
    expect(bridge.saved, hasLength(2));
  });

  testWidgets('«موقعي» بلا إذن: رسالة ولا تغيير', (tester) async {
    final bridge = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('my-location')));
    await tester.pump();
    expect(find.textContaining('لم يُسمح'), findsOneWidget);
    expect(bridge.saved, hasLength(1));
  });

  testWidgets('«موقعي» عند فشل القراءة: رسالة «تعذّر»', (tester) async {
    await pumpApp(tester, location: _ThrowingLocation());
    await tester.tap(find.byKey(const Key('my-location')));
    await tester.pump();
    expect(find.textContaining('تعذّر تحديد الموقع'), findsOneWidget);
  });

  testWidgets('البحث يعرض النتائج والاختيار يحفظ الإحداثيات', (tester) async {
    final geo = FakeGeocoder(results: const [
      Place(name: 'النماص', latitude: 19.12, longitude: 42.13),
      Place(name: 'تنومة', latitude: 18.93, longitude: 42.18),
    ]);
    final bridge = await pumpApp(tester, geocoder: geo);
    await tester.enterText(find.byKey(const Key('city-search')), 'النماص');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(geo.queries, ['النماص']);
    expect(find.text('تنومة'), findsOneWidget);
    await tester.tap(find.byKey(const Key('place-0')));
    await tester.pumpAndSettle();
    final city = bridge.last['city'] as Map;
    expect(city['name'], 'النماص');
    expect(city['latitude'], 19.12);
    expect(find.byKey(const Key('place-0')), findsNothing);
  });

  testWidgets('البحث بلا إنترنت أو بلا نتائج: رسالة عربية', (tester) async {
    await pumpApp(tester, geocoder: FakeGeocoder(error: Exception('offline')));
    await tester.enterText(find.byKey(const Key('city-search')), 'أبها');
    await tester.tap(find.byKey(const Key('city-search-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('تحقق من الاتصال بالإنترنت'), findsOneWidget);
  });

  testWidgets('البحث بلا نتائج', (tester) async {
    await pumpApp(tester, geocoder: FakeGeocoder());
    await tester.enterText(find.byKey(const Key('city-search')), 'كذا');
    await tester.tap(find.byKey(const Key('city-search-button')));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج. جرّب اسماً آخر.'), findsOneWidget);
  });

  testWidgets('القائمة الجاهزة تبقى اختياراً سريعاً بعد مكان من البحث', (tester) async {
    final bridge = await pumpApp(tester,
        geocoder: FakeGeocoder(results: const [
          Place(name: 'النماص', latitude: 19.12, longitude: 42.13),
        ]));
    await tester.enterText(find.byKey(const Key('city-search')), 'النماص');
    await tester.tap(find.byKey(const Key('city-search-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الخرج').last);
    await tester.pumpAndSettle();
    expect((bridge.last['city'] as Map)['name'], 'الخرج');
  });

  testWidgets('زر لقطة الخلفية لا يظهر في أندرويد', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('background-button')), findsNothing);
  });

  testWidgets('زر لقطة الخلفية يظهر في آيفون', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await pumpApp(tester);
    expect(find.byKey(const Key('background-button')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('آيفون: اسم ملف اللقطة في الجدول المحفوظ (نسبي داخل الحاوية)',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final store = FakeBackgroundStore();
    final bridge = await pumpApp(tester, background: store);
    expect(bridge.last['background'], isNull);
    await tester.tap(find.byKey(const Key('background-button')));
    await tester.pumpAndSettle();
    expect(store.picks, 1);
    expect(bridge.last['background'], 'wallpaper.jpg');
    expect(find.text('حُفظت لقطة الخلفية'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('آيفون: فشل حفظ اللقطة يعرض رسالة ولا يغيّر الجدول', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final store = FakeBackgroundStore(null, StateError('no container'));
    final bridge = await pumpApp(tester, background: store);
    await tester.tap(find.byKey(const Key('background-button')));
    await tester.pumpAndSettle();
    expect(store.picks, 1);
    expect(bridge.last['background'], isNull);
    expect(find.textContaining('تعذّر حفظ لقطة الخلفية'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('أندرويد: background في الجدول null حتى لو حُفظ ملف', (tester) async {
    final saved = LamhaSettings.defaults(
      parseCities(readAsset('assets/cities.json')).first,
      {'salary'},
    ).copyWith(backgroundFile: 'wallpaper.jpg');
    final bridge = await pumpApp(tester,
        prefs: {LamhaSettings.prefsKey: saved.encode()});
    expect(bridge.last.containsKey('background'), isTrue);
    expect(bridge.last['background'], isNull);
  });

  testWidgets('المعاينة (الميزة ٦): مواقيت تدور بالقادمة مميزة، وأعمدة الإيداعات، والقبلة، ونقاط الموسم',
      (tester) async {
    final bridge = await pumpApp(tester);
    final day = (bridge.last['days'] as List).first as Map;
    final next = (bridge.last['days'] as List)[1] as Map;
    String text(String key) => tester.widget<Text>(find.byKey(Key(key))).data!;
    Color? color(String key) => tester.widget<Text>(find.byKey(Key(key))).style!.color;

    // ٩:٠٠Z = ١٢:٠٠ بالرياض: العصر أولاً، والفجر والظهر من الغد بأوقات الغد.
    Map p(Map d, String k) => (d['prayers'] as Map)[k] as Map;
    final expected = [
      p(day, 'asr'), p(day, 'maghrib'), p(day, 'isha'), p(next, 'fajr'), p(next, 'dhuhr'),
    ];
    for (var i = 0; i < 5; i++) {
      expect(text('prayer-name-$i'), expected[i]['name']);
      // الوقت يصغر مع الاسم، ويُخفى إن لم يتسع حتى ٨٠٪ (خط الاختبار عريض).
      if (find.byKey(Key('prayer-sub-$i')).evaluate().isNotEmpty) {
        expect(text('prayer-sub-$i'), expected[i]['text']);
      }
    }
    const accent = Color(0xFFD6AA5C);
    expect(color('prayer-name-0'), accent);
    if (find.byKey(const Key('prayer-sub-0')).evaluate().isNotEmpty) {
      expect(color('prayer-sub-0'), accent);
    }
    expect(color('prayer-name-1'), isNot(accent));
    // أول عمود من اليمين.
    expect(tester.getRect(find.byKey(const Key('prayer-name-0'))).left,
        greaterThan(tester.getRect(find.byKey(const Key('prayer-name-1'))).right));
    // الأعمدة بحجم واحد (تصغر بالتساوي إن لزم).
    final sizes = {for (var i = 0; i < 5; i++) tester.widget<Text>(find.byKey(Key('prayer-name-$i'))).style!.fontSize};
    expect(sizes, hasLength(1));
    expect(sizes.single, lessThanOrEqualTo(20));

    // الإيداعات الستة الافتراضية: شبكة عمودين وثلاثة صفوف بلا عنوان، الأقرب أولاً من اليمين،
    // والاسم وبجانبه الأيام.
    final deps = (day['deposits'] as List).cast<Map>();
    expect(deps.length, 6);
    for (var i = 0; i < 6; i++) {
      expect(text('deposit-name-$i'), deps[i]['label']);
      expect(text('deposit-days-$i'), deps[i]['daysText']);
    }
    expect(find.byKey(const Key('deposit-cell-6')), findsNothing);
    expect(find.byKey(const Key('deposit-sub-0')), findsNothing);
    expect(find.byKey(const Key('deposit-title')), findsNothing);
    expect(find.text('متبقي على:'), findsNothing);
    // الأيام كجدول (طلب المالك): تبدأ من موضع واحد في كل عمود، والاسم يمينها.
    Rect at(String k) => tester.getRect(find.byKey(Key(k)));
    expect(at('deposit-days-0').right, closeTo(at('deposit-days-2').right, 0.01));
    expect(at('deposit-days-0').right, closeTo(at('deposit-days-4').right, 0.01));
    expect(at('deposit-days-1').right, closeTo(at('deposit-days-5').right, 0.01));
    expect(at('deposit-name-0').left, greaterThanOrEqualTo(at('deposit-days-0').right));
    expect(tester.getRect(find.byKey(const Key('deposit-cell-0'))).left,
        greaterThan(tester.getRect(find.byKey(const Key('deposit-cell-1'))).right));
    expect(tester.getRect(find.byKey(const Key('deposit-cell-2'))).top,
        greaterThan(tester.getRect(find.byKey(const Key('deposit-cell-0'))).bottom));
    expect(find.byKey(const Key('deposit-row-2')), findsOneWidget);

    // القبلة (lamha_qibla_update.md): الدائرة وتحتها الزاوية ثم «من الشمال · الاتجاه».
    expect(find.byKey(const Key('preview-qibla-icon')), findsOneWidget);
    expect(find.byKey(const Key('preview-qibla-dial')), findsOneWidget);
    expect(text('preview-qibla-title'), '٢٤٤°');
    expect(text('preview-qibla-sub'), 'من الشمال · جنوب غرب');
    expect(tester.getRect(find.byKey(const Key('preview-qibla-sub'))).top,
        greaterThanOrEqualTo(tester.getRect(find.byKey(const Key('preview-qibla-title'))).bottom));
    expect(tester.getRect(find.byKey(const Key('preview-qibla-title'))).top,
        greaterThanOrEqualTo(tester.getRect(find.byKey(const Key('preview-qibla-icon'))).bottom));

    // الفصل والموسم بلا عناوين، وتحتهما «الشتاء بعد … يوماً».
    final season = day['season'] as Map;
    final seasonTexts = tester
        .widgetList<Text>(find.descendant(of: tile(WidgetElement.season), matching: find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(seasonTexts.first, season['name']);
    expect(seasonTexts, isNot(contains('الفصل')));
    if (seasonTexts.length > 1) {
      expect(seasonTexts[1], '${(season['next'] as Map)['name']} ${season['afterText']}');
    }

    // الموسم بتنسيق المالك: «الوسم (المربعانية بعد … يوماً)» في سطر، وتحته وصف يبدأ باسم الموسم.
    final trad = day['tradSeason'] as Map;
    final tradTexts = [
      for (final t in tester.widgetList<Text>(
          find.descendant(of: tile(WidgetElement.tradSeason), matching: find.byType(Text))))
        t.data ?? t.textSpan!.toPlainText(),
    ];
    final note = '(${(trad['next'] as Map)['name']} ${trad['afterText']})'.replaceAll(' ', '\u00A0');
    // في سطر الاسم إن اتسع، وإلا أول سطر تحته.
    expect(tradTexts.first == '${trad['name']} $note' || (tradTexts.first == trad['name'] && tradTexts[1] == note), isTrue,
        reason: '$tradTexts');
    if (tradTexts.length > (tradTexts.first == trad['name'] ? 2 : 1)) expect(tradTexts.last, trad['descriptionLine']);
    expect((trad['descriptionLine'] as String).startsWith('${trad['name']} '), isTrue);

    // لا رموز تعبيرية في الصناديق.
    final emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
    for (final e in [WidgetElement.prayerTimes, WidgetElement.deposit, WidgetElement.season,
        WidgetElement.tradSeason, WidgetElement.qibla]) {
      for (final t in tester.widgetList<Text>(find.descendant(of: tile(e), matching: find.byType(Text)))) {
        final s = t.data ?? t.textSpan!.toPlainText();
        expect(emoji.hasMatch(s), isFalse, reason: '${e.name}: $s');
      }
    }
  });

  testWidgets('الصلاة القادمة القديمة في ترتيب مخصص: الاسم ثم الوقت ثم العدّاد', (tester) async {
    final city = parseCities(readAsset('assets/cities.json')).first;
    // مخصص (لون واحد مختلف)، فلا يُرحَّل إلى الترتيب الجديد.
    final custom = [
      for (final t in legacyDefaultLayout)
        t.id == WidgetElement.season ? t.copyWith(primaryColor: () => TileColor.white) : t,
    ];
    final s = LamhaSettings.defaults(city, {'salary', 'citizen_account'}).copyWith(layout: custom);
    final bridge = await pumpApp(tester, prefs: {LamhaSettings.prefsKey: s.encode()});
    expect(tile(WidgetElement.prayer), findsOneWidget);
    expect(tile(WidgetElement.prayerTimes), findsNothing);
    final day = (bridge.last['days'] as List).first as Map;
    final asr = (day['prayers'] as Map)['asr'] as Map;
    Finder inTile(String key) => find.descendant(of: tile(WidgetElement.prayer), matching: find.byKey(Key(key)));
    expect(tester.widget<Text>(inTile('tile-value')).data, asr['name']);
    final subs = [
      for (var i = 0; i < 2; i++)
        if (inTile('tile-sub-$i').evaluate().isNotEmpty) tester.widget<Text>(inTile('tile-sub-$i')).data,
    ];
    if (subs.length == 2) expect(subs.first, asr['text']);
    expect(subs.last, matches(RegExp(r'^(باقي )?[٠-٩]+:[٠-٩]{2}:[٠-٩]{2}$')));
  });

  test('لام الجر', () {
    expect(withLam('الشتاء'), 'للشتاء');
    expect(withLam('سهيل'), 'لسهيل');
  });
}

class _ThrowingLocation implements LocationService {
  @override
  Future<({double latitude, double longitude})?> currentPosition() async =>
      throw Exception('timeout');
}
