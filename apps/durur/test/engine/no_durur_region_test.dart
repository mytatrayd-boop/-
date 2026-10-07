import 'package:durur/src/domain/city.dart';
import 'package:durur/src/domain/record_meta.dart';
import 'package:durur/src/domain/localized_text.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/period_finder.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:durur/src/notifications/notification_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';
import '../helpers/app_harness.dart';
import 'engine_expectations.dart';

/// السعودية بلا درور (D43، D50، ARCHITECTURE §18): المحلل يرفض
/// `dururBorrow`، والمحرك بلا دَرّ، و«الجو المعتاد» من النجم، والمدقق
/// وقاعدة الدولة، والمخطِّط بلا تنبيهات دَرّ.
Tables noDururTables({
  void Function(Map<String, Object?> c, List<Object?> items)? edit,
}) => fixtureTables(
  edit: (tables, regions, items) {
    final c = tables['c']! as Map<String, Object?>;
    c['durur'] = <Object?>[];
    edit?.call(c, items);
  },
);

City city(String id, Country country, String regionId) => City(
  id: id,
  name: LocalizedText({'ar': id}),
  country: country,
  lat: 24,
  lon: 46,
  regionId: regionId,
  source: const Source(title: 'fixture'),
  approval: const Approval(
    status: ApprovalStatus.approved,
    reviewer: 'test',
    date: '2026-10-07',
  ),
);

Tables withCities(Tables t, List<City> cities) => Tables(
  meta: t.meta,
  regions: t.regions,
  itemList: t.itemList,
  regionTables: t.regionTables,
  cities: cities,
);

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('المحلل', () {
    test('dururBorrow حقل ملغى يُرفض', () {
      expect(
        () => fixtureTables(
          edit: (tables, _, _) {
            final c = tables['c']! as Map<String, Object?>;
            c['durur'] = <Object?>[];
            c['dururBorrow'] = {
              'fromRegionId': 'b',
              'note': {'ar': 'سطر'},
              'source': fixtureSource,
              'approval': approved,
            };
          },
        ),
        throwsFormatException,
      );
    });

    test('durur فارغ = منطقة بلا درور', () {
      final t = noDururTables();
      expect(t.regionTables['c']!.hasDurur, isFalse);
      expect(t.regionTables['a']!.hasDurur, isTrue);
    });
  });

  group('المحرك', () {
    final t = noDururTables();
    final c = CalendarEngine.fromTables(t, 'c');

    test('لا دَرّ، والجو المعتاد من النجم الحالي', () {
      expect(c.hasDurur, isFalse);
      final info = c.resolve(DateTime(2026, 3, 3));
      expect(info.dar, isNull);
      expect(info.star.itemId, 'st1');
      expect(info.weather, t.items['st1']!.weather);
      expect(info.weather, isNotEmpty);
    });

    test('منطقة بدرور: الجو من الدَّرّ', () {
      final a = CalendarEngine.fromTables(t, 'a');
      final info = a.resolve(DateTime(2026, 3, 3));
      expect(info.dar, isNotNull);
      expect(info.weather, info.dar!.record.weather);
    });

    test('بلا محرك عناصر: الجو فارغ لا خطأ', () {
      final bare = CalendarEngine(
        region: t.region('c')!,
        table: t.regionTables['c']!,
      );
      expect(bare.resolve(DateTime(2026, 5, 1)).weather, isEmpty);
    });

    test('بلا دَرّ لكل أيام 2025–2040، والطبقات الأخرى متصلة', () async {
      final tables = await loadAssetTables();
      final najd = CalendarEngine.fromTables(tables, 'najd');
      for (var y = 2025; y <= 2040; y++) {
        final days = YearIndex(najd, y).days;
        for (var i = 0; i < days.length; i++) {
          expect(days[i].dar, isNull);
          expect(days[i].weather, isNotEmpty, reason: '${days[i].date}');
          expectConsistent(days[i]);
          if (i > 0) expectContinuous(days[i - 1], days[i]);
        }
      }
    });

    test('findDarPeriod في منطقة بلا درور ← null', () {
      final rec = t.regionTables['a']!.durur.first;
      expect(findDarPeriod(c, rec.start, DateTime(2026, 1, 1)), isNull);
    });
  });

  group('المدقق', () {
    const v = TableValidator();

    test('درور فارغة مسموحة', () {
      expect(v.validate(noDururTables()).errors, isEmpty);
    });

    test('بلا درور: نجم بلا weather ← خطأ', () {
      final r = v.validate(
        noDururTables(
          edit: (_, items) {
            for (final i in items) {
              final m = i! as Map<String, Object?>;
              if (m['id'] == 'st1') m['weather'] = <Object?>[];
            }
          },
        ),
      );
      expect(r.errors.join(), contains('بلا weather'));
    });

    test('قاعدة الدولة: سعودية بدرور أو خليجية بلا درور ← خطأ إطلاق، '
        'وتحذير في التطوير', () {
      final t = noDururTables();
      // c بلا درور، a بدرور.
      final ok = withCities(t, [
        city('riyadh', Country.sa, 'c'),
        city('dubai', Country.ae, 'a'),
      ]);
      expect(v.validate(ok).errors, isEmpty);
      expect(v.validate(ok).warnings.join(), isNot(contains('D43')));

      final bad = withCities(t, [
        city('riyadh', Country.sa, 'a'),
        city('dubai', Country.ae, 'c'),
      ]);
      final dev = v.validate(bad);
      expect(dev.errors, isEmpty);
      expect(dev.warnings.join(), contains('منطقة سعودية فيها درور'));
      expect(dev.warnings.join(), contains('خارج السعودية بلا درور'));
      final release = v.validate(bad, release: true);
      expect(release.errors.join(), contains('منطقة سعودية فيها درور'));
      expect(release.errors.join(), contains('خارج السعودية بلا درور'));
    });

    test('البيانات المضمّنة: نجد بلا درور، والخليج بدرور، بلا خطأ', () async {
      final tables = await loadAssetTables();
      expect(tables.regionTables['najd']!.hasDurur, isFalse);
      for (final id in ['kuwait', 'uae_oman', 'region4']) {
        expect(tables.regionTables[id]!.hasDurur, isTrue, reason: id);
      }
      final r = v.validate(tables);
      expect(r.errors, isEmpty);
      expect(r.warnings.join(), isNot(contains('D43')));
    });
  });

  test('المخطِّط: لا تنبيهات دَرّ لمنطقة بلا درور والمفتاح مفعّل', () {
    final t = noDururTables();
    final plan = const NotificationPlanner().plan(
      now: DateTime(2026, 1, 1, 9),
      engine: CalendarEngine.fromTables(t, 'c'),
      items: t.items,
      heliacal: (_) => null,
      important: false,
      dar: true,
    );
    expect(plan, isEmpty);
  });
}
