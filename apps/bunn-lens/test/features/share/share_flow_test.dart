import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bunn_lens/domain/scan.dart';
import 'package:bunn_lens/features/share/user_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers.dart';

Future<Uint8List> _pngBytes() async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 40, 30), Paint()..color = const Color(0xFF884422));
  final img = await rec.endRecording().toImage(40, 30);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

class _Env {
  _Env(this.t, this.scan);
  final TestRepo t;
  final Scan scan;
}

Future<_Env> _setup(WidgetTester tester, {bool deleteImage = false}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final env = (await tester.runAsync(() async {
    final t = TestRepo.create();
    await t.cafes.save('مقهى الورد', lat: 24.7, lng: 46.6);
    final saved = await t.repo.save(NewScan(
      type: ScanType.bean,
      score: 82,
      notes: const ['أ', 'ب', 'ج'],
      imageBytes: await _pngBytes(),
      roasterName: 'محمصة س',
    ));
    final cafe = (await t.cafes.watchAll().first).first.cafe;
    await t.repo.setCafe(saved.id, cafe.id);
    var scan = (await t.repo.getById(saved.id))!;
    if (deleteImage) File(scan.imagePath).deleteSync();
    return _Env(t, scan);
  }))!;
  addTearDown(() => tester.runAsync(env.t.dispose));
  return env;
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('السجل')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('محمصة س'));
  await tester.pumpAndSettle();
}

/// يدفع الوقت الحقيقي والإطارات حتى يتحقق الشرط (فك صور وكتابة ملفات تحتاج حلقة حدث حقيقية).
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('اسم فارغ: المشاركة تُمنع بطلب الاسم، والإلغاء لا يشارك', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final env = await _setup(tester);
    final calls = <(Uint8List, String)>[];
    await pumpApp(tester,
        repository: env.t.repo,
        cafeRepository: env.t.cafes,
        shareLauncher: (png, text) async => calls.add((png, text)));
    await _openDetail(tester);

    await tester.tap(find.byTooltip('مشاركة'));
    await tester.pump();
    await _until(tester, () => find.text('اكتب اسمك للتوقيع').evaluate().isNotEmpty);
    expect(find.text('اكتب اسمك للتوقيع'), findsOneWidget);
    expect(calls, isEmpty);

    // حقل فارغ ثم حفظ: خطأ ولا مشاركة
    await tester.tap(find.text('حفظ'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('اكتب اسمك أولاً'), findsOneWidget);
    expect(calls, isEmpty);

    // إلغاء
    await tester.tap(find.text('إلغاء'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, isEmpty);
    expect((await SharedPreferences.getInstance()).getString(userNamePrefsKey), isNull);
    await unmountApp(tester);
  });

  testWidgets('كتابة الاسم تحفظه ثم تشارك PNG 1080×1350 مع نص فيه التقييم والمقهى والرابط', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final env = await _setup(tester);
    final calls = <(Uint8List, String)>[];
    await pumpApp(tester,
        repository: env.t.repo,
        cafeRepository: env.t.cafes,
        shareLauncher: (png, text) async => calls.add((png, text)));
    await _openDetail(tester);

    await tester.tap(find.byTooltip('مشاركة'));
    await tester.pump();
    await _until(tester, () => find.text('اكتب اسمك للتوقيع').evaluate().isNotEmpty);
    await tester.enterText(find.byType(TextField), '  منى  ');
    await tester.tap(find.text('حفظ'));
    await tester.pump();
    await _until(tester, () => calls.isNotEmpty);

    expect(calls, hasLength(1));
    final (png, text) = calls.single;
    expect(text, contains('82/100 (تقديري)'));
    expect(text, contains('مقهى الورد'));
    expect(text, contains('https://www.google.com/maps/search/?api=1&query=24.7,46.6'));
    final size = await tester.runAsync(() async {
      final f = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
      return (f.width, f.height);
    });
    expect(size, (1080, 1350));
    expect((await SharedPreferences.getInstance()).getString(userNamePrefsKey), 'منى');
    await unmountApp(tester);
  });

  testWidgets('اسم محفوظ: لا يُسأل ويشارك مباشرة', (tester) async {
    SharedPreferences.setMockInitialValues({userNamePrefsKey: 'سارة'});
    final env = await _setup(tester);
    final calls = <(Uint8List, String)>[];
    await pumpApp(tester,
        repository: env.t.repo,
        cafeRepository: env.t.cafes,
        shareLauncher: (png, text) async => calls.add((png, text)));
    await _openDetail(tester);

    await tester.tap(find.byTooltip('مشاركة'));
    await tester.pump();
    await _until(tester, () => calls.isNotEmpty);
    expect(find.text('اكتب اسمك للتوقيع'), findsNothing);
    expect(calls, hasLength(1));
    await unmountApp(tester);
  });

  testWidgets('صورة الفحص مفقودة: رسالة ولا مشاركة', (tester) async {
    SharedPreferences.setMockInitialValues({userNamePrefsKey: 'سارة'});
    final env = await _setup(tester, deleteImage: true);
    final calls = <(Uint8List, String)>[];
    await pumpApp(tester,
        repository: env.t.repo,
        cafeRepository: env.t.cafes,
        shareLauncher: (png, text) async => calls.add((png, text)));
    await _openDetail(tester);

    await tester.tap(find.byTooltip('مشاركة'));
    await tester.pump();
    await _until(tester, () => find.text('صورة الفحص مفقودة، لا يمكن مشاركته').evaluate().isNotEmpty);
    expect(find.text('صورة الفحص مفقودة، لا يمكن مشاركته'), findsOneWidget);
    expect(calls, isEmpty);
    await unmountApp(tester);
  });

  testWidgets('الإعدادات: كتابة الاسم وتعديله يُحفظان محلياً', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpApp(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('الإعدادات')));
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسمك ليوقّع صور المشاركة'), findsOneWidget);

    await tester.tap(find.text('اسم التوقيع'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ليلى');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('ليلى'), findsOneWidget);

    await tester.tap(find.text('اسم التوقيع'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'ليلى'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ليلى الأحمد');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('ليلى الأحمد'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString(userNamePrefsKey), 'ليلى الأحمد');
    await unmountApp(tester);
  });
}
