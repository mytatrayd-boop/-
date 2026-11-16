import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/app/adhan_alarms.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sa.lamha.lamha/adhan_alarm');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'available' || 'authorize' => true,
        'schedule' => (call.arguments['items'] as List).length,
        'cancelAll' => 2,
        'count' => 7,
        _ => null,
      };
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('القناة: الإتاحة والإذن والإلغاء', () async {
    final alarms = ChannelAdhanAlarms();
    expect(await alarms.available(), isTrue);
    expect(await alarms.authorize(), isTrue);
    expect(await alarms.cancelAll(), 2);
    expect(await alarms.count(), 7);
  });

  test('الجدولة ترسل الوقت بالثواني وعنوان كل منبّه وصوت الأذان الكامل', () async {
    final alarms = ChannelAdhanAlarms();
    final t = DateTime.utc(2026, 11, 16, 9, 30);
    final n = await alarms.schedule([(time: t, title: 'الظهر'), (time: t.add(const Duration(hours: 3)), title: 'العصر')]);
    expect(n, 2);
    final args = calls.single.arguments as Map;
    expect(args['sound'], 'adhan_full.mp3');
    expect(args['stop'], 'إيقاف');
    final items = args['items'] as List;
    expect(items.first, {'time': t.millisecondsSinceEpoch / 1000, 'title': 'الظهر'});
    expect(items.last['title'], 'العصر');
  });

  test('بلا منبّهات: لا شيء متاح (أندرويد)', () async {
    final noop = NoopAdhanAlarms();
    expect(await noop.available(), isFalse);
    expect(await noop.authorize(), isFalse);
    expect(await noop.schedule([]), 0);
    expect(await noop.cancelAll(), 0);
    expect(await noop.count(), 0);
  });

  test('ملفات آيفون: الأذان الكامل والجسر ضمن مشروع Xcode ومفتاح الإذن في Info.plist', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(project, contains('AdhanAlarmBridge.swift in Sources'));
    // معرّف المنبّه ثابت من وقته لا عشوائي (تكرار الأذان).
    final bridge = File('ios/Runner/AdhanAlarmBridge.swift').readAsStringSync();
    expect(bridge, contains('alarmId(seconds)'));
    expect(bridge, isNot(contains('id: UUID()')));
    expect(project, contains('adhan_full.mp3 in Resources'));
    expect(File('ios/Runner/adhan_full.mp3').existsSync(), isTrue);
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('NSAlarmKitUsageDescription'));
    expect(iosAlarmSound, 'adhan_full.mp3');
  });
}
