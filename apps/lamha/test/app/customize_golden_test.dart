import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customize_screen_test.dart' show openCustomize, select;

/// لقطة شاشة «تخصيص الودجت» (الميزة ٥ب) بخط Tajawal بمقاس جوال، في mockups/customize_screen.png
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
  testWidgets('لقطة شاشة التخصيص (الصلاة مختارة)', (tester) async {
    await _loadFont('Tajawal', [
      'assets/fonts/Tajawal-Regular.ttf',
      'assets/fonts/Tajawal-Medium.ttf',
      'assets/fonts/Tajawal-Bold.ttf',
    ]);
    await openCustomize(tester);
    tester.view.physicalSize = const Size(412 * 2, 915 * 2);
    tester.view.devicePixelRatio = 2;
    await tester.pumpAndSettle();
    await select(tester, 'prayer');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../mockups/customize_screen.png'),
    );
  }, tags: ['golden']);
}
