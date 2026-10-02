import 'package:durur/src/notifications/local_notification_scheduler.dart';
import 'package:durur/src/notifications/notification_content.dart';
import 'package:durur/src/notifications/notification_planner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// المُجدوِل الفعلي بلا جهاز: قناة البلجن محاكاة، والمنصة أندرويد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;
  late List<Map<String, Object?>> pending;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    pending = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'initialize' => true,
            'pendingNotificationRequests' => List.of(pending),
            // المسح يُفرغ المعلّقة كالجهاز: قراءتها بعده تعطي قائمة فارغة.
            'cancelAllPendingNotifications' => pending = [],
            'areNotificationsEnabled' => true,
            'requestNotificationsPermission' => false,
            'openAppNotificationSettings' => true,
            _ => null,
          };
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  ScheduledNotification note(int id, DateTime fireAt, NotificationKind kind) =>
      ScheduledNotification(
        id: id,
        fireAt: fireAt,
        kind: kind,
        title: 'عنوان $id',
        body: kind == NotificationKind.dar ? '' : 'نص',
        payload: '/item/wasm',
      );

  const channels = (important: 'المواسم المهمة', dar: 'بداية كل دَرّ');

  Future<LocalNotificationScheduler> ready({
    DateTime Function()? clock,
  }) async {
    final s = LocalNotificationScheduler(
      FlutterLocalNotificationsPlugin(),
      clock,
    );
    await s.initialize(onTap: (_) {});
    return s;
  }

  Map<Object?, Object?> args(MethodCall c) => c.arguments as Map;

  test('التهيئة بأيقونة النجمة، والمسح يسبق الجدولة', () async {
    final s = await ready();
    final init = calls.singleWhere((c) => c.method == 'initialize');
    expect(args(init)['defaultIcon'], 'ic_stat_durur');
    calls.clear();

    await s.replaceAll(
      [
        note(2030101900, DateTime(2030, 10, 19, 8), NotificationKind.important),
        note(2030102900, DateTime(2030, 10, 29, 8), NotificationKind.dar),
      ],
      timezone: 'Asia/Riyadh',
      channels: channels,
      now: DateTime(2030, 1, 1),
    );
    final methods = calls.map((c) => c.method).toList();
    // المعلّقة فقط تُمسح؛ المعروضة في شريط الإشعارات تبقى.
    expect(methods, isNot(contains('cancelAll')));
    final cancel = methods.indexOf('cancelAllPendingNotifications');
    expect(cancel, greaterThanOrEqualTo(0));
    expect(methods.indexOf('pendingNotificationRequests'), lessThan(cancel));
    final scheduled = [
      for (final (i, m) in methods.indexed)
        if (m == 'zonedSchedule') i,
    ];
    expect(scheduled, hasLength(2));
    expect(scheduled.every((i) => i > cancel), isTrue);
  });

  test('08:00 في Asia/Riyadh، الوضع غير الدقيق، القناة والأيقونة', () async {
    final s = await ready();
    calls.clear();
    await s.replaceAll(
      [
        note(2030101900, DateTime(2030, 10, 19, 8), NotificationKind.important),
        note(2030102900, DateTime(2030, 10, 29, 8), NotificationKind.dar),
      ],
      timezone: 'Asia/Riyadh',
      channels: channels,
      now: DateTime(2030, 1, 1),
    );
    final scheduled = calls.where((c) => c.method == 'zonedSchedule').toList();
    final first = args(scheduled[0]);
    expect(first['id'], 2030101900);
    expect(first['timeZoneName'], 'Asia/Riyadh');
    expect(first['scheduledDateTime'], '2030-10-19T08:00:00');
    expect(first['scheduledDateTimeISO8601'], '2030-10-19T08:00:00.000+0300');
    expect(first['payload'], '/item/wasm');
    final specifics = first['platformSpecifics'] as Map;
    expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
    expect(specifics['channelId'], 'important');
    expect(specifics['channelName'], 'المواسم المهمة');
    expect(specifics['icon'], 'ic_stat_durur');

    final dar = args(scheduled[1]);
    expect((dar['platformSpecifics'] as Map)['channelId'], 'dar');
    expect(dar['body'], isNull); // نص فارغ ← بلا نص
  });

  test('منطقة زمنية غير معروفة ← اللحظة نفسها بـ UTC', () async {
    final s = await ready();
    calls.clear();
    final at = DateTime(2030, 10, 19, 8);
    await s.replaceAll(
      [note(2030101900, at, NotificationKind.important)],
      timezone: 'Mars/Olympus_Mons',
      channels: channels,
      now: DateTime(2030, 1, 1),
    );
    final a = args(calls.singleWhere((c) => c.method == 'zonedSchedule'));
    expect(a['timeZoneName'], anyOf('UTC', 'Etc/UTC'));
    expect(
      DateTime.parse(a['scheduledDateTimeISO8601']! as String),
      at.toUtc(),
    );
  });

  test('تنبيه اليوم المتأخر: يُعاد بعد لحظات إن كان معلقاً، ولا يُعاد إن وصل',
      () async {
    // بداية المزامنة قبل دقيقتين، ولحظة الجدولة الآن (ساعة المُجدوِل).
    final syncStart = DateTime.now().subtract(const Duration(minutes: 2));
    final scheduleTime = DateTime.now().add(const Duration(hours: 1));
    final s = await ready(clock: () => scheduleTime);
    final late = note(1, syncStart.subtract(const Duration(minutes: 5)),
        NotificationKind.important);
    pending = [
      {'id': 1, 'title': 't', 'body': 'b', 'payload': '/item/wasm'},
    ];
    calls.clear();
    await s.replaceAll(
      [late],
      timezone: 'Asia/Riyadh',
      channels: channels,
      now: syncStart,
    );
    // قُرئت المعلّقة قبل أن يُفرغها المسح، فأُعيد التنبيه.
    expect(pending, isEmpty);
    final a = args(calls.singleWhere((c) => c.method == 'zonedSchedule'));
    final when = DateTime.parse(a['scheduledDateTimeISO8601']! as String);
    // الموعد من ساعة لحظة الجدولة لا من بداية المزامنة.
    expect(
      when
          .difference(scheduleTime.add(LocalNotificationScheduler.lateDelay))
          .inMilliseconds
          .abs(),
      lessThan(2),
    );

    // وصل (لم يعد معلّقاً) ← لا يُعاد.
    calls.clear();
    await s.replaceAll(
      [late],
      timezone: 'Asia/Riyadh',
      channels: channels,
      now: syncStart,
    );
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    expect(calls.where((c) => c.method == 'cancelAll'), isEmpty);
    expect(
      calls.where((c) => c.method == 'cancelAllPendingNotifications'),
      hasLength(1),
    );
  });

  test('الإذن والإعدادات عبر قناة أندرويد', () async {
    final s = await ready();
    expect(await s.isPermitted(), isTrue);
    expect(await s.requestPermission(), isFalse);
    expect(await s.openSystemSettings(), isTrue);
    expect(
      calls.map((c) => c.method),
      containsAll([
        'areNotificationsEnabled',
        'requestNotificationsPermission',
        'openAppNotificationSettings',
      ]),
    );
  });
}
