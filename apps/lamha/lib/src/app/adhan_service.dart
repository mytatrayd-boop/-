import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/adhan.dart';

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

  /// عدد التنبيهات المعلّقة فعلاً في النظام بعد آخر جدولة (لا ما طُلب)، أو null إن لم تُجدول بعد. يُعرض في
  /// الإعدادات ليتحقق المالك أن لا نسخ زائدة (تكرار الإشعار).
  Future<int?> pendingCount();
}

/// مفتاح آخر خطأ في shared_preferences.
const adhanErrorKey = 'adhanLastError';

/// مفاتيح الصوت في الأصول الأصلية: أندرويد `res/raw/adhan.mp3` و`takbeer.mp3`، وآيفون `Runner/takbeer.wav`
/// (آبل تقبل aiff وwav وcaf فقط، وبحد ٣٠ ثانية).
const androidAdhanSound = 'adhan';
const androidTakbeerSound = 'takbeer';
const iosTakbeerSound = 'takbeer.wav';

/// عدد التنبيهات المعلّقة فعلاً بعد آخر جدولة.
const adhanPendingKey = 'adhanPendingCount';

/// نسخة الجدولة: من خزّن أقل منها يُمسح كل ما علّقه التطبيق مرة واحدة عند أول فتح بعد التحديث ثم يُجدوَل من جديد
/// (إشعارات معلّقة من بناءات قديمة قد تتكرر مع الجديدة). ارفعها إن تغيّر نمط المعرّفات أو الجدولة.
const adhanSchedVersion = 2;
const adhanSchedVersionKey = 'adhanSchedVersion';

/// مفتاح في shared_preferences: هل جدوَل التطبيق تنبيهات من قبل (فلا نمسّ الإشعارات لمن لم يفعّل الأذان قط).
const adhanActiveKey = 'adhanActive';

class LocalAdhanNotifier implements AdhanNotifier {
  LocalAdhanNotifier(this._prefs);

  final SharedPreferences _prefs;
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
  }

  NotificationDetails _details(AdhanSound requested) {
    final sound = requested.forPlatform(ios: _ios);
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
        sound: silent ? null : iosTakbeerSound,
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

  /// الاستدعاءات تُنفَّذ واحداً بعد واحد: استدعاءان متداخلان (فتح التطبيق وتغيير موقع أو حفظ) كان يتشابك فيهما
  /// `cancelAll` مع `zonedSchedule`.
  Future<void> _chain = Future.value();

  @override
  Future<void> apply(List<AdhanEvent> events, AdhanSound sound, String city) {
    final run = _chain.then((_) => _apply(events, sound, city));
    _chain = run.catchError((Object _) {});
    return run;
  }

  @override
  Future<int?> pendingCount() async => _prefs.getInt(adhanPendingKey);

  Future<void> _schedule(List<AdhanEvent> events, NotificationDetails details, bool exact, String city) async {
    for (final e in events) {
      await _plugin.zonedSchedule(
        id: e.id,
        scheduledDate: e.time,
        notificationDetails: details,
        androidScheduleMode:
            exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        title: e.title,
        body: e.body(city),
      );
    }
  }

  /// المعلّق في النظام يساوي المطلوب تماماً وبلا معرّف مكرر.
  Future<bool> _pendingMatches(List<AdhanEvent> events) async {
    final pending = await _plugin.pendingNotificationRequests();
    final ids = {for (final p in pending) p.id};
    final want = {for (final e in events) e.id};
    await _prefs.setInt(adhanPendingKey, pending.length);
    return pending.length == events.length && ids.length == pending.length && ids.containsAll(want);
  }

  Future<void> _apply(List<AdhanEvent> events, AdhanSound sound, String city) async {
    try {
      final purge = (_prefs.getInt(adhanSchedVersionKey) ?? 0) < adhanSchedVersion;
      if (events.isEmpty && !(_prefs.getBool(adhanActiveKey) ?? false) && !purge) return;
      await _init();
      await _plugin.cancelAll();
      if (events.isEmpty) {
        await _prefs.setBool(adhanActiveKey, false);
        await _prefs.setInt(adhanPendingKey, 0);
        await _prefs.setInt(adhanSchedVersionKey, adhanSchedVersion);
        return;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final exact = _ios || (await android?.canScheduleExactNotifications() ?? false);
      final details = _details(sound);
      await _schedule(events, details, exact, city);
      if (!await _pendingMatches(events)) {
        // نسخ زائدة أو ناقصة: امسح كل شيء وأعد الجدولة مرة واحدة فقط.
        await _plugin.cancelAll();
        await _schedule(events, details, exact, city);
        if (!await _pendingMatches(events)) {
          final n = _prefs.getInt(adhanPendingKey) ?? -1;
          throw StateError('عدد التنبيهات المعلّقة $n بدل ${events.length}');
        }
      }
      await _prefs.setBool(adhanActiveKey, true);
      await _prefs.setInt(adhanSchedVersionKey, adhanSchedVersion);
      await _prefs.remove(adhanErrorKey);
    } catch (e) {
      // فشل الجدولة لا يوقف التطبيق، لكن يُحفظ ويُعرض في الإعدادات.
      await _fail('الجدولة', e);
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
      await _plugin.show(
        id: 1,
        title: 'تجربة الأذان',
        body: 'هكذا يصلك التنبيه عند دخول وقت الصلاة',
        notificationDetails: _details(sound),
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

  @override
  Future<int?> pendingCount() async => null;
}
