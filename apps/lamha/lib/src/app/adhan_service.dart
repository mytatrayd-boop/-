import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/adhan.dart';
import 'adhan_alarms.dart';
import 'adhan_player.dart';

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

  /// عدد التنبيهات المجدولة فعلاً في النظام بعد آخر جدولة (منبّهات أو إشعارات)، أو null إن لم تُجدول بعد. يُعرض
  /// في الإعدادات ليتحقق المالك أن لا نسخ زائدة (تكرار الأذان).
  Future<int?> pendingCount();
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

/// عدد التنبيهات المجدولة فعلاً بعد آخر جدولة.
const adhanPendingKey = 'adhanPendingCount';

/// نسخة الجدولة: من خزّن أقل منها يُمسح كل ما علّقه التطبيق مرة واحدة عند أول فتح بعد التحديث ثم يُجدوَل من جديد
/// (منبّهات وإشعارات معلّقة من بناءات قديمة قد تتكرر مع الجديدة). ارفعها إن تغيّر نمط المعرّفات.
const adhanSchedVersion = 2;
const adhanSchedVersionKey = 'adhanSchedVersion';

/// هل يُستعمل منبّه AlarmKit للأذان الكامل في آيفون ٢٦+؟ **معطّل** بقرار المالك (١٧ نوفمبر، DECISIONS ٤٢): AlarmKit
/// يرنّ ويهتزّ ويكرّر الصوت حتى «إيقاف» ولا خيار رسمياً لإيقافه تلقائياً أو لإلغاء الاهتزاز. يعمل بدله إشعار المقطع
/// القصير مع المشغّل الخلفي (الأذان كاملاً مرة واحدة بلا اهتزاز المنبّه). الكود باقٍ للعودة إليه إن تغيّر الأمر.
const adhanAlarmKitEnabled = false;

/// منبّه تجربة الأذان في آيفون ٢٦+ يرنّ بعد هذه المدة من الضغط (ليتسنى قفل الجوال)، وتبقى دالة التجربة معلّقة حتى
/// وقته فيبقى زر التجربة معطّلاً والنص الأحمر والساعة الرملية ظاهرين حتى يرنّ (ملاحظة المالك ١٦/١١/٢٠٢٦).
const adhanTestAlarmDelay = Duration(seconds: 10);

/// مفتاح في shared_preferences: هل جدوَل التطبيق تنبيهات من قبل (فلا نمسّ الإشعارات لمن لم يفعّل الأذان قط).
const adhanActiveKey = 'adhanActive';

class LocalAdhanNotifier implements AdhanNotifier {
  LocalAdhanNotifier(this._prefs, {this.onPlayFull, this.keeper, AdhanAlarms? alarms})
      : _alarms = alarms ?? NoopAdhanAlarms();

  /// آيفون ٢٦+: منبّه نظام (AlarmKit) يرنّ بالأذان كاملاً في وقته حتى بعد سحب التطبيق (DECISIONS ٣٨).
  final AdhanAlarms _alarms;

  /// آيفون: المشغّل الذي يبقى حياً في الخلفية ويشغّل الأذان الكامل تلقائياً في وقته (DECISIONS ٣٨).
  final AdhanPlayer? keeper;

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

  /// الاستدعاءات تُنفَّذ واحداً بعد واحد: استدعاءان متداخلان (فتح التطبيق وتغيير موقع أو حفظ) كانا يجدولان كل منهما
  /// المنبّهات والإشعارات فيتكرر الأذان.
  Future<void> _chain = Future.value();

  @override
  Future<void> apply(List<AdhanEvent> events, AdhanSound sound, String city) {
    final run = _chain.then((_) => _apply(events, sound, city));
    _chain = run.catchError((Object _) {});
    return run;
  }

  @override
  Future<int?> pendingCount() async => _prefs.getInt(adhanPendingKey);

