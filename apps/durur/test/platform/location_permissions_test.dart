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
        // الميزة 8: التنبيهات المحلية.
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      ]);
      expect(manifest, isNot(contains('android.permission.INTERNET')));
    });

    test('الميزة 8: مستقبلا الجدولة، بلا إذن المنبهات الدقيقة (D13)', () {
      // قائمة الأذونات أعلاه تثبت غياب SCHEDULE_EXACT_ALARM وUSE_EXACT_ALARM.
      expect(
        permissions.where((p) => p!.contains('EXACT_ALARM')),
        isEmpty,
      );
      expect(
        manifest,
        contains('flutterlocalnotifications.ScheduledNotificationReceiver'),
      );
      expect(
        manifest,
        contains('flutterlocalnotifications.ScheduledNotificationBootReceiver'),
      );
      expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isCoreLibraryDesugaringEnabled = true'));
      expect(gradle, contains('coreLibraryDesugaring('));
      expect(
        File('android/app/src/main/res/drawable/ic_stat_durur.xml')
            .existsSync(),
        isTrue,
      );
      expect(
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync(),
        contains('@drawable/ic_stat_durur'),
      );
    });
  });

  group('آيفون', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    test('الميزة 8: مندوب UNUserNotificationCenter', () {
      expect(
        File('ios/Runner/AppDelegate.swift').readAsStringSync(),
        contains('UNUserNotificationCenter.current().delegate'),
      );
    });

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
