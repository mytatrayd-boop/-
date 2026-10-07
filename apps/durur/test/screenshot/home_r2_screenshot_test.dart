import 'dart:io';
import 'dart:ui' as ui;

import 'package:durur/src/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// لقطة الشاشة الرئيسية (DESIGN R2) للمراجعة البصرية، لا اختبار مقارنة.
/// تُشغَّل يدوياً فقط:
///
///   DURUR_SCREENSHOT=1 flutter test test/screenshot/
///
/// وتكتب `design/mockups/app_home_r2.png` (412dp، الرياض، 7 أكتوبر 2026،
/// بالخطوط الحقيقية Almarai وAmiri).
Future<void> main() async {
  final enabled = Platform.environment['DURUR_SCREENSHOT'] == '1';
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  Future<void> loadFont(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
    await loader.load();
  }

  setUpAll(() async {
    if (!enabled) return;
    await loadFont('Almarai', [
      for (final w in ['Light', 'Regular', 'Bold', 'ExtraBold'])
        'assets/fonts/Almarai-$w.ttf',
    ]);
    await loadFont('Amiri', [
      'assets/fonts/Amiri-Regular.ttf',
      'assets/fonts/Amiri-Bold.ttf',
    ]);
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter';
    await loadFont('MaterialIcons', [
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  });

  testWidgets('لقطة الرئيسية R2', skip: !enabled, (tester) async {
    const width = 412.0;
    const height = 1780.0;
    const ratio = 2.0;
    tester.view.physicalSize = const Size(width * ratio, height * ratio);
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    await pumpDururApp(
      tester,
      prefs: await fakePrefs(savedCity('riyadh')),
      tables: tables,
      extra: [fixedClock(DateTime(2026, 10, 7, 9))],
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpAndSettle();

    final image = await captureImage(
      find.byType(MaterialApp).evaluate().single,
    );
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('design/mockups/app_home_r2.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  });
}
