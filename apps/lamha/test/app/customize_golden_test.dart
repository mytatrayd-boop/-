import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_helpers.dart' show loadImages;
import 'customize_screen_test.dart' show openCustomize, select, tab;

/// لقطتا شاشة «الودجت» بخط Tajawal بمقاس جوال: الشاشة في mockups/customize_screen.png، ولوحة عنصر
/// (تبويب الألوان) في mockups/customize_sheet.png
/// (تُحدَّث بـ --update-goldens).
Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

void main() {
  Future<void> setUp(WidgetTester tester) async {
    await _loadFont('Tajawal', [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
    ]);
    await openCustomize(tester);
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();
  }

  testWidgets('لقطة شاشة الودجت', (tester) async {
    await setUp(tester);
    await loadImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../mockups/customize_screen.png'),
    );
  }, tags: ['golden']);

  testWidgets('لقطة لوحة عنصر (الفصل، تبويب الألوان)', (tester) async {
    await setUp(tester);
    await select(tester, 'season');
    await tab(tester, 'colors');
    await loadImages(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../mockups/customize_sheet.png'),
    );
  }, tags: ['golden']);
}
