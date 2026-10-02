import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'astronomy/heliacal.dart';
import 'domain/city.dart';
import 'domain/day_info.dart';
import 'domain/local_date.dart';
import 'domain/region.dart';
import 'domain/tables.dart';
import 'engine/calendar_engine.dart';
import 'engine/year_index.dart';
import 'formatting/digits.dart';
import 'hijri/umm_al_qura_calendar.dart';
import 'location/city_locator.dart';
import 'location/geolocator_location_service.dart';
import 'location/location_service.dart';
import 'notifications/local_notification_scheduler.dart';
import 'notifications/notification_content.dart';
import 'notifications/notification_planner.dart';
import 'notifications/notification_scheduler.dart';
import 'report/report_service.dart';
import 'repository/settings_repository.dart';
import 'repository/table_repository.dart';
import 'updates/bundle_verifier.dart';
import 'updates/data_updater.dart';
import 'updates/trusted_keys.dart';
import 'updates/update_config.dart';
import 'updates/update_fetcher.dart';
import 'updates/update_schedule.dart';
import 'updates/update_store.dart';

export 'report/report_service.dart' show isOpenableUrl;

/// كل مزوّدات Riverpod في مكان واحد (ARCHITECTURE §3).

/// يُستبدل في main() بنسخة محمّلة مسبقاً، وفي الاختبارات بنسخة وهمية.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider يجب استبداله في ProviderScope.',
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

/// يحمّل الجداول المضمّنة في التطبيق (الملاذ الأخير دائماً، §16.4)؛
/// يُستبدل في الاختبارات.
final embeddedTablesLoaderProvider = Provider<Future<Tables> Function()>(
  (ref) => TableRepository().load,
);

/// الجداول المستخدمة: حزمة التحديث المثبّتة إن اجتازت التحقق من جديد
/// (التوقيع والبصمة والمدقق، ورقمها أكبر من المضمّن)، وإلا المضمّنة (§16.4).
/// تُحمَّل مرة عند الفتح، وتُعاد بعد قبول حزمة (`invalidate`، §16.5). بلا
/// إعادة محاولة تلقائية؛ إعادة المحاولة بزر في الواجهة.
final tablesProvider = FutureProvider<Tables>((ref) async {
  final embedded = await ref.watch(embeddedTablesLoaderProvider)();
  final installed = await loadInstalledTables(
    embedded: embedded,
    store: ref.watch(updateStoreProvider),
    verifier: ref.watch(bundleVerifierProvider),
    appBuild: () => ref.read(appBuildProvider.future),
  );
  return installed ?? embedded;
}, retry: (_, _) => null);

/// تقويم أم القرى من الجداول المحمّلة (D22)، أو null قبل اكتمال التحميل.
/// يتبع tablesProvider، فيتحدث مع أي إعادة تحميل للجداول (§16.5).
final hijriCalendarProvider = Provider<UmmAlQuraCalendar?>(
  (ref) => ref.watch(tablesProvider).value?.hijri,
);

/// الإعدادات المحفوظة (ARCHITECTURE §12): المدينة، وانتهاء الإعداد الأولي،
/// ومفتاحا التنبيهات (الميزة 8)، والسمة والأرقام (DESIGN 8.7).
class Settings {
  const Settings({
    this.cityId,
    this.onboardingDone = false,
    this.notifyImportant = true,
    this.notifyDar = false,
    this.theme = ThemeChoice.system,
    this.digits = DigitStyle.arabicIndic,
  });

  final String? cityId;

  /// انتهى الإعداد الأولي (بعد شرح التنبيهات، DESIGN 8.2 د).
  final bool onboardingDone;

  /// «المواسم المهمة» (مفعّل افتراضياً) و«بداية كل دَرّ» (مطفأ افتراضياً).
  final bool notifyImportant;
  final bool notifyDar;

  final ThemeChoice theme;
  final DigitStyle digits;

  Settings copyWith({
    String? cityId,
    bool? onboardingDone,
    bool? notifyImportant,
    bool? notifyDar,
    ThemeChoice? theme,
    DigitStyle? digits,
  }) => Settings(
    cityId: cityId ?? this.cityId,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    notifyImportant: notifyImportant ?? this.notifyImportant,
    notifyDar: notifyDar ?? this.notifyDar,
    theme: theme ?? this.theme,
    digits: digits ?? this.digits,
  );
}

