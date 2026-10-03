import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// اسم التطبيق «دليل المواسم» (الميزة 12، D32).
void main() {
  const oldName = 'ديرة الدرور';
  const newName = 'دليل المواسم';

  test('ARB: الاسم الجديد، ولا يظهر الاسم القديم في أي نص', () {
    final arb =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    expect(arb['appTitle'], newName);
    expect(arb['onboardingWelcomeTitle'], contains(newName));
    for (final MapEntry(:key, :value) in arb.entries) {
      if (key.startsWith('@') || value is! String) continue;
      expect(value, isNot(contains(oldName)), reason: key);
    }
  });

  test('نصوص البيانات لا تعرض الاسم القديم', () {
    final files = Directory('assets/tables')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    for (final file in files) {
      expect(
        file.readAsStringSync(),
        isNot(contains(oldName)),
        reason: file.path,
      );
    }
  });

  test('اسم أندرويد وآيفون جديد، والمعرّفات الداخلية باقية', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:label="$newName"'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains(oldName)));
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      expect(
        RegExp('<key>$key</key>\\s*<string>$newName</string>').hasMatch(plist),
        isTrue,
        reason: key,
      );
    }
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.durur.durur"'));
    expect(gradle, contains('namespace = "com.durur.durur"'));
    expect(File('pubspec.yaml').readAsStringSync(), startsWith('name: durur'));
  });
}
