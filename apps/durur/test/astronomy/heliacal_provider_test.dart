import 'package:durur/src/astronomy/heliacal.dart';
import 'package:durur/src/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  const calc = HeliacalCalculator();

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: appOverrides(await fakePrefs(), tables),
    );
    addTearDown(c.dispose);
    await c.read(tablesProvider.future);
    return c;
  }

  test('heliacalProvider: نفس نتيجة الحساب بإحداثيات المدينة', () async {
    final c = await container();
    final kuwait = tables.city('kuwait_city')!;
    final expected = calc.compute(lat: kuwait.lat, lon: kuwait.lon, year: 2026);
    final got = c.read(heliacalProvider(('kuwait_city', 2026)))!;
    expect(got.suhail, expected.suhail);
    expect(got.thurayya, expected.thurayya);
    // مخزّنة: القراءة الثانية تعيد الكائن نفسه.
    expect(c.read(heliacalProvider(('kuwait_city', 2026))), same(got));
  });

  test(
    'heliacalProvider: مدينة غير موجودة أو جداول غير محمّلة ← null',
    () async {
      final c = await container();
      expect(c.read(heliacalProvider(('nowhere', 2026))), isNull);

      final loading = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await fakePrefs()),
          tablesProvider.overrideWith((ref) => Future.any([])),
        ],
      );
      addTearDown(loading.dispose);
      expect(loading.read(heliacalProvider(('riyadh', 2026))), isNull);
    },
  );

  test('currentHeliacalProvider: يتبع المدينة المختارة والسنة', () async {
    final c = await container();
    expect(c.read(currentHeliacalProvider(2026)), isNull);

    await c.read(settingsProvider.notifier).selectCity('muscat');
    final muscat = c.read(currentHeliacalProvider(2026))!;
    expect(muscat.suhail, c.read(heliacalProvider(('muscat', 2026)))!.suhail);

    await c.read(settingsProvider.notifier).selectCity('kuwait_city');
    final kuwait = c.read(currentHeliacalProvider(2026))!;
    expect(kuwait.suhail!.isAfter(muscat.suhail!), isTrue);
    expect(c.read(currentHeliacalProvider(2027))!.suhail!.year, 2027);
  });

  test('D10: الحساب لا يغيّر نتيجة جدول المنطقة', () async {
    final c = await container();
    await c.read(settingsProvider.notifier).selectCity('kuwait_city');
    final date = DateTime(2026, 9, 1);
    final before = c.read(dayInfoProvider(date))!;
    c.read(currentHeliacalProvider(2026));
    final after = c.read(dayInfoProvider(date))!;
    expect(after, same(before));
  });
}