/// كل تغيير يُحفظ على الجهاز أولاً ثم تتغير الحالة، فيتحدث كل ما يعتمد عليها
/// فوراً. الحفظ الفاشل يرمي [SettingsSaveException] والحالة لا تتغير.
class SettingsController extends Notifier<Settings> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  Settings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return Settings(
      cityId: repo.cityId,
      onboardingDone: repo.onboardingDone,
      notifyImportant: repo.notifyImportant,
      notifyDar: repo.notifyDar,
      theme: repo.theme,
      digits: repo.digits,
    );
  }

  Future<void> selectCity(String cityId) async {
    await _repo.saveCityId(cityId);
    state = state.copyWith(cityId: cityId);
  }

  Future<void> completeOnboarding() async {
    await _repo.saveOnboardingDone();
    state = state.copyWith(onboardingDone: true);
  }

  Future<void> setNotifyImportant(bool on) async {
    await _repo.saveNotifyImportant(on);
    state = state.copyWith(notifyImportant: on);
  }

  Future<void> setNotifyDar(bool on) async {
    await _repo.saveNotifyDar(on);
    state = state.copyWith(notifyDar: on);
  }

  Future<void> setTheme(ThemeChoice theme) async {
    await _repo.saveTheme(theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> setDigits(DigitStyle digits) async {
    await _repo.saveDigits(digits);
    state = state.copyWith(digits: digits);
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

/// شكل الأرقام المختار (DESIGN 8.7).
final digitStyleProvider = Provider<DigitStyle>(
  (ref) => ref.watch(settingsProvider.select((s) => s.digits)),
);

/// المدينة المختارة، أو null إن لم تُختر بعد أو لم تعد في القائمة
/// أو لم تُحمَّل الجداول بعد.
final currentCityProvider = Provider<City?>((ref) {
  final id = ref.watch(settingsProvider.select((s) => s.cityId));
  final tables = ref.watch(tablesProvider).value;
  if (id == null || tables == null) return null;
  return tables.city(id);
});

/// منطقة المدينة المختارة.
final currentRegionProvider = Provider<Region?>((ref) {
  final city = ref.watch(currentCityProvider);
  final tables = ref.watch(tablesProvider).value;
  if (city == null || tables == null) return null;
  return tables.region(city.regionId);
});

/// محرك جدول منطقة المدينة المختارة (الميزة 1).
final engineProvider = Provider<CalendarEngine?>((ref) {
  final region = ref.watch(currentRegionProvider);
  final tables = ref.watch(tablesProvider).value;
  final table = region == null ? null : tables?.regionTables[region.id];
  if (region == null || table == null) return null;
  return CalendarEngine.fromTables(tables!, region.id);
});

/// نتيجة المحرك ليوم محلي في منطقة المدينة المختارة، أو null بلا مدينة.
/// المفتاح يُمرَّر **مقرّباً لمنتصف الليل** (`dateOnly`)، وإلا يُنشأ مدخل
/// جديد لكل لحظة (ARCHITECTURE §3)؛ يُفحص ذلك في وضع التطوير.
final dayInfoProvider = Provider.family<DayInfo?, DateTime>((ref, date) {
  assert(date == dateOnly(date), 'مفتاح dayInfoProvider غير مقرّب: $date');
  return ref.watch(engineProvider)?.resolve(date);
});

/// هل في البيانات المحمّلة سجل غير معتمد؟ (شريط «بيانات تجريبية»، DESIGN 5.7).
/// يُحسب مرة لكل تحميل للجداول.
final hasUnapprovedDataProvider = Provider<bool>(
  (ref) => ref.watch(tablesProvider).value?.hasUnapproved ?? false,
);

/// نتائج كل أيام سنة لمنطقة المدينة المختارة (تغذي حلقات الدائرة)، أو null.
final yearIndexProvider = Provider.family<YearIndex?, int>((ref, year) {
  final engine = ref.watch(engineProvider);
  return engine == null ? null : YearIndex(engine, year);
});

/// ساعة الجهاز؛ تُستبدل في الاختبارات بوقت ثابت.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// تاريخ اليوم المحلي مقرّباً لمنتصف الليل (الميزة 6). يتحدث عند منتصف
/// الليل بمؤقت، وعند عودة التطبيق للواجهة عبر [TodayController.refresh].
class TodayController extends Notifier<DateTime> {
  Timer? _midnight;

  @override
  DateTime build() {
    ref.onDispose(() => _midnight?.cancel());
    final now = ref.watch(clockProvider)();
    _scheduleMidnight(now);
    return dateOnly(now);
  }

  /// يعيد قراءة الساعة (عند عودة التطبيق للواجهة أو عند منتصف الليل).
  void refresh() {
    final now = ref.read(clockProvider)();
    final today = dateOnly(now);
    if (today != state) state = today;
    _scheduleMidnight(now);
  }

  void _scheduleMidnight(DateTime now) {
    _midnight?.cancel();
    final next = addDays(dateOnly(now), 1);
    _midnight = Timer(
      next.difference(now) + const Duration(seconds: 1),
      refresh,
    );
  }
}

final todayProvider = NotifierProvider<TodayController, DateTime>(
  TodayController.new,
);

/// التاريخ المعروض في الدائرة (مقرّب، ومحصور في 2025–2040). إن كان يعرض
/// اليوم ثم تغيّر اليوم (منتصف الليل أو العودة في يوم جديد) يتبعه؛ وإن كان
/// المستخدم يتصفح تاريخاً آخر لا يتغيّر عليه (DESIGN 8.4).
class SelectedDateController extends Notifier<DateTime> {
  @override
  DateTime build() {
    ref.listen<DateTime>(todayProvider, (previous, next) {
      if (previous != null && state == DateRange.clamp(previous)) {
        state = DateRange.clamp(next);
      }
    });
    return DateRange.clamp(ref.read(todayProvider));
  }

  void select(DateTime date) {
    final day = DateRange.clamp(date);
    if (day != state) state = day;
  }

  void shiftDays(int days) => select(addDays(state, days));

  void backToToday() => select(ref.read(todayProvider));
}

final selectedDateProvider = NotifierProvider<SelectedDateController, DateTime>(
  SelectedDateController.new,
);

/// قراءة الموقع (geolocator)؛ تُستبدل في الاختبارات بنسخة وهمية.
final locationServiceProvider = Provider<LocationService>(
  (ref) => const GeolocatorLocationService(),
);

/// أقرب مدينة بقراءة موقع واحدة (الميزة 4).
final cityLocatorProvider = Provider<CityLocator>(
  (ref) => CityLocator(ref.watch(locationServiceProvider)),
);

/// طلوع سهيل والثريا (الميزة 5) لمدينة وسنة، بإحداثيات المدينة في cities.json.
/// null إن لم تُحمَّل الجداول أو لم تكن المدينة في القائمة.
/// النتيجة مخزّنة لكل (مدينة، سنة)، وتُعاد مع أي إعادة تحميل للجداول
/// (قد تتغير الإحداثيات، §16.5). لا تغيّر جدول المنطقة (D10).
final heliacalProvider = Provider.family<HeliacalDates?, (String, int)>((
  ref,
  args,
) {
  final (cityId, year) = args;
  final city = ref.watch(tablesProvider).value?.city(cityId);
  if (city == null) return null;
  return const HeliacalCalculator().compute(
    lat: city.lat,
    lon: city.lon,
    year: year,
  );
});

/// طلوع سهيل والثريا للمدينة المختارة في [year]، أو null بلا مدينة.
final currentHeliacalProvider = Provider.family<HeliacalDates?, int>((
  ref,
  year,
) {
  final cityId = ref.watch(currentCityProvider.select((c) => c?.id));
  if (cityId == null) return null;
  return ref.watch(heliacalProvider((cityId, year)));
});

/// يفتح رابطاً عاماً في المتصفح (روابط صفحة المصادر، D27)؛ false إن فشل.
/// لا طلب شبكة من التطبيق نفسه. **يرفض أي رابط ليس https** (لا http ولا
/// مخططات أخرى) بلا محاولة فتح. يُستبدل في الاختبارات.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) async {
    if (!isOpenableUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  },
);

// ───────────────────────── البلاغ (الميزة 9) ─────────────────────────

/// إعدادات البلاغ من `--dart-define-from-file` (ARCHITECTURE §10)؛ تُستبدل
/// في الاختبارات.
final reportConfigProvider = Provider<ReportConfig>(
  (ref) => ReportConfig.fromEnvironment(),
);

/// ينسخ نصاً للحافظة؛ يُستبدل في الاختبارات.
final clipboardWriterProvider = Provider<TextCopier>(
  (ref) =>
      (text) => Clipboard.setData(ClipboardData(text: text)),
);

/// نموذج ← نسخ (ARCHITECTURE §10). يفتح الروابط عبر [urlOpenerProvider]
/// (https فقط).
final reportServiceProvider = Provider<ReportService>(
  (ref) => ReportService(
    config: ref.watch(reportConfigProvider),
    openUrl: ref.watch(urlOpenerProvider),
    copyText: ref.watch(clipboardWriterProvider),
  ),
);

/// نسخة التطبيق للبلاغ (`package_info_plus`)، مثل `1.0.0+1`؛ تُستبدل في
/// الاختبارات.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty
      ? info.version
      : '${info.version}+${info.buildNumber}';
}, retry: (_, _) => null);

