import 'notification_content.dart';

/// نصوص قناتي أندرويد (من ملف الترجمة).
typedef NotificationChannelNames = ({String important, String dar});

/// المُجدوِل على الجهاز (ARCHITECTURE §9). واجهة لتُستبدل في الاختبارات بنسخة
/// وهمية؛ التطبيق يستخدم [LocalNotificationScheduler] (flutter_local_notifications).
abstract interface class NotificationScheduler {
  /// يهيّئ البلجن **بلا طلب إذن**، ويسجّل [onTap] للضغط على تنبيه والتطبيق
  /// مفتوح أو في الخلفية.
  Future<void> initialize({required void Function(String payload) onTap});

  /// حمولة التنبيه الذي فتح التطبيق من حالة الإغلاق، أو null.
  Future<String?> launchPayload();

  /// معرّف المنطقة الزمنية للجهاز (IANA)، مثل `Asia/Riyadh`.
  Future<String> localTimezone();

  /// هل التنبيهات مسموحة للتطبيق الآن؟
  Future<bool> isPermitted();

  /// يطلب الإذن من النظام (أندرويد 13+ وآيفون)؛ النتيجة بعد رد المستخدم.
  Future<bool> requestPermission();

  /// يفتح إعدادات تنبيهات التطبيق في النظام؛ false إن تعذّر.
  Future<bool> openSystemSettings();

  /// يلغي كل التنبيهات **المعلّقة** (لا المعروضة في شريط الإشعارات) ثم يجدول [notifications] (عملية حتمية، فلا
  /// تكرار) بالمنطقة الزمنية [timezone].
  ///
  /// تنبيه فات وقته ([ScheduledNotification.fireAt] ≤ [now]، ضمن هامش الساعة
  /// في المخطِّط) يُعاد جدولته بعد لحظات **فقط إن كان ما يزال معلقاً لم
  /// يصل** (الجدولة غير الدقيقة قد تؤخره دقائق)؛ وإن وصل لا يُعاد، فلا يصل
  /// التنبيه نفسه مرتين (SPEC 8 معيار 7).
  Future<void> replaceAll(
    List<ScheduledNotification> notifications, {
    required String timezone,
    required NotificationChannelNames channels,
    required DateTime now,
  });
}
