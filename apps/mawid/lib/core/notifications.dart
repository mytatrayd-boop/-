import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'reminders.dart';
import 'settings.dart';

/// غلاف رفيع على المكتبة؛ المنطق في reminders.dart (مختبَر).
class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh')); // بدون توقيت صيفي
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<void> requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// يعيد جدولة كل شيء من الصفر حسب الإعدادات الحالية.
  Future<void> reschedule(AppState s, DateTime now) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!s.notificationsOn) return;
    final plan = planReminders(now, s.shown, d3: s.reminder('d3'), d1: s.reminder('d1'), d0: s.reminder('d0'));
    const details = NotificationDetails(
      android: AndroidNotificationDetails('mawid_payouts', 'مواعيد الصرف',
          channelDescription: 'تذكير بمواعيد الصرف', importance: Importance.high, priority: Priority.high),
      iOS: DarwinNotificationDetails(),
    );
    for (final r in plan) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime(tz.local, r.when.year, r.when.month, r.when.day, r.when.hour, r.when.minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
      );
    }
  }
}
