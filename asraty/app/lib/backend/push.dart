import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Pop-up notifications with sound, like a chat app.
///
/// - Background / closed app: the OS shows the FCM notification. On Android it
///   must use a high-importance channel to appear as a heads-up banner with
///   sound; the server targets [channelId] (functions/src/logic.ts PUSH_CHANNEL).
/// - App open: FCM shows nothing by default, so iOS is told to present the
///   banner + sound, and Android re-posts it through a local notification.
class Push {
  static const channelId = 'asraty_alerts';
  static final _local = FlutterLocalNotificationsPlugin();
  static var _ready = false;

  static const _channel = AndroidNotificationChannel(
    channelId,
    'تنبيهات أسرتي',
    description: 'المهام والموافقات والتنبيهات والمسابقات',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    _ready = true;
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null || defaultTargetPlatform != TargetPlatform.android) return; // iOS presents it itself
      _local.show(
        id: m.hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_notification',
            color: const Color(0xFF2F6158),
            styleInformation: BigTextStyleInformation(n.body ?? ''),
          ),
        ),
      );
    });
  }
}
