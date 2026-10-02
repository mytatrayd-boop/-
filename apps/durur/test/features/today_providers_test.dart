import 'package:durur/src/domain/local_date.dart';
import 'package:durur/src/providers.dart';
import 'package:durur/src/repository/settings_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// مزوّدات الميزة 6: اليوم، والتاريخ المعروض، وفهرس السنة، وشريط المسودة.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  Future<(ProviderContainer, void Function(DateTime))> container(
    DateTime start,
  ) async {
    var now = start;
    final c = ProviderContainer(
      overrides: appOverrides(
        await fakePrefs({SettingsRepository.cityIdKey: 'riyadh'}),
        tables,
        [clockProvider.overrideWithValue(() => now)],
      ),
    );
    addTearDown(c.dispose);
    await c.read(tablesProvider.future);
    return (c, (DateTime t) => now = t);
  }

  test('اليوم مقرّب لمنتصف الليل، والمعروض يبدأ به', () async {
    final (c, _) = await container(DateTime(2026, 10, 2, 15, 45, 12));
    expect(c.read(todayProvider), DateTime(2026, 10, 2));
    expect(c.read(selectedDateProvider), DateTime(2026, 10, 2));
  });

  test('منتصف الليل/العودة للتطبيق: المعروض يتبع اليوم إن كان يعرضه', () async {
    final (c, setNow) = await container(DateTime(2026, 10, 2, 23, 59));
    c.listen(selectedDateProvider, (_, _) {});
    setNow(DateTime(2026, 10, 3, 0, 0, 5));
    c.read(todayProvider.notifier).refresh();
    expect(c.read(todayProvider), DateTime(2026, 10, 3));
    expect(c.read(selectedDateProvider), DateTime(2026, 10, 3));
  });

  test('من يتصفح تاريخاً آخر لا يتغيّر عليه مع اليوم الجديد', () async {
    final (c, setNow) = await container(DateTime(2026, 10, 2, 10));
    c.read(selectedDateProvider.notifier).select(DateTime(2027, 1, 15, 8));
    setNow(DateTime(2026, 10, 3, 1));
    c.read(todayProvider.notifier).refresh();
    expect(c.read(selectedDateProvider), DateTime(2027, 1, 15));
    c.read(selectedDateProvider.notifier).backToToday();
    expect(c.read(selectedDateProvider), DateTime(2026, 10, 3));
  });

  test('التنقل بالأيام عبر نهاية السنة، والحصر في 2025–2040', () async {
    final (c, _) = await container(DateTime(2026, 12, 31, 12));
    final sel = c.read(selectedDateProvider.notifier);
    sel.shiftDays(1);
    expect(c.read(selectedDateProvider), DateTime(2027, 1, 1));
    sel.select(DateTime(2050, 6, 1));
    expect(c.read(selectedDateProvider), DateRange.last);
    sel.shiftDays(5);
    expect(c.read(selectedDateProvider), DateTime(2040, 12, 31));
    sel.select(DateTime(2010, 1, 1));
    expect(c.read(selectedDateProvider), DateTime(2025, 1, 1));
  });

  test('التوقيت الصيفي لا يكسر التنقل بالأيام', () {
    var d = DateTime(2026, 1, 1);
    for (var i = 0; i < 400; i++) {
      final next = addDays(d, 1);
      expect(daysBetween(d, next), 1);
      expect(next, dateOnly(next));
      d = next;
    }
  });

  test('مفتاح dayInfoProvider غير المقرّب مرفوض في وضع التطوير', () async {
    final (c, _) = await container(DateTime(2026, 10, 2, 10));
    expect(c.read(dayInfoProvider(DateTime(2026, 10, 2))), isNotNull);
    expect(
      () => c.read(dayInfoProvider(DateTime(2026, 10, 2, 10))),
      throwsA(anything),
    );
  });

  test('yearIndexProvider: سنة كاملة لمنطقة المدينة', () async {
    final (c, _) = await container(DateTime(2028, 3, 1));
    final index = c.read(yearIndexProvider(2028))!;
    expect(index.length, 366);
    expect(index.days.first.regionId, 'najd');
    expect(index.days.first.dururRegionId, 'uae_oman');
  });

  test(
    'شريط «بيانات تجريبية»: يظهر ما دام في البيانات سجل غير معتمد',
    () async {
      final (c, _) = await container(DateTime(2026, 10, 2));
      expect(tables.hasUnapproved, isTrue);
      expect(c.read(hasUnapprovedDataProvider), isTrue);
    },
  );
}
