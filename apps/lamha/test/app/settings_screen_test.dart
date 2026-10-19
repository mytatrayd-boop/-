import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/app/places.dart';
import 'package:lamha/src/app/providers.dart';
import 'package:lamha/src/app/services.dart';
import 'package:lamha/src/app/widget_preview.dart';
import 'package:lamha/src/engine/arabic.dart';
import 'package:lamha/src/engine/qibla.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers.dart';
import 'app_helpers.dart';

Finder tile(WidgetElement e) => find.byKey(Key('tile-${e.name}'));

double bgAlpha(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(find.byKey(const Key('preview-background')));
  return (box.decoration as BoxDecoration).color!.a;
}

void main() {
  testWidgets('من اليمين لليسار، والمعاينة فيها المربعات الخمسة بالترتيب', (tester) async {
    await pumpApp(tester);
    final dir = Directionality.of(tester.element(find.byType(Scaffold)));
    expect(dir, TextDirection.rtl);
    for (final e in gridElements) {
      expect(tile(e), findsOneWidget);
    }
    // الصف الأول من اليمين: الصلاة ثم القبلة ثم الإيداع.
    final prayer = tester.getRect(tile(WidgetElement.prayer));
    final qibla = tester.getRect(tile(WidgetElement.qibla));
    final deposit = tester.getRect(tile(WidgetElement.deposit));
    expect(prayer.right, greaterThan(qibla.right));
    expect(qibla.right, greaterThan(deposit.right));
    // الموسم بعرض عمودين.
    final trad = tester.getRect(tile(WidgetElement.tradSeason));
    expect(trad.width / qibla.width, inInclusiveRange(2.0, 2.15));
    expect(trad.top, greaterThan(prayer.bottom));
  });

  testWidgets('المعاينة تعيد الترتيب عند الإخفاء', (tester) async {
    await pumpApp(tester);
    final prayerRect = tester.getRect(tile(WidgetElement.prayer));
    await tester.tap(find.byKey(const Key('switch-prayer')));
    await tester.pumpAndSettle();
    expect(tile(WidgetElement.prayer), findsNothing);
    // أربعة مربعات: ٢×٢، والقبلة تأخذ مكان الصلاة من اليمين.
    final q = tester.getRect(tile(WidgetElement.qibla));
    final d = tester.getRect(tile(WidgetElement.deposit));
    final s = tester.getRect(tile(WidgetElement.season));
    final t = tester.getRect(tile(WidgetElement.tradSeason));
    expect(q.right, closeTo(prayerRect.right, 0.5));
    expect(q.top, closeTo(prayerRect.top, 0.5));
    expect(d.top, q.top);
    expect(q.width, closeTo(d.width, 0.5));
    expect(s.width, closeTo(t.width, 0.5));
    expect(s.top, greaterThan(q.bottom));
    expect(q.width, greaterThan(prayerRect.width));

    // مربع واحد يأخذ الشبكة كلها.
    for (final e in ['qibla', 'deposit', 'season']) {
      await tester.tap(find.byKey(Key('switch-$e')));
      await tester.pumpAndSettle();
    }
    final only = tester.getRect(tile(WidgetElement.tradSeason));
    expect(only.width, greaterThan(q.width * 2));
  });

  test('توزيع الصفوف حسب عدد المربعات', () {
    List<List<int>> shape(int n) => [
          for (final r in gridRows(gridElements.sublist(0, n)))
            [for (final c in r) c.flex]
        ];
    expect(shape(0), isEmpty);
    expect(shape(1), [[1]]);
    expect(shape(2), [[1, 1]]);
    expect(shape(3), [[1, 1], [1]]);
    expect(shape(4), [[1, 1], [1, 1]]);
    expect(shape(5), [[1, 1, 1], [1, 2]]);
  });

  testWidgets('لا يمكن إلغاء آخر إيداع', (tester) async {
    final bridge = await pumpApp(tester);
    // الخامس (المعاشات) ظاهر وغير مفعّل افتراضياً.
    expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('deposit-retirement')))
            .value,
        isFalse);
    expect(find.text('معاشات المتقاعدين'), findsOneWidget);
    for (final id in ['salary', 'citizen_account', 'social_security']) {
      await tester.tap(find.byKey(Key('deposit-$id')));
      await tester.pumpAndSettle();
    }
    final saves = bridge.saved.length;
    await tester.tap(find.byKey(const Key('deposit-housing_support')));
    await tester.pump();
    expect(find.text('يلزم إيداع واحد على الأقل. لإخفاء المربع أطفئ «الإيداع».'),
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
    await tester.tap(find.byKey(const Key('switch-weather')));
    await tester.pumpAndSettle();
    expect(bridge.saved, hasLength(2));
    expect(bridge.updates, 2);
    expect((bridge.last['visible'] as Map)['weather'], isFalse);

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
    await tester.tap(find.text('أبها').last);
    await tester.pumpAndSettle();
    expect((bridge.last['city'] as Map)['name'], 'أبها');
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

  testWidgets('المعاينة: القيمة تحت العنوان مباشرة، والأحجام ١٣/٢٠/١٤ بلا رموز', (tester) async {
    final bridge = await pumpApp(tester);
    Finder inTile(WidgetElement e, String key) => find.descendant(
        of: tile(e),
        matching: key == 'tile-sub'
            ? find.byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('tile-sub-'))
            : find.byKey(Key(key)));
    for (final e in gridElements) {
      final title = tester.widget<Text>(inTile(e, 'tile-title'));
      final value = tester.widget<Text>(inTile(e, 'tile-value'));
      // العنوان والقيمة سطر واحد بلا كسر، يصغر خطهما (حتى ٧٠٪) إن لم يتسعا.
      expect(title.style!.fontSize, inInclusiveRange(13 * 0.7, 13));
      expect(title.maxLines, 1);
      expect(title.softWrap, isFalse);
      expect(value.style!.fontSize, inInclusiveRange(20 * 0.7, 20));
      expect(value.style!.fontWeight, FontWeight.w700);
      for (final sub in tester.widgetList<Text>(inTile(e, 'tile-sub'))) {
        expect(sub.style!.fontSize, 14);
      }
      // لا رموز تعبيرية في المربعات.
      final texts = tester
          .widgetList<Text>(
              find.descendant(of: tile(e), matching: find.byType(Text)))
          .map((t) => t.data!);
      final emoji =
          RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
      for (final t in texts) {
        expect(emoji.hasMatch(t), isFalse, reason: '${e.name}: $t');
      }
      // تتابع من الأعلى: لا فراغ كبير بين العنوان والقيمة.
      final gap = tester.getRect(inTile(e, 'tile-value')).top -
          tester.getRect(inTile(e, 'tile-title')).bottom;
      expect(gap, inInclusiveRange(0, 8), reason: e.name);
    }

    // القبلة: الزاوية سطر والاتجاه سطر تحته.
    final q = bridge.last['qibla'] as Map;
    final qValue = tester.widget<Text>(inTile(WidgetElement.qibla, 'tile-value'));
    expect(qValue.data, '${arabicDigits((q['degrees'] as num).round())}°');
    final qSub = inTile(WidgetElement.qibla, 'tile-sub');
    expect(tester.widget<Text>(qSub).data, q['direction']);
    expect(tester.getRect(qSub).top,
        greaterThan(tester.getRect(inTile(WidgetElement.qibla, 'tile-value')).bottom - 0.5));

    // الصلاة: الاسم، ثم وقتها من الجدول (text)، ثم الباقي.
    // ٩:٠٠Z = ١٢:٠٠ بالرياض، فالقادمة العصر.
    final day = (bridge.last['days'] as List).first as Map;
    final asr = (day['prayers'] as Map)['asr'] as Map;
    expect(tester.widget<Text>(inTile(WidgetElement.prayer, 'tile-value')).data,
        asr['name']);
    final subs = tester
        .widgetList<Text>(inTile(WidgetElement.prayer, 'tile-sub'))
        .map((t) => t.data)
        .toList();
    expect(subs.first, asr['text']);
    // العدّاد بصيغة Chronometer: ١٢:٠٠ ← العصر.
    expect(subs.last, matches(RegExp(r'^باقي [٠-٩]+:[٠-٩]{2}:[٠-٩]{2}$')));

    // الإيداع مع إيداعين: الاسم سطر بـ«…»، والباقي سطر، والثاني سطر بـ«…»، والعنوان المختصر إذا لم يتسع.
    final deps = (day['deposits'] as List).cast<Map>();
    expect(deps.length, greaterThan(1));
    final dValue = tester.widget<Text>(inTile(WidgetElement.deposit, 'tile-value'));
    expect(dValue.data, deps.first['label']);
    expect(dValue.maxLines, 1);
    expect(dValue.overflow, TextOverflow.ellipsis);
    final dSubs =
        tester.widgetList<Text>(inTile(WidgetElement.deposit, 'tile-sub')).toList();
    expect(dSubs.map((t) => t.maxLines), [1, 1]);
    expect(dSubs.first.data, deps.first['remainingText']);
    expect(dSubs.last.data, startsWith('${deps[1]['label']} · '));
    expect(dSubs.last.overflow, TextOverflow.ellipsis);
    final dTitle = inTile(WidgetElement.deposit, 'tile-title');
    // خط الاختبار عريض فلا يتسع «الإيداع القادم» سطراً واحداً، فيصير «الإيداع».
    expect(tester.widget<Text>(dTitle).data, 'الإيداع');
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
