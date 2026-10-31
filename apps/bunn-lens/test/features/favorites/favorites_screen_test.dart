import 'dart:async';

import 'package:bunn_lens/app/router.dart';
import 'package:bunn_lens/data/repositories/scan_repository.dart';
import 'package:bunn_lens/domain/scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers.dart';

NewScan scan(ScanType type, int score, {String? roaster}) => NewScan(
      type: type,
      score: score,
      notes: const ['أ', 'ب', 'ج'],
      imageBytes: const [0, 1, 2],
      roasterName: roaster,
    );

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

String loc(WidgetTester t) => GoRouter.of(t.element(find.byType(NavigationBar)))
    .routeInformationProvider
    .value
    .uri
    .path;

/// يسمح لإدخال/إخراج drift الحقيقي بالاكتمال خارج الزمن الوهمي.
Future<void> settleReal(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<TestRepo> seeded(WidgetTester tester) async {
  final t = (await tester.runAsync(() async {
    final t = TestRepo.create();
    final a = await t.repo.save(scan(ScanType.bean, 70, roaster: 'الأولى'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final b = await t.repo.save(scan(ScanType.coffee, 91, roaster: 'الثانية'));
    await t.repo.save(scan(ScanType.bean, 55, roaster: 'الثالثة'));
    await t.repo.setFavorite(a.id, true);
    await t.repo.setFavorite(b.id, true);
    return t;
  }))!;
  addTearDown(() => tester.runAsync(t.dispose));
  return t;
}

void main() {
  testWidgets('فارغ: رسالة ولا بطاقات', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'المفضلة');
    expect(find.text('لم تحفظ شيئاً بعد. اضغط النجمة في أي نتيجة'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('قائمة: المفضلة فقط، والمرشح بن/قهوة، والفتح يعرض التفاصيل', (tester) async {
    // شاشة طويلة كي تُبنى كل عناصر ListView الكسولة في التفاصيل.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final t = await seeded(tester);
    await pumpApp(tester, repository: t.repo);
    await openTab(tester, 'المفضلة');
    await settleReal(tester);
    expect(find.text('الأولى'), findsOneWidget);
    expect(find.text('الثانية'), findsOneWidget);
    expect(find.text('الثالثة'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'قهوة'));
    await tester.pumpAndSettle();
    expect(find.text('الثانية'), findsOneWidget);
    expect(find.text('الأولى'), findsNothing);

    await tester.tap(find.text('الثانية'));
    await settleReal(tester);
    expect(loc(tester), startsWith('${AppRoutes.favorites}/'));
    expect(find.text('تفاصيل الفحص'), findsOneWidget);
    expect(find.text('91/100'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('إزالة النجمة تُخرج البطاقة مع تراجع يعيدها', (tester) async {
    final t = await seeded(tester);
    await pumpApp(tester, repository: t.repo);
    await openTab(tester, 'المفضلة');
    await settleReal(tester);
    await tester.tap(find.byTooltip('إزالة من المفضلة').first); // الثانية (الأحدث)
    await settleReal(tester);
    expect(find.text('الثانية'), findsNothing);
    expect(find.text('أُزيل من المفضلة'), findsOneWidget);
    await tester.tap(find.text('تراجع'));
    await settleReal(tester);
    expect(find.text('الثانية'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('نجمة السجل تضيف للمفضلة وتظهر في التبويب', (tester) async {
    final t = await seeded(tester);
    await pumpApp(tester, repository: t.repo);
    await openTab(tester, 'السجل');
    await settleReal(tester);
    await tester.tap(find.byTooltip('إضافة إلى المفضلة')); // الثالثة فقط غير مفضلة
    await settleReal(tester);
    expect(find.text('أُضيف للمفضلة'), findsOneWidget);
    await openTab(tester, 'المفضلة');
    await settleReal(tester);
    expect(find.text('الثالثة'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('نجمة التفاصيل تبدّل الحالة', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final t = await seeded(tester);
    await pumpApp(tester, repository: t.repo);
    await openTab(tester, 'المفضلة');
    await settleReal(tester);
    await tester.tap(find.text('الثانية'));
    await settleReal(tester);
    await tester.tap(find.descendant(
        of: find.byType(AppBar), matching: find.byTooltip('إزالة من المفضلة')));
    await settleReal(tester);
    expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('إضافة إلى المفضلة')),
        findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('إنجليزي LTR: العناوين والفراغ', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    await openTab(tester, 'Favorites');
    expect(find.text("You haven't saved anything yet. Tap the star on any result"),
        findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(NavigationBar))), TextDirection.ltr);
    await unmountApp(tester);
  });

  testWidgets('إنجليزي: نجمة بنصوص إنجليزية', (tester) async {
    final t = await seeded(tester);
    await pumpApp(tester, locale: const Locale('en'), repository: t.repo);
    await openTab(tester, 'Favorites');
    await settleReal(tester);
    expect(find.byTooltip('Remove from favorites'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Remove from favorites').first);
    await settleReal(tester);
    expect(find.text('Removed from favorites'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('RTL في العربية', (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'المفضلة');
    expect(Directionality.of(tester.element(find.byType(NavigationBar))), TextDirection.rtl);
    await unmountApp(tester);
  });

  testWidgets('تحميل ثم خطأ مع إعادة المحاولة', (tester) async {
    final repo = _Repo();
    addTearDown(repo.close);
    await tester.pumpWidget(buildTestApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('المفضلة')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('favorites-skeleton')), findsNWidgets(4));

    repo.controller.addError(StateError('x'));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر تحميل المفضلة'), findsOneWidget);

    repo.controller = StreamController<List<Scan>>();
    await tester.tap(find.text('أعد المحاولة'));
    await tester.pump();
    repo.controller.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('لم تحفظ شيئاً بعد. اضغط النجمة في أي نتيجة'), findsOneWidget);
    await unmountApp(tester);
  });
}

class _Repo implements ScanRepository {
  StreamController<List<Scan>> controller = StreamController<List<Scan>>();
  Future<void> close() async {
    if (!controller.isClosed) await controller.close();
  }

  @override
  Stream<List<Scan>> watchAll({ScanType? type, bool favoritesOnly = false}) => controller.stream;
  @override
  Future<bool> setFavorite(int id, bool value) async => false;
  @override
  Future<Scan> save(NewScan scan) => throw UnimplementedError();
  @override
  Future<Scan?> getById(int id) async => null;
  @override
  Stream<Scan?> watchById(int id) => Stream.value(null);
  @override
  Future<bool> delete(int id) async => false;
}