  Future<void> _schedule(List<AdhanEvent> events, NotificationDetails details, bool exact, String city, AdhanSound sound) async {
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
      if (_ios) await _cancelAlarms();
      if (events.isEmpty) {
        await keeper?.disarm();
        await _prefs.setBool(adhanActiveKey, false);
        await _prefs.setInt(adhanPendingKey, 0);
        await _prefs.setInt(adhanSchedVersionKey, adhanSchedVersion);
        return;
      }
      // آيفون ٢٦+ والأذان الكامل: منبّه النظام يرنّ في وقته بلا تطبيق شغّال، فلا إشعار ولا صوت خلفي. وإلا (أقدم أو
      // رُفض الإذن أو فشل) يُجدول إشعار المقطع القصير مع المشغّل الخلفي أدناه.
      if (_ios && adhanAlarmKitEnabled && sound == AdhanSound.full && await _scheduleAlarms([
        for (final e in events.take(adhanAlarmLimit)) (time: e.time, title: e.title),
      ], verify: true)) {
        await keeper?.disarm();
        await _prefs.setBool(adhanActiveKey, true);
        await _prefs.setInt(adhanSchedVersionKey, adhanSchedVersion);
        await _prefs.remove(adhanErrorKey);
        return;
      }
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final exact = _ios || (await android?.canScheduleExactNotifications() ?? false);
      final details = _details(sound);
      await _schedule(events, details, exact, city, sound);
      if (!await _pendingMatches(events)) {
        // نسخ زائدة أو ناقصة: امسح كل شيء وأعد الجدولة مرة واحدة فقط.
        await _plugin.cancelAll();
        await _schedule(events, details, exact, city, sound);
        if (!await _pendingMatches(events)) {
          final n = _prefs.getInt(adhanPendingKey) ?? -1;
          throw StateError('عدد التنبيهات المعلّقة $n بدل ${events.length}');
        }
      }
      // آيفون والأذان الكامل: التطبيق يبقى حياً بصوت صامت ويشغّل الأذان كاملاً في وقته، ويلغي إشعار الحدث قبله
      // بنحو ٢٠ ثانية فلا يتداخلان. إن أُغلق التطبيق بالسحب بقي إشعار المقطع القصير احتياطاً.
      if (_ios && sound == AdhanSound.full) {
        await keeper?.arm(events, onPrepare: (e) => _plugin.cancel(id: e.id));
      } else {
        await keeper?.disarm();
      }
      await _prefs.setBool(adhanActiveKey, true);
      await _prefs.setInt(adhanSchedVersionKey, adhanSchedVersion);
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

  /// يجدول [items] منبّهات AlarmKit؛ true إن جُدول شيء، false لتعذّره (فيرجع الاستدعاء إلى الإشعار). مع [verify]
  /// يقارن عدد المنبّهات الفعلي في النظام بما جُدول، فإن زاد (نسخ مكررة) يمسح الكل ويعيد مرة واحدة. لا يُستعمل
  /// مع منبّه التجربة (فالعدد حينئذ يشمل المنبّهات الحقيقية).
  Future<bool> _scheduleAlarms(List<({DateTime time, String title})> items, {bool verify = false}) async {
    try {
      if (!await _alarms.available() || !await _alarms.authorize()) return false;
      var n = await _alarms.schedule(items);
      if (verify && n > 0) {
        var actual = await _alarms.count();
        if (actual != n) {
          await _alarms.cancelAll();
          n = await _alarms.schedule(items);
          actual = await _alarms.count();
          if (actual != n) await _fail('منبّه الأذان', 'عدد المنبّهات $actual بدل $n');
        }
        await _prefs.setInt(adhanPendingKey, actual);
      }
      return n > 0;
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
      // آيفون ٢٦+: تجربة المنبّه الكامل بعد ١٠ ثوانٍ (يمكنك إغلاق التطبيق لتسمع أنه يرنّ).
      if (_ios && adhanAlarmKitEnabled && sound == AdhanSound.full && await _scheduleAlarms([
        (time: DateTime.now().add(adhanTestAlarmDelay), title: 'تجربة الأذان'),
      ])) {
        await _prefs.remove(adhanErrorKey);
        // نبقى معلّقين حتى يرنّ المنبّه: الزر معطّل والتنبيه الأحمر والساعة الرملية ظاهران طوال الانتظار.
        await Future<void>.delayed(adhanTestAlarmDelay);
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

  @override
  Future<int?> pendingCount() async => null;
}