// ───────────────────────── التنبيهات (الميزة 8) ─────────────────────────

/// المُجدوِل على الجهاز؛ يُستبدل في الاختبارات بنسخة وهمية.
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => LocalNotificationScheduler(),
);

/// هل إذن التنبيهات ممنوح؟ يُقرأ عند الفتح ويُحدَّث عند العودة للواجهة
/// (قد يغيّره المستخدم من إعدادات الجهاز) وبعد كل طلب.
class NotificationPermissionController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() =>
      ref.watch(notificationSchedulerProvider).isPermitted();

  /// يعيد القراءة بلا طلب.
  Future<void> refresh() async {
    final permitted = await AsyncValue.guard(
      () => ref.read(notificationSchedulerProvider).isPermitted(),
    );
    if (ref.mounted) state = permitted;
  }

  /// يطلب الإذن من النظام؛ النتيجة (false عند أي خطأ).
  Future<bool> request() async {
    bool granted;
    try {
      granted = await ref.read(notificationSchedulerProvider).requestPermission();
    } on Object {
      granted = false;
    }
    if (ref.mounted) state = AsyncData(granted);
    return granted;
  }
}

final notificationPermissionProvider =
    AsyncNotifierProvider<NotificationPermissionController, bool>(
      NotificationPermissionController.new,
      retry: (_, _) => null,
    );

