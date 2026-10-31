import 'package:bunn_lens/domain/scan.dart';
import 'package:bunn_lens/features/cafes/data/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

NewScan _scan() => NewScan(
      type: ScanType.bean,
      score: 82,
      notes: const ['أ', 'ب', 'ج'],
      imageBytes: const [1, 2, 3],
      roasterName: 'محمصة س',
    );

class _Env {
  _Env(this.t, this.scanId);
  final TestRepo t;
  final int scanId;
}

Future<_Env> _setup(WidgetTester tester, {List<String> cafes = const []}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final env = (await tester.runAsync(() async {
    final t = TestRepo.create();
    for (final c in cafes) {
      await t.cafes.save(c, lat: 1, lng: 2);
    }
    final s = await t.repo.save(_scan());
    return _Env(t, s.id);
  }))!;
  addTearDown(() => tester.runAsync(env.t.dispose));
  return env;
}

Future<void> _openDetail(WidgetTester tester, String tab, String roaster) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(roaster));
  await tester.pumpAndSettle();
}

/// يمنح drift وقتاً حقيقياً لإنهاء الكتابة وبث التغيير.
Future<void> _settleDb(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('عربي RTL: إذن ممنوح ← اسم ← حفظ مع الإحداثيات وظهور الاسم في السجل', (tester) async {
    final env = await _setup(tester);
    final loc = FakeLocationService(const LocationResult.success(24.7, 46.6));
    await pumpApp(tester, repository: env.t.repo, cafeRepository: env.t.cafes, locationService: loc);
    await _openDetail(tester, 'السجل', 'محمصة س');

    await tester.tap(find.byTooltip('احفظ مكان المقهى'));
    await tester.pumpAndSettle();
    expect(loc.calls, 1);
    expect(find.text('اسم المقهى'), findsWidgets);
    expect(Directionality.of(tester.element(find.byType(TextField))), TextDirection.rtl);

    // اسم فارغ مرفوض
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل اسم المقهى'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'مقهى الحي');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('حُفظ المقهى'), findsOneWidget);

    final saved = (await tester.runAsync(() => env.t.repo.getById(env.scanId)))!;
    expect(saved.cafe!.name, 'مقهى الحي');
    expect((saved.cafe!.lat, saved.cafe!.lng), (24.7, 46.6));
    expect(find.text('مقهى الحي'), findsWidgets); // صف المقهى في التفاصيل

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('مقهى الحي'), findsOneWidget); // بطاقة السجل
    await unmountApp(tester);
  });

  testWidgets('رفض الإذن: رسالة ثم متابعة بالاسم فقط بلا إحداثيات', (tester) async {
    final env = await _setup(tester);
    final loc = FakeLocationService(const LocationResult.failure(LocationFailure.denied));
    await pumpApp(tester, repository: env.t.repo, cafeRepository: env.t.cafes, locationService: loc);
    await _openDetail(tester, 'السجل', 'محمصة س');

    await tester.tap(find.byTooltip('احفظ مكان المقهى'));
    await tester.pumpAndSettle();
    expect(find.textContaining('لم نحصل على إذن الموقع'), findsOneWidget);
    await tester.tap(find.text('احفظ الاسم فقط'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'بلا موقع');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();

    final saved = (await tester.runAsync(() => env.t.repo.getById(env.scanId)))!;
    expect(saved.cafe!.name, 'بلا موقع');
    expect(saved.cafe!.hasLocation, isFalse);
    expect(find.text('افتح في خرائط قوقل'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('رفض الإذن ثم إلغاء: لا يُحفظ شيء', (tester) async {
    final env = await _setup(tester);
    final loc = FakeLocationService(const LocationResult.failure(LocationFailure.deniedForever));
    await pumpApp(tester, repository: env.t.repo, cafeRepository: env.t.cafes, locationService: loc);
    await _openDetail(tester, 'السجل', 'محمصة س');
    await tester.tap(find.byTooltip('احفظ مكان المقهى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    final saved = (await tester.runAsync(() => env.t.repo.getById(env.scanId)))!;
    expect(saved.cafe, isNull);
    await unmountApp(tester);
  });

  testWidgets('اقتراحات من المقاهي المحفوظة وإعادة استخدام المقهى بلا تكرار', (tester) async {
    final env = await _setup(tester, cafes: ['Blue Bottle', 'مقهى الورد']);
    final loc = FakeLocationService(const LocationResult.success(5, 6));
    await pumpApp(tester, repository: env.t.repo, cafeRepository: env.t.cafes, locationService: loc);
    await _openDetail(tester, 'السجل', 'محمصة س');
    await tester.tap(find.byTooltip('احفظ مكان المقهى'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'blue');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Blue Bottle'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'مقهى الورد'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, 'Blue Bottle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    final all = (await tester.runAsync(() => env.t.cafes.watchAll().first))!;
    expect(all.length, 2);
    final saved = (await tester.runAsync(() => env.t.repo.getById(env.scanId)))!;
    expect(saved.cafe!.name, 'Blue Bottle');
    await unmountApp(tester);
  });

  testWidgets('إنجليزي LTR: الحفظ وزر افتح في الخرائط برابط الإحداثيات', (tester) async {
    final env = await _setup(tester);
    final loc = FakeLocationService(const LocationResult.success(24.5, 46.25));
    final opened = <Uri>[];
    await pumpApp(tester,
        locale: const Locale('en'),
        repository: env.t.repo,
        cafeRepository: env.t.cafes,
        locationService: loc,
        urlOpener: (u) async {
          opened.add(u);
          return true;
        });
    await _openDetail(tester, 'History', 'محمصة س');
    await tester.tap(find.byTooltip('Save cafe location'));
    await tester.pumpAndSettle();
    expect(Directionality.of(tester.element(find.byType(TextField))), TextDirection.ltr);
    await tester.enterText(find.byType(TextField), 'Roast House');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Cafe saved'), findsOneWidget);

    await tester.tap(find.text('Open in Google Maps'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(),
        'https://www.google.com/maps/search/?api=1&query=24.5,46.25');
    await unmountApp(tester);
  });

  testWidgets('شاشة المقاهي من الإعدادات: قائمة، فتح الخرائط، تعديل، حذف بتأكيد', (tester) async {
    final env = await _setup(tester, cafes: ['مقهى أ']);
    await tester.runAsync(() async {
      final c = (await env.t.cafes.watchAll().first).single.cafe;
      await env.t.repo.setCafe(env.scanId, c.id);
      await env.t.cafes.save('بلا موقع');
    });
    final opened = <Uri>[];
    await pumpApp(tester,
        repository: env.t.repo,
        cafeRepository: env.t.cafes,
        urlOpener: (u) async {
          opened.add(u);
          return true;
        });
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('الإعدادات')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مقاهيّ المحفوظة'));
    await tester.pumpAndSettle();

    expect(find.text('مقهى أ'), findsOneWidget);
    expect(find.textContaining('الفحوصات: 1'), findsOneWidget);
    expect(find.textContaining('آخر درجة: 82/100'), findsOneWidget);
    expect(find.textContaining('بلا موقع'), findsWidgets);

    await tester.tap(find.text('مقهى أ'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://www.google.com/maps/search/?api=1&query=1.0,2.0');

    // تعديل الاسم
    await tester.tap(find.byTooltip('خيارات المقهى').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل الاسم'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'مقهى ب');
    await tester.tap(find.text('حفظ'));
    await _settleDb(tester);
    expect(find.text('مقهى ب'), findsOneWidget);
    expect(find.text('مقهى أ'), findsNothing);

    // حذف: إلغاء ثم تأكيد
    await tester.tap(find.byTooltip('خيارات المقهى').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المقهى'));
    await tester.pumpAndSettle();
    expect(find.text('حذف هذا المقهى؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('مقهى ب'), findsOneWidget);

    await tester.tap(find.byTooltip('خيارات المقهى').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف المقهى'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('حذف')));
    await _settleDb(tester);
    expect(find.text('مقهى ب'), findsNothing);
    final scan = (await tester.runAsync(() => env.t.repo.getById(env.scanId)))!;
    expect(scan.cafe, isNull); // الفحص باقٍ
    await unmountApp(tester);
  });

  testWidgets('شاشة المقاهي من المفضلة، والحالة الفارغة بالإنجليزي', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Favorites')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('My saved cafes'));
    await tester.pumpAndSettle();
    expect(find.text('No cafe saved yet'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('اسم المقهى يظهر في بطاقة المفضلة', (tester) async {
    final env = await _setup(tester, cafes: ['مقهى المفضلة']);
    await tester.runAsync(() async {
      final c = (await env.t.cafes.watchAll().first).single.cafe;
      await env.t.repo.setCafe(env.scanId, c.id);
      await env.t.repo.setFavorite(env.scanId, true);
    });
    await pumpApp(tester, repository: env.t.repo, cafeRepository: env.t.cafes);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('المفضلة')));
    await tester.pumpAndSettle();
    expect(find.text('مقهى المفضلة'), findsOneWidget);
    await unmountApp(tester);
  });
}
