import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_content.dart';
import 'notification_planner.dart';
import 'notification_scheduler.dart';

/// المُجدوِل الفعلي: flutter_local_notifications + timezone + flutter_timezone
/// (ARCHITECTURE §9، D13). لا يُختبر هنا (يحتاج جهازاً)؛ المنطق كله في
/// المخطِّط ومزامنة التنبيهات، وهما مختبران بمُجدوِل وهمي.
class LocalNotificationScheduler implements NotificationScheduler {
  LocalNotificationScheduler([
    FlutterLocalNotificationsPlugin? plugin,
    DateTime Function()? clock,
  ]) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _clock = clock ?? DateTime.now;

  final FlutterLocalNotificationsPlugin _plugin;

  /// ساعة لحظة الجدولة (لموعد التنبيه المتأخر)؛ تُستبدل في الاختبارات.
  final DateTime Function() _clock;
  Future<void>? _ready;

  /// أيقونة الإشعار الصغيرة: النجمة الرباعية أحادية اللون (DESIGN 8.9)،
  /// `android/app/src/main/res/drawable/ic_stat_durur.xml`.
  static const _androidIcon = 'ic_stat_durur';

  /// موعد التنبيه المتأخر الذي لم يصل بعد (انظر [replaceAll]).
  static const lateDelay = Duration(seconds: 10);

  @override
  Future<void> initialize({required void Function(String payload) onTap}) =>
      _ready ??= _init(onTap);

  Future<void> _init(void Function(String payload) onTap) async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_androidIcon),
        // لا يُطلب الإذن عند التهيئة؛ يُطلب في شرح التنبيهات أو عند تشغيل
        // مفتاح (DESIGN 8.2 د، 8.7).
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onTap(payload);
      },
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<String> localTimezone() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> isPermitted() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.areNotificationsEnabled() ?? false;
    }
    final options = await _ios?.checkPermissions();
    return options?.isEnabled ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // أندرويد 13+: POST_NOTIFICATIONS؛ وقبله مسموحة دائماً.
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<bool> openSystemSettings() async =>
      await _plugin.openAppNotificationSettings() ?? false;

  @override
  Future<void> replaceAll(
    List<ScheduledNotification> notifications, {
    required String timezone,
    required NotificationChannelNames channels,
    required DateTime now,
  }) async {
    await _ready;
    final location = _location(timezone);
    final stillPending = {
      for (final p in await _plugin.pendingNotificationRequests()) p.id,
    };
    // المعلّقة فقط: التنبيه المعروض في شريط الإشعارات يبقى حتى يضغطه
    // المستخدم (cancelAll يحذفه أيضاً).
    await _plugin.cancelAllPendingNotifications();
    for (final n in notifications) {
      final at = n.fireAt;
      final tz.TZDateTime when;
      if (!at.isAfter(now)) {
        // متأخر لم يصل بعد ← بعد لحظات؛ وصل ← لا يُعاد.
        if (!stillPending.contains(n.id)) continue;
        // من ساعة لحظة الجدولة لا من بداية المزامنة، فلا يكون الموعد ماضياً.
        when = tz.TZDateTime.from(_clock().add(lateDelay), tz.UTC);
      } else {
        when = location == null
            // منطقة غير معروفة لمكتبة timezone: اللحظة نفسها بتوقيت الجهاز.
            ? tz.TZDateTime.from(at, tz.UTC)
            : tz.TZDateTime(location, at.year, at.month, at.day, at.hour);
      }
      final (channelId, channelName) = switch (n.kind) {
        NotificationKind.important => ('important', channels.important),
        NotificationKind.dar => ('dar', channels.dar),
      };
      await _plugin.zonedSchedule(
        id: n.id,
        scheduledDate: when,
        title: n.title,
        body: n.body.isEmpty ? null : n.body,
        payload: n.payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            icon: _androidIcon,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // لا يحتاج إذن المنبهات الدقيقة SCHEDULE_EXACT_ALARM؛ قد يتأخر دقائق
        // ولا يهم لتنبيه موسمي (D13).
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static tz.Location? _location(String id) {
    try {
      final location = tz.getLocation(id);
      tz.setLocalLocation(location);
      return location;
    } on Object {
      return null;
    }
  }
}