/// ما تعتمد عليه خطة التنبيهات: تغيّر أيٍّ منه يعيد الجدولة (§9، §16.5).
/// ومنها «الأرقام» (DESIGN 8.7): تغييرها يعيد الجدولة بصمت.
typedef NotificationInputs = ({
  String? cityId,
  bool important,
  bool dar,
  DigitStyle digits,
  Tables? tables,
  DateTime today,
});

final notificationInputsProvider = Provider<NotificationInputs>((ref) {
  final s = ref.watch(settingsProvider);
  return (
    cityId: s.cityId,
    important: s.notifyImportant,
    dar: s.notifyDar,
    digits: s.digits,
    tables: ref.watch(tablesProvider).value,
    today: ref.watch(todayProvider),
  );
});

/// حالة آخر مزامنة للتنبيهات (لرسالة الخطأ في الإعدادات، DESIGN 8.7).
enum NotificationSyncStatus { idle, scheduled, failed }

/// يعيد جدولة التنبيهات (ARCHITECTURE §9، D13): عند فتح التطبيق، وعند تغيّر
/// المدينة أو المفتاحين أو الجداول (إعادة تحميلها بعد تحديث بيانات، §16.5)
/// أو اليوم، وعند العودة للواجهة ([sync]) فتُكتشف المنطقة الزمنية الجديدة.
/// كل جدولة = `cancelAll` ثم الخطة كاملة، فلا تكرار. إن لم يتغير شيء منذ
/// آخر جدولة ناجحة (الخطة والمنطقة الزمنية) لا يُعاد شيء.
class NotificationSyncController extends Notifier<NotificationSyncStatus> {
  String? _lastSignature;
  Future<void>? _running;
  bool _again = false;

