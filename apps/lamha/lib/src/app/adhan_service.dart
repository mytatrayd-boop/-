import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/adhan.dart';
import 'adhan_alarms.dart';

/// جدولة الأذان بالإشعارات المحلية (flutter_local_notifications، DECISIONS ٢٨) خلف واجهة قابلة للاستبدال
/// في الاختبارات.

/// نتيجة طلب الأذونات.
class AdhanPermissionResult {
  const AdhanPermissionResult({required this.notifications, required this.exactAlarms});

  /// إذن عرض الإشعارات (أندرويد ١٣+ وآيفون).
  final bool notifications;

  /// أندرويد ١٢+: إذن المنبّه الدقيق. بدونه يقع التنبيه قرب الموعد (قد يتأخر دقائق) لا فيه بالضبط.
  final bool exactAlarms;
}

abstract class AdhanNotifier {
  /// يستبدل كل التنبيهات المجدولة بـ[events] (فارغة = يلغيها كلها) بصوت [sound] لمدينة [city].
  Future<void> apply(List<AdhanEvent> events, AdhanSound sound, String city);

  /// يطلب الأذونات (عند تفعيل المستخدم للأذان).
  Future<AdhanPermissionResult> requestPermissions();

  /// تنبيه فوري بالصوت المختار لتجربته.
  Future<void> test(AdhanSound sound);

  /// آخر خطأ في الجدولة أو التجربة (يُعرض في الإعدادات فلا يبقى الفشل صامتاً)، أو null إن نجح آخر ما جُرّب.
  Future<String?> lastError();
}

/// مفتاح آخر خطأ في shared_preferences.
const adhanErrorKey = 'adhanLastError';

/// مفاتيح الصوت في الأصول الأصلية: أندرويد `res/raw/adhan.mp3` و`takbeer.mp3`، وآيفون `Runner/takbeer.wav`
/// و`adhan30.wav` (آبل تقبل aiff وwav وcaf فقط، وبحد ٣٠ ثانية).
const androidAdhanSound = 'adhan';
const androidTakbeerSound = 'takbeer';
const iosTakbeerSound = 'takbeer.wav';

/// آيفون، «الأذان»: أول ٢٨٫٥ ثانية من الأذان في الإشعار (حد آبل ٣٠)، ثم يكمل التطبيق الأذان كاملاً عند الضغط.
const iosAdhanClipSound = 'adhan30.wav';

/// حمولة إشعار الأذان في آيفون: تضغط عليها فيُشغَّل الأذان الكامل داخل التطبيق.
const adhanFullPayload = 'adhan_full';

/// مفتاح في shared_preferences: هل جدوَل التطبيق تنبيهات من قبل (فلا نمسّ الإشعارات لمن لم يفعّل الأذان قط).
const adhanActiveKey = 'adhanActive';

class LocalAdhanNotifier implements AdhanNotifier {
  LocalAdhanNotifier(this._prefs, {this.onPlayFull, AdhanAlarms? alarms}) : _alarms = alarms ?? NoopAdhanAlarms();

  final AdhanAlarms _alarms;

  final SharedPreferences _prefs;

  /// يُستدعى عند ضغط إشعار الأذان في آيفون (أو فتح التطبيق منه): يشغّل الأذان الكامل.
  final void Function()? onPlayFull;
  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _fail(String where, Object e) async {
    debugPrint('adhan $where: $e');
    final msg = '$where: ${e.toString().split('\n').first}';
    await _prefs.setString(adhanErrorKey, msg.length > 200 ? msg.substring(0, 200) : msg);
  }

