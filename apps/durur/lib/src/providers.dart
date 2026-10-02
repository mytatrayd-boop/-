import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'astronomy/heliacal.dart';
import 'domain/city.dart';
import 'domain/day_info.dart';
import 'domain/local_date.dart';
import 'domain/region.dart';
import 'domain/tables.dart';
import 'engine/calendar_engine.dart';
import 'engine/year_index.dart';
import 'hijri/umm_al_qura_calendar.dart';
import 'location/city_locator.dart';
import 'location/geolocator_location_service.dart';
import 'location/location_service.dart';
import 'repository/settings_repository.dart';
import 'repository/table_repository.dart';

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

/// كل الجداول المضمّنة، تُحمَّل مرة واحدة. بلا إعادة محاولة تلقائية:
/// الأصول المضمّنة لا تتغير، وإعادة المحاولة بزر في الواجهة.
final tablesProvider = FutureProvider<Tables>(
  (ref) => TableRepository().load(),
  retry: (_, _) => null,
);

/// تقويم أم القرى من الجداول المحمّلة (D22)، أو null قبل اكتمال التحميل.
/// يتبع tablesProvider، فيتحدث مع أي إعادة تحميل للجداول (§16.5).
final hijriCalendarProvider = Provider<UmmAlQuraCalendar?>(
  (ref) => ref.watch(tablesProvider).value?.hijri,
);

/// الإعدادات المحفوظة. حالياً المدينة فقط؛ تُضاف مفاتيح التنبيهات
/// وانتهاء الإعداد الأولي مع ميزاتها.
class Settings {
  const Settings({this.cityId});

  final String? cityId;
}

class SettingsController extends Notifier<Settings> {
  @override
  Settings build() =>
      Settings(cityId: ref.watch(settingsRepositoryProvider).cityId);

  /// يحفظ المدينة على الجهاز ثم يحدّث الحالة، فيتحدث كل ما يعتمد عليها فوراً.
  /// يرمي [SettingsSaveException] إن فشل الحفظ، والحالة لا تتغير.
  Future<void> selectCity(String cityId) async {
    await ref.read(settingsRepositoryProvider).saveCityId(cityId);
    state = Settings(cityId: cityId);
  }
}

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
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
/// لا طلب شبكة من التطبيق نفسه. يُستبدل في الاختبارات.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
);
