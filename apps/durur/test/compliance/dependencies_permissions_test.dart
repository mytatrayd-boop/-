import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// الميزة 10 (SPEC معيار 2، 5، 6؛ D1، D15، D21): فحص آلي للتبعيات
/// والأذونات. لا مكتبة تحليلات أو إعلانات أو تتبع أو مشتريات أو تقارير أعطال
/// أو حسابات في أي تبعية (مباشرة أو انتقالية)، والأذونات هي المسموحة فقط.
/// البناء الفعلي (الملف المدمج بعد البلجنات) لم يُختبر هنا: لا Android SDK ولا
/// Xcode؛ يُفحص بـ aapt عند أول بناء (TESTERS.md).
void main() {
  /// كل الحزم في pubspec.lock (المباشرة والانتقالية).
  List<String> lockedPackages() {
    final lines = File('pubspec.lock').readAsLinesSync();
    final names = <String>[];
    var inPackages = false;
    for (final line in lines) {
      if (line == 'packages:') {
        inPackages = true;
        continue;
      }
      if (inPackages && line.isNotEmpty && !line.startsWith(' ')) break;
      final m = RegExp(r'^  ([a-z0-9_]+):$').firstMatch(line);
      if (inPackages && m != null) names.add(m[1]!);
    }
    return names;
  }

  /// أقسام pubspec.yaml المسماة (dependencies / dev_dependencies).
  List<String> pubspecSection(String section) {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final names = <String>[];
    var inside = false;
    for (final line in lines) {
      if (line == '$section:') {
        inside = true;
        continue;
      }
      if (inside && line.isNotEmpty && !line.startsWith(' ')) break;
      final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
      if (inside && m != null) names.add(m[1]!);
    }
    return names;
  }

  group('التبعيات', () {
    final packages = lockedPackages();

    test('pubspec.lock مقروء وفيه التبعيات المعروفة', () {
      expect(packages.length, greaterThan(50));
      expect(packages, containsAll(['flutter_riverpod', 'go_router']));
    });

    test('لا تحليلات ولا إعلانات ولا تتبع ولا مشتريات ولا Firebase', () {
      // يكفي أن يحتوي الاسم أحد هذه المقاطع. المطابقة بالمقطع قد تعطي
      // إنذاراً كاذباً لحزمة بريئة يحوي اسمها مقطعاً قصيراً (مثل heap
      // أو singular أو branch)؛ عندها تُراجع الحزمة يدوياً، وإن كانت سليمة
      // تُضاف إلى [falsePositives] مع السبب، لا يُحذف المقطع.
      const falsePositives = <String>{};
      const banned = [
        'firebase', // D1: بلا Firebase (ومنه firebase_analytics وcrashlytics)
        'analytics',
        'crashlytics',
        'google_mobile_ads',
        'admob',
        'ads_sdk',
        'applovin',
        'unity_ads',
        'ironsource',
        'appodeal',
        'sentry',
        'bugsnag',
        'datadog',
        'newrelic',
        'instabug',
        'in_app_purchase',
        'purchases_flutter', // RevenueCat
        'revenuecat',
        'amplitude',
        'mixpanel',
        'segment',
        'posthog',
        'appsflyer',
        'adjust',
        'branch',
        'onesignal',
        'facebook',
        'flurry',
        'appmetrica',
        'smartlook',
        'uxcam',
        'clarity',
        'app_tracking_transparency',
        'advertising_id',
        'google_sign_in', // لا حساب ولا تسجيل دخول (SPEC معيار 2)
        'sign_in_with_apple',
        'install_referrer',
        'workmanager', // لا مهام خلفية (§16.2)
        'kochava',
        'singular',
        'appcenter',
        'huawei',
        'hms',
        'umeng',
        'countly',
        'matomo',
        'heap',
        'rollbar',
        'vungle',
        'chartboost',
        'yandex',
        'tiktok',
        'snapchat',
      ];
      final found = [
        for (final p in packages)
          if (!falsePositives.contains(p))
            for (final b in banned)
              if (p.contains(b)) '$p (يطابق "$b")',
      ];
      expect(found, isEmpty);
    });

    test('التبعيات المباشرة هي الموثقة في ARCHITECTURE §14 فقط', () {
      // إضافة مكتبة تتطلب قراراً مسجلاً في DECISIONS.md وتحديث هذه القائمة.
      expect(pubspecSection('dependencies')..sort(), [
        'cryptography',
        'cupertino_icons',
        'flutter',
        'flutter_local_notifications',
        'flutter_localizations',
        'flutter_riverpod',
        'flutter_timezone',
        'geolocator',
        'go_router',
        'intl',
        'meta',
        'package_info_plus',
        'path_provider',
        'shared_preferences',
        'timezone',
        'url_launcher',
      ]);
      expect(pubspecSection('dev_dependencies')..sort(), [
        'flutter_lints',
        'flutter_test',
        'hijri',
      ]);
    });
  });

  group('أذونات أندرويد', () {
    List<String> permissionsIn(String path) =>
        RegExp(r'<uses-permission(?:-sdk-\d+)?\s+android:name="([^"]+)"')
            .allMatches(File(path).readAsStringSync())
            .map((m) => m[1]!)
            .toList();

    test('main: المسموح فقط (FOREGROUND_SERVICE_LOCATION للحذف)', () {
      expect(permissionsIn('android/app/src/main/AndroidManifest.xml')..sort(), [
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.FOREGROUND_SERVICE_LOCATION',
        'android.permission.INTERNET',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      ]);
      expect(
        RegExp(r'FOREGROUND_SERVICE_LOCATION"\s+tools:node="remove"').hasMatch(
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        ),
        isTrue,
      );
    });

    test('debug وprofile: INTERNET لأدوات التطوير فقط (لا تدخل الإصدار)', () {
      for (final flavor in ['debug', 'profile']) {
        expect(
          permissionsIn('android/app/src/$flavor/AndroidManifest.xml'),
          ['android.permission.INTERNET'],
          reason: flavor,
        );
      }
      final manifests = Directory('android/app/src')
          .listSync()
          .whereType<Directory>()
          .map((d) => File('${d.path}/AndroidManifest.xml'))
          .where((f) => f.existsSync())
          .map((f) => f.path.split('/').reversed.skip(1).first)
          .toList()
        ..sort();
      expect(manifests, ['debug', 'main', 'profile']);
    });

    test('لا معرّف إعلانات ولا HTTP صريح، واسم التطبيق بالعربية', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, isNot(contains('AD_ID')));
      expect(manifest, isNot(contains('com.google.android.gms.ads')));
      expect(manifest, contains('android:usesCleartextTraffic="false"'));
      expect(manifest, contains('android:label="ديرة الدرور"'));
    });
  });

  group('آيفون Info.plist', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final keys = RegExp(r'<key>([^<]+)</key>')
        .allMatches(plist)
        .map((m) => m[1]!)
        .toList();

    test('وصف إذن واحد فقط: الموقع أثناء الاستخدام', () {
      expect(keys.where((k) => k.endsWith('UsageDescription')).toList(), [
        'NSLocationWhenInUseUsageDescription',
      ]);
      expect(keys, isNot(contains('NSUserTrackingUsageDescription')));
      expect(keys, isNot(contains('UIBackgroundModes')));
      expect(keys, isNot(contains('NSAppTransportSecurity')));
      expect(keys, isNot(contains('GADApplicationIdentifier')));
      expect(keys, isNot(contains('SKAdNetworkItems')));
    });

    test('العربية لغة التطبيق، واسمه بالعربية (ARCHITECTURE §13)', () {
      expect(
        RegExp(r'<key>CFBundleDevelopmentRegion</key>\s*<string>ar</string>')
            .hasMatch(plist),
        isTrue,
      );
      expect(
        RegExp(
          r'<key>CFBundleLocalizations</key>\s*<array>\s*'
          r'<string>ar</string>\s*</array>',
        ).hasMatch(plist),
        isTrue,
      );
      for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
        expect(
          RegExp('<key>$key</key>\\s*<string>ديرة الدرور</string>')
              .hasMatch(plist),
          isTrue,
          reason: key,
        );
      }
    });
  });
}