  @override
  NotificationSyncStatus build() {
    ref.listen(notificationInputsProvider, (_, _) => sync());
    // منح الإذن (من الشرح أو الإعدادات أو إعدادات الجهاز) ← جدولة من جديد.
    ref.listen(notificationPermissionProvider, (previous, next) {
      if (next.value == true && previous?.value != true) {
        _lastSignature = null;
        sync();
      }
    });
    // أول قراءة (فتح التطبيق) بعد بناء المزوّد.
    Future.microtask(sync);
    return NotificationSyncStatus.idle;
  }

  /// يجدول إن تغيّرت الخطة أو المنطقة الزمنية. الطلبات المتزامنة تُدمج
  /// (جولة واحدة بعد الجارية).
  Future<void> sync() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _loop();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<void> _loop() async {
    do {
      _again = false;
      await _syncOnce();
    } while (_again && ref.mounted);
  }

  Future<void> _syncOnce() async {
    if (!ref.mounted) return;
    final tables = ref.read(tablesProvider).value;
    if (tables == null) return; // تُعاد عند اكتمال التحميل.
    final settings = ref.read(settingsProvider);
    final city = ref.read(currentCityProvider);
    final region = ref.read(currentRegionProvider);
    final engine = ref.read(engineProvider);
    final scheduler = ref.read(notificationSchedulerProvider);
    final now = ref.read(clockProvider)();
    try {
      final timezone = await scheduler.localTimezone();
      if (!ref.mounted) return;
      final notifications = <ScheduledNotification>[];
      if (city != null && region != null && engine != null) {
        final l10n = lookupAppLocalizations(const Locale('ar'));
        final plan = const NotificationPlanner().plan(
          now: now,
          engine: engine,
          items: tables.items,
          heliacal: (year) => _heliacal(city.id, year),
          important: settings.notifyImportant,
          dar: settings.notifyDar,
        );
        for (final p in plan) {
          notifications.add(
            buildScheduledNotification(
              p,
              l10n: l10n,
              tables: tables,
              city: city,
              region: region,
            ),
          );
        }
      }
      // «الأرقام» في البصمة: تغييرها يعيد الجدولة بصمت (DESIGN 8.7) حتى إن
      // لم يتغير نص، فكل نص فيه رقم يتبع الإعداد عند جدولته.
      final signature = [
        timezone,
        settings.digits.name,
        for (final n in notifications) n.fingerprint,
      ].join('\n');
      if (signature == _lastSignature) return;
      final l10n = lookupAppLocalizations(const Locale('ar'));
      await scheduler.replaceAll(
        notifications,
        now: now,
        timezone: timezone,
        channels: (
          important: l10n.notifChannelImportant,
          dar: l10n.notifChannelDar,
        ),
      );
      _lastSignature = signature;
      if (ref.mounted) state = NotificationSyncStatus.scheduled;
    } on Object {
      _lastSignature = null;
      if (!ref.mounted) return;
      // بلا إذن يرفض النظام (آيفون) إضافة التنبيهات: ليس فشلاً، والملاحظة
      // في الإعدادات هي «التنبيهات متوقفة»؛ تُعاد الجدولة عند منح الإذن.
      final permitted = await _isPermitted();
      if (ref.mounted) {
        state = permitted
            ? NotificationSyncStatus.failed
            : NotificationSyncStatus.idle;
      }
    }
  }

  Future<bool> _isPermitted() async {
    try {
      return await ref.read(notificationPermissionProvider.future);
    } on Object {
      return false;
    }
  }

  HeliacalDates? _heliacal(String cityId, int year) {
    try {
      return ref.read(heliacalProvider((cityId, year)));
    } on Object {
      return null; // خارج مدى الحساب ← تاريخ الجدول.
    }
  }
}

final notificationSyncProvider =
    NotifierProvider<NotificationSyncController, NotificationSyncStatus>(
      NotificationSyncController.new,
    );

// ─────────────────────── تحديث البيانات الموقّع (الميزة 11) ───────────────────────

