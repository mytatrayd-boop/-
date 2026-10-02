import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// إعدادات المنصات للميزة 4 (ARCHITECTURE §7 و§13). البناء الفعلي لم يُختبر
/// هنا (لا Android SDK ولا Xcode)؛ هذا يثبت محتوى الملفات فقط.
void main() {
  group('أندرويد', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final permissions = RegExp(r'<uses-permission\s+android:name="([^"]+)"')
        .allMatches(manifest)
        .map((m) => m.group(1))
        .toList();

    test('الموقع التقريبي فقط', () {
      expect(
        permissions,
        contains('android.permission.ACCESS_COARSE_LOCATION'),
      );
      expect(manifest, isNot(contains('ACCESS_FINE_LOCATION')));
      expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });

    test('إذن خدمة المقدمة الذي تضيفه المكتبة محذوف من الملف المدمج', () {
      expect(
        RegExp(r'FOREGROUND_SERVICE_LOCATION"\s+tools:node="remove"')
            .hasMatch(manifest),
        isTrue,
      );
    });

    test('لا أذونات أخرى (INTERNET يخص الميزة 11)', () {
      expect(permissions, [
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.FOREGROUND_SERVICE_LOCATION', // للحذف فقط
      ]);
      expect(manifest, isNot(contains('android.permission.INTERNET')));
    });
  });

  group('آيفون', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    test('سبب الطلب بالعربية، والدقة المخفّضة افتراضياً', () {
      expect(
        RegExp(
          r'<key>NSLocationWhenInUseUsageDescription</key>\s*'
          r'<string>نستخدم موقعك التقريبي مرة واحدة[^<]+</string>',
        ).hasMatch(plist),
        isTrue,
      );
      expect(
        RegExp(r'<key>NSLocationDefaultAccuracyReduced</key>\s*<true/>')
            .hasMatch(plist),
        isTrue,
      );
    });

    test('لا إذن موقع دائم ولا في الخلفية', () {
      expect(plist, isNot(contains('NSLocationAlways')));
      expect(plist, isNot(contains('UIBackgroundModes')));
    });
  });
}