  @override
  Future<String?> lastError() async => _prefs.getString(adhanErrorKey);

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      onDidReceiveNotificationResponse: (r) {
        if (r.payload == adhanFullPayload) onPlayFull?.call();
      },
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // الأذونات تُطلب عند تفعيل المستخدم، لا عند الفتح.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
    // فُتح التطبيق من إشعار الأذان وهو مغلق: يكمل الأذان كاملاً.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if ((launch?.didNotificationLaunchApp ?? false) && launch?.notificationResponse?.payload == adhanFullPayload) {
        onPlayFull?.call();
      }
    } catch (e) {
      debugPrint('adhan launch details: $e');
    }
  }

  /// حمولة الإشعار: آيفون والأذان فقط (ليكمل التطبيق الأذان عند الضغط).
  String? _payload(AdhanSound requested) => _ios && requested == AdhanSound.full ? adhanFullPayload : null;

  NotificationDetails _details(AdhanSound requested) {
    final sound = requested;
    final silent = sound == AdhanSound.silent;
    final raw = sound == AdhanSound.full ? androidAdhanSound : androidTakbeerSound;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        // قناة لكل صوت: صوت القناة لا يتغير بعد إنشائها.
        'adhan_${sound.name}',
        switch (sound) {
          AdhanSound.full => 'الأذان',
          AdhanSound.takbeer => 'التكبير',
          AdhanSound.silent => 'تنبيه الصلاة (بلا صوت)',
        },
        channelDescription: 'تنبيه عند دخول وقت الصلاة',
        importance: Importance.max,
        priority: Priority.high,
        playSound: !silent,
        sound: silent ? null : RawResourceAndroidNotificationSound(raw),
        // زر «إيقاف» يلغي الإشعار فيتوقف صوته (النظام يوقف صوت الإشعار عند إلغائه).
        actions: silent
            ? null
            : const [AndroidNotificationAction('stop', 'إيقاف', cancelNotification: true)],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: !silent,
        sound: silent ? null : (sound == AdhanSound.full ? iosAdhanClipSound : iosTakbeerSound),
      ),
    );
  }

  @override
  Future<AdhanPermissionResult> requestPermissions() async {
    try {
      await _init();
      if (_ios) {
        final ok = await _plugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, sound: true);
        return AdhanPermissionResult(notifications: ok ?? false, exactAlarms: true);
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notifications = await android?.requestNotificationsPermission() ?? false;
      var exact = await android?.canScheduleExactNotifications() ?? false;
      if (!exact) {
        // يفتح إعداد «المنبهات والتذكيرات» للتطبيق؛ إن رفضه المستخدم نكتفي بالتقريبي.
        exact = await android?.requestExactAlarmsPermission() ?? false;
      }
      return AdhanPermissionResult(notifications: notifications, exactAlarms: exact);
    } catch (e) {
      await _fail('الأذونات', e);
      return const AdhanPermissionResult(notifications: false, exactAlarms: false);
    }
  }

  @override
  Future<void> apply(List<AdhanEvent> events, AdhanSound sound, String city) async {
    try {
      if (events.isEmpty && !(_prefs.getBool(adhanActiveKey) ?? false)) return;
      await _init();
      await _plugin.cancelAll();
      if (_ios) await _cancelAlarms();
      if (events.isEmpty) {
        await _prefs.setBool(adhanActiveKey, false);
        return;
      }
      // آيفون ٢٦+: الأذان الكامل منبّه نظام يرنّ كاملاً حتى مع إغلاق التطبيق؛ وإلا (أقدم، أو رُفض الإذن، أو فشل)
      // يبقى إشعار المقطع القصير الذي يكمله التطبيق عند الضغط.
      if (_ios && sound == AdhanSound.full && await _scheduleAlarms([
        for (final e in events.take(adhanAlarmLimit)) (time: e.time, title: e.title),
      ])) {
        await _prefs.setBool(adhanActiveKey, true);
        await _prefs.remove(adhanErrorKey);
        return;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final exact = _ios || (await android?.canScheduleExactNotifications() ?? false);
      final details = _details(sound);
      for (final e in events) {
        await _plugin.zonedSchedule(
          id: e.id,
          scheduledDate: e.time,
          notificationDetails: details,
          androidScheduleMode:
              exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          title: e.title,
          body: e.body(city),
          payload: _payload(sound),
        );
      }
      await _prefs.setBool(adhanActiveKey, true);
      await _prefs.remove(adhanErrorKey);
    } catch (e) {
      // فشل الجدولة لا يوقف التطبيق، لكن يُحفظ ويُعرض في الإعدادات.
      await _fail('الجدولة', e);
    }
  }

  /// يلغي منبّهات الأذان (آيفون)؛ الخطأ لا يوقف شيئاً.
  Future<void> _cancelAlarms() async {
    try {
      await _alarms.cancelAll();
    } catch (e) {
      debugPrint('adhan alarms cancel: $e');
    }
  }

  /// يجدول [items] منبّهات AlarmKit؛ true إن جُدول شيء، false لتعذّره (فيرجع الاستدعاء إلى الإشعار).
  Future<bool> _scheduleAlarms(List<({DateTime time, String title})> items) async {
    try {
      if (!await _alarms.available() || !await _alarms.authorize()) return false;
      return await _alarms.schedule(items) > 0;
    } catch (e) {
      await _fail('منبّه الأذان', e);
      return false;
    }
  }

  /// هل الإشعارات مسموحة؟ يطلب الإذن إن لم يكن ممنوحاً (النظام يتجاهل الطلب إن رُفض نهائياً).
  Future<bool> _notificationsAllowed() async {
    if (_ios) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final current = await ios?.checkPermissions();
      if (current?.isEnabled ?? false) return true;
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (await android?.areNotificationsEnabled() ?? true) return true;
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> test(AdhanSound sound) async {
    try {
      await _init();
      // بلا إذن الإشعارات يهمل النظام الإشعار بصمت (أندرويد ١٣+ وآيفون)، فيبدو الزر «لا يستجيب». الإذن
      // كان يُطلب فقط عند تحويل مفتاح الأذان من مطفأ إلى مفعّل، فنتحقق منه ونطلبه هنا ونعرض السبب إن رُفض.
      if (!await _notificationsAllowed()) {
        await _fail('التجربة', 'الإشعارات مغلقة للتطبيق، فعّلها من إعدادات الجهاز ثم أعد التجربة');
        return;
      }
      // آيفون ٢٦+: تجربة المنبّه الكامل بعد ١٠ ثوانٍ (يمكنك إغلاق التطبيق لتجربة أنه يرنّ).
      if (_ios && sound == AdhanSound.full && await _scheduleAlarms([
        (time: DateTime.now().add(const Duration(seconds: 10)), title: 'تجربة الأذان'),
      ])) {
        await _prefs.remove(adhanErrorKey);
        return;
      }
      await _plugin.show(
        id: 1,
        title: 'تجربة الأذان',
        body: 'هكذا يصلك التنبيه عند دخول وقت الصلاة',
        notificationDetails: _details(sound),
        payload: _payload(sound),
      );
      await _prefs.remove(adhanErrorKey);
    } catch (e) {
      await _fail('التجربة', e);
    }
  }
}

/// لا يفعل شيئاً (الاختبارات والمنصات بلا إشعارات).
class NoopAdhanNotifier implements AdhanNotifier {
  @override
  Future<void> apply(List<AdhanEvent> events, AdhanSound sound, String city) async {}

  @override
  Future<AdhanPermissionResult> requestPermissions() async =>
      const AdhanPermissionResult(notifications: true, exactAlarms: true);

  @override
  Future<void> test(AdhanSound sound) async {}

  @override
  Future<String?> lastError() async => null;
}