/// `UPDATE_BASE_URL` من `--dart-define-from-file` (§16.1)؛ فارغ = لا تحديث.
final updateConfigProvider = Provider<UpdateConfig>(
  (ref) => UpdateConfig.fromEnvironment(),
);

/// المفاتيح العامة الموثوقة (§16.3)؛ فارغة حتى يولّد المالك مفتاح الإنتاج.
/// تُستبدل في الاختبارات بمفتاح مولّد أثناء التشغيل.
final trustedKeysProvider = Provider<Map<String, String>>(
  (ref) => trustedDataKeys,
);

final bundleVerifierProvider = Provider<BundleVerifier>(
  (ref) => BundleVerifier(ref.watch(trustedKeysProvider)),
);

/// مجلد دعم التطبيق (`path_provider`)؛ يُستبدل في الاختبارات بمجلد مؤقت.
final updateStoreProvider = Provider<UpdateStore>(
  (ref) => UpdateStore(getApplicationSupportDirectory),
);

/// طلب HTTPS لملف ثابت (`dart:io`)؛ يُستبدل في الاختبارات.
final updateFetcherProvider = Provider<UpdateFetcher>(
  (ref) => HttpUpdateFetcher(),
);

/// رقم بناء التطبيق (لـ `minAppBuild` في البيان)؛ يُستبدل في الاختبارات.
final appBuildProvider = FutureProvider<int>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return int.tryParse(info.buildNumber) ?? 0;
}, retry: (_, _) => null);

final dataUpdaterProvider = Provider<DataUpdater>(
  (ref) => DataUpdater(
    config: ref.watch(updateConfigProvider),
    verifier: ref.watch(bundleVerifierProvider),
    fetcher: ref.watch(updateFetcherProvider),
    store: ref.watch(updateStoreProvider),
    state: UpdateState(ref.watch(sharedPreferencesProvider)),
  ),
);

/// يتحقق من تحديث البيانات عند الفتح والعودة للواجهة إن حان الموعد (7 أيام
/// بعد نجاح، 24 ساعة بعد فشل؛ لا أثناء الإعداد الأولي)، بلا مهام خلفية ولا
/// رسالة للمستخدم (§16.2). بعد قبول حزمة: `invalidate(tablesProvider)` فتُعاد
/// الجداول والهجري وكل ما يتبعها، وتُعاد جدولة التنبيهات (§16.5).
/// الحالة = نتيجة آخر محاولة (null قبلها).
class DataUpdateController extends Notifier<UpdateOutcome?> {
  Future<UpdateOutcome>? _running;

  @override
  UpdateOutcome? build() => null;

  /// محاولة واحدة متزامنة كحد أقصى؛ لا ترمي.
  Future<UpdateOutcome> maybeCheck() {
    final running = _running;
    if (running != null) return running;
    final run = _maybeCheck();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<UpdateOutcome> _maybeCheck() async {
    final updater = ref.read(dataUpdaterProvider);
    if (!updater.isEnabled) return _finish(UpdateOutcome.disabled);
    final now = ref.read(clockProvider)();
    final due = isCheckDue(
      now: now,
      lastCheckOk: updater.state.lastCheckOk,
      lastAttempt: updater.state.lastAttempt,
      onboardingDone: ref.read(settingsProvider).onboardingDone,
    );
    if (!due) return _finish(UpdateOutcome.notDue);
    final Tables embedded;
    final int appBuild;
    try {
      embedded = await ref.read(embeddedTablesLoaderProvider)();
      appBuild = await ref.read(appBuildProvider.future);
    } on Object {
      return _finish(UpdateOutcome.failed);
    }
    if (!ref.mounted) return UpdateOutcome.failed;
    final outcome = await updater.check(
      embedded: embedded,
      appBuild: appBuild,
      now: now,
    );
    if (!ref.mounted) return outcome;
    if (outcome == UpdateOutcome.updated) ref.invalidate(tablesProvider);
    return _finish(outcome);
  }

  UpdateOutcome _finish(UpdateOutcome outcome) {
    if (ref.mounted) state = outcome;
    return outcome;
  }
}

final dataUpdateProvider = NotifierProvider<DataUpdateController, UpdateOutcome?>(
  DataUpdateController.new,
);
