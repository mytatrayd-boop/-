import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/app_version.dart';

import 'app_helpers.dart';

void main() {
  test('اسم النسخة المعروض يطابق pubspec.yaml، وبلا رقم بناء يظهر الاسم وحده', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([0-9.]+)\+', multiLine: true).firstMatch(pubspec)!;
    expect(appVersionName, m.group(1));
    // بلا --dart-define=APP_BUILD (الاختبار المحلي): الاسم وحده.
    expect(appVersionText(), appBuildNumber.isEmpty ? appVersionName : '$appVersionName ($appBuildNumber)');
  });

  testWidgets('شاشة الإعدادات تعرض رقم النسخة', (tester) async {
    await pumpApp(tester);
    final v = find.byKey(const Key('app-version'));
    await tester.scrollUntilVisible(v, 300, scrollable: find.byType(Scrollable).first);
    expect((tester.widget<Text>(v)).data, contains(appVersionName));
  });
}
