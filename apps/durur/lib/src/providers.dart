import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain/city.dart';
import 'domain/day_info.dart';
import 'domain/region.dart';
import 'domain/tables.dart';
import 'engine/calendar_engine.dart';
import 'hijri/umm_al_qura_calendar.dart';
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
  return CalendarEngine(region: region, table: table);
});

/// نتيجة المحرك ليوم محلي في منطقة المدينة المختارة، أو null بلا مدينة.
final dayInfoProvider = Provider.family<DayInfo?, DateTime>((ref, date) {
  return ref.watch(engineProvider)?.resolve(date);
});
