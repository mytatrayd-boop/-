import 'package:durur/src/notifications/notification_content.dart';
import 'package:durur/src/notifications/notification_scheduler.dart';

/// مُجدوِل وهمي يسجّل ما يُطلب منه (بلا بلجن)، مع حد آيفون 64 للتحقق.
class FakeNotificationScheduler implements NotificationScheduler {
  FakeNotificationScheduler({
    this.permitted = false,
    this.grantOnRequest = true,
    this.timezone = 'Asia/Riyadh',
    this.launch,
    this.failSchedule = false,
    this.failWithoutPermission = false,
  });

  /// يحاكي آيفون: إضافة تنبيه بلا إذن ترمي (UNErrorDomain 1).
  bool failWithoutPermission;
  DateTime? lastNow;

  bool permitted;
  bool grantOnRequest;
  String timezone;
  String? launch;
  bool failSchedule;

  void Function(String payload)? onTap;
  int initializeCalls = 0;
  int permissionRequests = 0;
  int settingsOpened = 0;
  int replaceCalls = 0;
  List<ScheduledNotification> pending = const [];
  String? scheduledTimezone;
  NotificationChannelNames? channels;

  @override
  Future<void> initialize({required void Function(String payload) onTap}) async {
    initializeCalls++;
    this.onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<String> localTimezone() async => timezone;

  @override
  Future<bool> isPermitted() async => permitted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permitted = grantOnRequest;
    return permitted;
  }

  @override
  Future<bool> openSystemSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<void> replaceAll(
    List<ScheduledNotification> notifications, {
    required String timezone,
    required NotificationChannelNames channels,
    required DateTime now,
  }) async {
    replaceCalls++;
    lastNow = now;
    if (failSchedule) throw StateError('فشل جدولة وهمي');
    if (failWithoutPermission && !permitted && notifications.isNotEmpty) {
      throw StateError('UNErrorDomain 1: Notifications are not allowed');
    }
    if (notifications.length > 64) throw StateError('تجاوز حد آيفون');
    // cancelAll ثم الجدولة: تبقى الخطة الجديدة وحدها.
    pending = List.unmodifiable(notifications);
    scheduledTimezone = timezone;
    this.channels = channels;
  }
}
