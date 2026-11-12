import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lamha/src/app/adhan_service.dart';
import 'package:lamha/src/engine/adhan.dart';
import 'package:lamha/src/engine/prayer.dart';

import 'app_helpers.dart';

/// شاشة الأذان في الإعدادات (DECISIONS ٢٨): المفاتيح، وطلب الأذونات، وجدولة التنبيهات، وتجربة الصوت.
void main() {
  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  bool on(WidgetTester tester, String key) =>
      tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

  testWidgets('مطفأ افتراضياً: لا مفاتيح صلوات ولا جدولة', (tester) async {
    final adhan = FakeAdhanNotifier();
    await pumpApp(tester, adhan: adhan);
    await tester.ensureVisible(find.byKey(const Key('adhan-enabled')));
    expect(on(tester, 'adhan-enabled'), isFalse);
    expect(find.byKey(const Key('adhan-fajr')), findsNothing);
    expect(find.byKey(const Key('adhan-test')), findsNothing);
    expect(adhan.permissionRequests, 0);
    expect(adhan.applied.every((a) => a.events.isEmpty), isTrue);
  });

  testWidgets('تفعيله يطلب الأذونات ويجدوِل خمس صلوات، ويحفظ في الإعدادات', (tester) async {
    final adhan = FakeAdhanNotifier();
    final bridge = await pumpApp(tester, adhan: adhan);
    await tapKey(tester, 'adhan-enabled');
    expect(adhan.permissionRequests, 1);
    expect(on(tester, 'adhan-enabled'), isTrue);
    for (final p in adhanPrayers) {
      expect(on(tester, 'adhan-${p.name}'), isTrue, reason: p.name);
    }
    expect(adhan.lastEvents, hasLength(adhanMaxEvents));
    expect(adhan.applied.last.city, isNotEmpty);
    expect(adhan.lastEvents.first.time.isAfter(testNow), isTrue);
    // لا يدخل جدول الودجت.
    expect(bridge.last.containsKey('adhan'), isFalse);
  });

  testWidgets('رفض إذن الإشعارات يبقيه مطفأً برسالة ولا يجدوِل', (tester) async {
    final adhan = FakeAdhanNotifier(
        permission: const AdhanPermissionResult(notifications: false, exactAlarms: false));
    await pumpApp(tester, adhan: adhan);
    await tapKey(tester, 'adhan-enabled');
    expect(adhan.permissionRequests, 1);
    expect(on(tester, 'adhan-enabled'), isFalse);
    expect(find.text('لم يُمنح إذن الإشعارات، فبقي الأذان مطفأً.'), findsOneWidget);
    expect(adhan.applied.every((a) => a.events.isEmpty), isTrue);
  });

  testWidgets('غياب المنبّه الدقيق يُفعّل الأذان مع تنبيه للمستخدم', (tester) async {
    final adhan = FakeAdhanNotifier(
        permission: const AdhanPermissionResult(notifications: true, exactAlarms: false));
    await pumpApp(tester, adhan: adhan);
    await tapKey(tester, 'adhan-enabled');
    expect(on(tester, 'adhan-enabled'), isTrue);
    expect(find.textContaining('المنبهات والتذكيرات'), findsOneWidget);
  });

  testWidgets('إطفاء صلاة يحذفها من التنبيهات، والإطفاء العام يلغيها كلها', (tester) async {
    final adhan = FakeAdhanNotifier();
    await pumpApp(tester, adhan: adhan);
    await tapKey(tester, 'adhan-enabled');
    await tapKey(tester, 'adhan-dhuhr');
    expect(on(tester, 'adhan-dhuhr'), isFalse);
    expect(adhan.lastEvents.any((e) => e.prayer == PrayerName.dhuhr), isFalse);
    expect(adhan.lastEvents.any((e) => e.prayer == PrayerName.fajr), isTrue);
    // لا طلب أذونات ثانٍ لتغيير صلاة.
    expect(adhan.permissionRequests, 1);
    await tapKey(tester, 'adhan-enabled');
    expect(adhan.lastEvents, isEmpty);
    expect(find.byKey(const Key('adhan-fajr')), findsNothing);
  });

  testWidgets('اختيار الصوت يعيد الجدولة بالصوت الجديد، والتجربة تستعمله', (tester) async {
    final adhan = FakeAdhanNotifier();
    await pumpApp(tester, adhan: adhan);
    await tapKey(tester, 'adhan-enabled');
    expect(adhan.applied.last.sound, AdhanSound.full);
    await tapKey(tester, 'adhan-sound-takbeer');
    expect(adhan.applied.last.sound, AdhanSound.takbeer);
    await tapKey(tester, 'adhan-test');
    expect(adhan.tested, [AdhanSound.takbeer]);
    await tapKey(tester, 'adhan-sound-silent');
    expect(adhan.applied.last.sound, AdhanSound.silent);
  });

  testWidgets('آيفون: التكبيرتان أو الصمت فقط، مع شرح حد ٣٠ ثانية', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await pumpApp(tester, adhan: FakeAdhanNotifier());
      await tapKey(tester, 'adhan-enabled');
      expect(find.byKey(const Key('adhan-sound-full')), findsNothing);
      expect(find.byKey(const Key('adhan-sound-takbeer')), findsOneWidget);
      expect(find.byKey(const Key('adhan-sound-silent')), findsOneWidget);
      // الأذان الكامل المحفوظ يظهر تكبيرتين.
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('adhan-sound-takbeer'))).selected, isTrue);
      expect(find.textContaining('٣٠ ثانية'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('أندرويد: الشرح يذكر زر «إيقاف»', (tester) async {
    await pumpApp(tester, adhan: FakeAdhanNotifier());
    await tapKey(tester, 'adhan-enabled');
    expect(find.byKey(const Key('adhan-sound-full')), findsOneWidget);
    expect(find.textContaining('إيقاف'), findsWidgets);
  });

  testWidgets('الإعدادات المحفوظة تعيد الجدولة عند فتح التطبيق', (tester) async {
    final adhan = FakeAdhanNotifier();
    await pumpApp(tester, adhan: adhan);
    await tapKey(tester, 'adhan-enabled');
    final saved = (await SharedPreferences.getInstance()).getString('settings')!;
    expect((jsonDecode(saved) as Map)['adhan'], containsPair('enabled', true));
    // إعادة التشغيل بالإعدادات المحفوظة نفسها: تُزال الشجرة أولاً فلا تبقى حاوية Riverpod القديمة.
    await tester.pumpWidget(const SizedBox());
    final again = FakeAdhanNotifier();
    await pumpApp(tester, adhan: again, prefs: {'settings': saved});
    expect(again.applied, isNotEmpty);
    expect(again.lastEvents, hasLength(adhanMaxEvents));
    expect(find.byKey(const Key('adhan-fajr')), findsOneWidget);
  });

  group('أصول الصوت في المنصتين', () {
    test('أندرويد: الأذان والتكبيرتان في res/raw ومحميّان من مصغّر الموارد', () {
      expect(File('android/app/src/main/res/raw/adhan.mp3').lengthSync(), greaterThan(1000000));
      expect(File('android/app/src/main/res/raw/takbeer.mp3').lengthSync(), greaterThan(100000));
      final keep = File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
      expect(keep, contains('@raw/adhan'));
      expect(keep, contains('@raw/takbeer'));
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      for (final needle in [
        'ScheduledNotificationReceiver',
        'ScheduledNotificationBootReceiver',
        'ActionBroadcastReceiver',
        'SCHEDULE_EXACT_ALARM',
        'RECEIVE_BOOT_COMPLETED',
      ]) {
        expect(manifest, contains(needle), reason: needle);
      }
    });

    test('آيفون: التكبيرتان wav ضمن مشروع Xcode، وأقصر من ٣٠ ثانية', () {
      final wav = File('ios/Runner/takbeer.wav');
      expect(wav.existsSync(), isTrue);
      // wav: ‏١٦ بت أحادي ٤٤٫١ ك: ٨٨٢٠٠ بايت في الثانية. حد آبل لصوت الإشعار ٣٠ ثانية.
      final seconds = (wav.lengthSync() - 44) / 88200;
      expect(seconds, inInclusiveRange(5, 30));
      final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
      expect(project, contains('takbeer.wav in Resources'));
      expect(project, contains('path = takbeer.wav'));
      expect(iosTakbeerSound, 'takbeer.wav');
    });
  });
}

