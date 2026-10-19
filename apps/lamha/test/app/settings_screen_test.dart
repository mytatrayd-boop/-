import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_settings.dart';
import 'package:lamha/src/app/cities.dart';
import 'package:lamha/src/engine/settings.dart';
import 'package:lamha/src/app/widget_preview.dart';

import '../helpers.dart';
import 'app_helpers.dart';

Finder tile(WidgetElement e) => find.byKey(Key('tile-${e.name}'));

double bgAlpha(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(find.byKey(const Key('preview-background')));
  final g = (box.decoration as BoxDecoration).gradient! as LinearGradient;
  return g.colors.first.a;
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
    expect(bgAlpha(tester), closeTo(0.92, 0.01));
    final slider = find.byKey(const Key('opacity-slider'));
    // الشريط يعرض الشفافية، ومن اليمين لليسار القيمة الكبرى (شفافية ١٠٠٪) في الطرف الأيسر.
    final r = tester.getRect(slider);
    await tester.tapAt(Offset(r.left + 2, r.center.dy));
    await tester.pumpAndSettle();
    expect(bgAlpha(tester), closeTo(0, 0.02));
    expect(bridge.last['opacity'], lessThan(5));
    await tester.tapAt(Offset(r.right - 2, r.center.dy));
    await tester.pumpAndSettle();
    expect(bgAlpha(tester), closeTo(0.92, 0.02));
    expect(bridge.last['opacity'], greaterThan(95));
    await tester.tapAt(r.center);
    await tester.pumpAndSettle();
    expect(bgAlpha(tester), closeTo(0.46, 0.03));
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

  testWidgets('«موقعي» يختار أقرب مدينة ويحفظ الإحداثيات', (tester) async {
    final bridge = await pumpApp(tester,
        location: FakeLocation((latitude: 21.5, longitude: 39.2)));
    await tester.tap(find.byKey(const Key('my-location')));
    await tester.pumpAndSettle();
    final city = bridge.last['city'] as Map;
    expect(city['name'], 'جدة');
    expect(city['latitude'], 21.5);
  });

  testWidgets('«موقعي» بلا إذن: رسالة ولا تغيير', (tester) async {
    final bridge = await pumpApp(tester);
    await tester.tap(find.byKey(const Key('my-location')));
    await tester.pump();
    expect(find.textContaining('لم يُسمح'), findsOneWidget);
    expect(bridge.saved, hasLength(1));
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

  test('لام الجر', () {
    expect(withLam('الشتاء'), 'للشتاء');
    expect(withLam('سهيل'), 'لسهيل');
  });
}
