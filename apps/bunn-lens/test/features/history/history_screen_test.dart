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
      notes: const ['ملاحظة أولى', 'ملاحظة ثانية', 'ملاحظة ثالثة'],
      imageBytes: const [0, 1, 2],
      roasterName: roaster,
    );

Future<void> openHistory(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text('السجل')));
  await tester.pumpAndSettle();
}

String loc(WidgetTester t) => GoRouter.of(t.element(find.byType(NavigationBar)))
    .routeInformationProvider
    .value
    .uri
    .path;

void main() {
  testWidgets('حالة الفراغ مع زر افحص الآن يفتح تبويب الفحص', (tester) async {
    await pumpApp(tester);
    await openHistory(tester);
    expect(find.text('لا فحوصات بعد'), findsOneWidget);
    await tester.tap(find.text('افحص الآن'));
    await tester.pumpAndSettle();
    expect(loc(tester), AppRoutes.scan);
    await unmountApp(tester);
  });

  testWidgets('القائمة من الأحدث مع الدرجة والمحمصة، والتصفية بالنوع', (tester) async {
    final t = (await tester.runAsync(() async {
      final t = TestRepo.create();
      await t.repo.save(scan(ScanType.bean, 70, roaster: 'الأولى'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await t.repo.save(scan(ScanType.coffee, 91, roaster: 'الثانية'));
      return t;
    }))!;
    addTearDown(() => tester.runAsync(t.dispose));
    await pumpApp(tester, repository: t.repo);
    await openHistory(tester);

    expect(find.text('ممتاز'), findsOneWidget);
    expect(find.text('جيد'), findsOneWidget);
    expect(tester.getTopLeft(find.text('الثانية')).dy,
        lessThan(tester.getTopLeft(find.text('الأولى')).dy));

    await tester.tap(find.widgetWithText(ChoiceChip, 'بن'));
    await tester.pumpAndSettle();
    expect(find.text('جيد'), findsOneWidget);
    expect(find.text('ممتاز'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('فتح بطاقة يعرض النتيجة كاملة مع التنبيه', (tester) async {
    // شاشة طويلة كي تُبنى كل عناصر ListView الكسولة.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final t = (await tester.runAsync(() async {
      final t = TestRepo.create();
      await t.repo.save(scan(ScanType.bean, 82, roaster: 'محمصة س'));
      return t;
    }))!;
    addTearDown(() => tester.runAsync(t.dispose));
    await pumpApp(tester, repository: t.repo);
    await openHistory(tester);
    await tester.tap(find.text('محمصة س'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الفحص'), findsOneWidget);
    expect(find.text('جيد'), findsOneWidget);
    for (final n in ['ملاحظة أولى', 'ملاحظة ثانية', 'ملاحظة ثالثة']) {
      expect(find.text(n), findsOneWidget);
    }
    expect(find.text('التقدير بصري تقريبي وليس حكماً نهائياً'), findsOneWidget);
    expect(find.text('محمصة س'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('الحذف: الإلغاء يُبقي العنصر، والتأكيد يحذفه ويعرض الفراغ', (tester) async {
    final t = (await tester.runAsync(() async {
      final t = TestRepo.create();
      await t.repo.save(scan(ScanType.coffee, 60));
      return t;
    }))!;
    addTearDown(() => tester.runAsync(t.dispose));
    await pumpApp(tester, repository: t.repo);
    await openHistory(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(find.text('حذف هذا الفحص؟'), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(find.text('متوسط'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('حذف')));
    // delete يمرّ بإدخال/إخراج حقيقي؛ نتركه يكتمل خارج الزمن الوهمي،
    // ونستعمل pump لا pumpAndSettle كي لا يختفي الشريط بمهلته.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('متوسط'), findsNothing);
    expect(find.text('تم حذف الفحص'), findsOneWidget);
    expect(find.text('لا فحوصات بعد'), findsOneWidget);
    expect(await tester.runAsync(() => t.repo.watchAll().first), isEmpty);
    await unmountApp(tester);
  });

  testWidgets('الحذف: لا شريط «تم الحذف» إن أعادت delete القيمة false', (tester) async {
    final repo = _ControlledRepo();
    addTearDown(repo.close);
    await tester.pumpWidget(_app(repo));
    await tester.pump();
    await openHistory(tester);
    repo.controller.add([
      Scan(
        id: 1,
        type: ScanType.bean,
        score: 50,
        notes: const ['أ', 'ب', 'ج'],
        imagePath: '/nonexistent/x.jpg',
        createdAt: DateTime(2026, 1, 1),
      ),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('حذف')));
    await tester.pumpAndSettle();
    expect(find.text('تم حذف الفحص'), findsNothing);
    expect(find.text('تعذّر حذف الفحص'), findsNothing);
    await unmountApp(tester);
  });

  testWidgets('حالة التحميل: 4 بطاقات هيكلية', (tester) async {
    final repo = _ControlledRepo();
    addTearDown(repo.close);
    await tester.pumpWidget(_app(repo));
    await tester.pump();
    await openHistory(tester);
    await tester.pump();
    expect(find.byKey(const ValueKey('history-skeleton')), findsNWidgets(4));
    await unmountApp(tester);
  });

  testWidgets('حالة الخطأ مع زر إعادة المحاولة', (tester) async {
    final repo = _ControlledRepo();
    addTearDown(repo.close);
    await tester.pumpWidget(_app(repo));
    await tester.pump();
    await openHistory(tester);
    repo.controller.addError(StateError('x'));
    await tester.pumpAndSettle();
    expect(find.text('تعذّر تحميل السجل'), findsOneWidget);

    repo.nextEmpty = true;
    await tester.tap(find.text('أعد المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('لا فحوصات بعد'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('الإنجليزية LTR: العناوين والحالة الفارغة', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.descendant(
        of: find.byType(NavigationBar), matching: find.text('History')));
    await tester.pumpAndSettle();
    expect(find.text('No scans yet'), findsOneWidget);
    expect(find.text('Scan now'), findsOneWidget);
    await unmountApp(tester);
  });
}

Widget _app(ScanRepository repo) => buildTestApp(repo);

/// مستودع يتحكم الاختبار في بثه.
class _ControlledRepo implements ScanRepository {
  StreamController<List<Scan>> controller = StreamController<List<Scan>>();
  bool nextEmpty = false;

  Future<void> close() async {
    if (!controller.isClosed) await controller.close();
  }

  @override
  Stream<List<Scan>> watchAll({ScanType? type, bool favoritesOnly = false}) {
    if (nextEmpty) return Stream.value(const []);
    return controller.stream;
  }

  @override
  Future<Scan> save(NewScan scan) => throw UnimplementedError();
  @override
  Future<Scan?> getById(int id) async => null;
  @override
  Stream<Scan?> watchById(int id) => Stream.value(null);
  @override
  Future<bool> delete(int id) async => false;
  @override
  Future<bool> setFavorite(int id, bool value) async => false;
  @override
  Future<bool> setCafe(int scanId, int? cafeId) async => false;
}
