import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/app_harness.dart';

class _FailingSettingsRepository extends SettingsRepository {
  _FailingSettingsRepository(super.prefs);

  @override
  Future<void> saveCityId(String cityId) async =>
      throw const SettingsSaveException(SettingsRepository.cityIdKey);
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  Future<ProviderContainer> container(
    SharedPreferences prefs, [
    List<Override> extra = const [],
  ]) async {
    final c = ProviderContainer(overrides: appOverrides(prefs, tables, extra));
    addTearDown(c.dispose);
    // ينتظر تحميل الجداول (مثل فتح التطبيق).
    await c.read(tablesProvider.future);
    return c;
  }

  test('بلا مدينة محفوظة: لا مدينة ولا محرك ولا نتيجة', () async {
    final c = await container(await fakePrefs());
    expect(c.read(settingsProvider).cityId, isNull);
    expect(c.read(currentCityProvider), isNull);
    expect(c.read(currentRegionProvider), isNull);
    expect(c.read(engineProvider), isNull);
    expect(c.read(dayInfoProvider(DateTime(2026, 10, 2))), isNull);
  });

  test('معيار 3: المدينة تختار جدول منطقتها في المحرك', () async {
    final c = await container(await fakePrefs());
    final date = DateTime(2026, 10, 2);
    for (final (cityId, regionId) in [
      ('riyadh', 'najd'),
      ('kuwait_city', 'kuwait'),
      ('muscat', 'uae_oman'),
    ]) {
      await c.read(settingsProvider.notifier).selectCity(cityId);
      expect(c.read(currentCityProvider)?.id, cityId);
      expect(c.read(currentRegionProvider)?.id, regionId);
      final engine = c.read(engineProvider)!;
      expect(engine.region.id, regionId);
      expect(engine.table, same(tables.regionTables[regionId]));
      final info = c.read(dayInfoProvider(date))!;
      expect(info.regionId, regionId);
      // نفس نتيجة محرك الميزة 1 لتلك المنطقة.
      expect(info.dar.record, same(engine.resolve(date).dar.record));
    }
  });

  test('معيار 4: يُحفظ معرّف المدينة فقط، ويبقى بعد إعادة الفتح', () async {
    final prefs = await fakePrefs();
    final first = await container(prefs);
    await first.read(settingsProvider.notifier).selectCity('kuwait_city');

    expect(prefs.getKeys(), {SettingsRepository.cityIdKey});
    expect(prefs.getString(SettingsRepository.cityIdKey), 'kuwait_city');
    first.dispose();

    // «إعادة تشغيل»: حاوية جديدة تقرأ من نفس التخزين.
    final reopened = await container(await SharedPreferences.getInstance());
    expect(reopened.read(currentCityProvider)?.id, 'kuwait_city');
    expect(reopened.read(engineProvider)?.region.id, 'kuwait');
  });

  test('معيار 5: تغيير المدينة يحدّث المحرك والنتيجة فوراً للمستمعين', () async {
    final c = await container(
      await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'}),
    );
    final regions = <String?>[];
    c.listen(engineProvider, (_, next) => regions.add(next?.region.id),
        fireImmediately: true);
    // المستمعون يُبلَّغون في دورة الأحداث التالية (Riverpod 3).
    await c.read(settingsProvider.notifier).selectCity('muscat');
    await Future<void>.delayed(Duration.zero);
    await c.read(settingsProvider.notifier).selectCity('kuwait_city');
    await Future<void>.delayed(Duration.zero);
    expect(regions, ['najd', 'uae_oman', 'kuwait']);
  });

  test('معرّف محفوظ لم يعد في القائمة ← كأن لا مدينة', () async {
    final c = await container(
      await fakePrefs({SettingsRepository.cityIdKey: 'atlantis'}),
    );
    expect(c.read(currentCityProvider), isNull);
    expect(c.read(engineProvider), isNull);
  });

  test('فشل الحفظ: خطأ، والمدينة السابقة كما هي', () async {
    final prefs =
        await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'});
    final c = await container(prefs, [
      settingsRepositoryProvider
          .overrideWithValue(_FailingSettingsRepository(prefs)),
    ]);
    await expectLater(
      c.read(settingsProvider.notifier).selectCity('muscat'),
      throwsA(isA<SettingsSaveException>()),
    );
    expect(c.read(currentCityProvider)?.id, 'riyadh');
  });

  test('قبل تحميل الجداول: لا مدينة (بلا خطأ)', () async {
    final prefs = await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'});
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      tablesProvider.overrideWith((ref) => Future<Tables>.delayed(
            const Duration(milliseconds: 10),
            () => tables,
          )),
    ]);
    addTearDown(c.dispose);
    expect(c.read(currentCityProvider), isNull);
    await c.read(tablesProvider.future);
    expect(c.read(currentCityProvider)?.id, 'riyadh');
  });
}
