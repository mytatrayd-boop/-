import 'package:durur/src/domain/item.dart';
import 'package:durur/src/domain/month_day.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:durur/src/features/home/dial/dial_model.dart';
import 'package:durur/src/features/item_detail/detail_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';
import '../helpers/app_harness.dart';

/// الميزة 7: محتوى صفحة النجم/الموسم/الدَّرّ، والمعيار 3 على البيانات.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final assets = await loadAssetTables();

  group('resolveDetail', () {
    final tables = fixtureTables();
    final engine = CalendarEngine.fromTables(tables, 'a');
    DetailData? resolve(DetailTarget t, DateTime from) => resolveDetail(
      tables: tables,
      engine: engine,
      request: (target: t, from: from),
    );

    test('نجم: الفترة، والموسم الكبير في بدايتها، ومصدرا النص والتواريخ', () {
      final d = resolve(const ItemTarget('st1'), DateTime(2026, 6, 1))!;
      expect(d.kind, DetailKind.star);
      expect(d.name, 'st1');
      expect(d.period.start, DateTime.utc(2026, 5, 1));
      expect(d.seasonId, 's1');
      expect(d.regionName, 'a');
      expect(d.item!.proverb.ar, 'مثل');
      expect(d.datesRecord, isNotNull);
      expect(d.isHeliacal, isFalse);
    });

    test('موسم كبير: بلا شريحة موسم', () {
      final d = resolve(const ItemTarget('s2'), DateTime(2026, 8, 1))!;
      expect(d.kind, DetailKind.season);
      expect(d.seasonId, isNull);
    });

    test('دَرّ (D26): من سجله بلا itemId، والشريحة مئته', () {
      final d = resolve(
        const DarTarget('a', MonthDay(7, 1)),
        DateTime(2026, 7, 4),
      )!;
      expect(d.kind, DetailKind.dar);
      expect(d.name, 'هـ');
      expect(d.item, isNull);
      expect(d.seasonId, 's2');
      expect(d.weather.single.name, 'cold');
      expect(d.weatherNote!.ar, 'ملاحظة');
      expect(d.period.end, DateTime.utc(2026, 12, 24));
    });

    test('مسار لا يجد سجله ← null (فتعود الصفحة للرئيسية)', () {
      expect(resolve(const ItemTarget('nope'), DateTime(2026)), isNull);
      expect(
        resolve(const DarTarget('a', MonthDay(7, 2)), DateTime(2026)),
        isNull,
      );
      expect(
        resolve(const DarTarget('zz', MonthDay(7, 1)), DateTime(2026)),
        isNull,
      );
      expect(
        resolveDetail(
          tables: tables,
          engine: null,
          request: (target: const ItemTarget('s1'), from: DateTime(2026)),
        ),
        isNull,
      );
    });

    test('دَرّ بمعرّف منطقة مستعيرة ← null (الدرور في جدول المُعيرة)', () {
      final d = resolveDetail(
        tables: assets,
        engine: CalendarEngine.fromTables(assets, 'najd'),
        request: (
          target: const DarTarget('najd', MonthDay(1, 8)),
          from: DateTime(2026),
        ),
      );
      expect(d, isNull);
    });
  });

  group('detailRequestFor (من الدائرة والبطاقة)', () {
    test('الرياض بلا درور (D50): حلقة الدرور غير موجودة، والطلب يذهب للطالع، '
        'ومسار /dar/najd لا يجد صفحة', () {
      final day = CalendarEngine.fromTables(
        assets,
        'najd',
      ).resolve(DateTime(2026, 10, 2));
      expect(day.dar, isNull);
      final r = detailRequestFor(DialRing.durur, day);
      expect(r.target, ItemTarget(day.star.itemId));
      final najdDar = resolveDetail(
        tables: assets,
        engine: CalendarEngine.fromTables(assets, 'najd'),
        request: (
          target: DarTarget(
            'najd',
            assets.regionTables['uae_oman']!.durur.first.start,
          ),
          from: DateTime(2026, 10, 2),
        ),
      );
      expect(najdDar, isNull);
    });

    test('الحلقات: النجم والموسم والأشهر وموسم الجو أو الدَّرّ', () {
      final day = CalendarEngine.fromTables(
        assets,
        'kuwait',
      ).resolve(DateTime(2026, 10, 2));
      expect(day.weatherSeason, isNull);
      expect(
        detailRequestFor(DialRing.stars, day).target,
        ItemTarget(day.star.itemId),
      );
      expect(
        detailRequestFor(DialRing.months, day).target,
        ItemTarget(day.majorSeason.itemId),
      );
      expect(
        detailRequestFor(DialRing.weather, day).target,
        DarTarget('kuwait', day.dar!.record.start),
      );
    });
  });

  test('D26: لا نوع «dar» في items.json (ItemKind.dar محذوف)', () {
    expect(ItemKind.values.map((k) => k.code), isNot(contains('dar')));
    expect(() => ItemKind.parse('dar', 'items.json[x]'), throwsFormatException);
  });

  test('المعيار 3: كل نجم وموسم يظهر في الدائرة له تعريف ومثل ومصدر', () {
    for (final region in assets.regions) {
      final engine = CalendarEngine.fromTables(assets, region.id);
      final index = YearIndex(engine, 2026);
      final ids = <String>{};
      for (final day in index.days) {
        ids
          ..add(day.star.itemId)
          ..add(day.majorSeason.itemId);
        if (day.weatherSeason != null) ids.add(day.weatherSeason!.itemId);
        if (day.dar != null) ids.add(day.dar!.record.seasonId);
      }
      for (final id in ids) {
        final item = assets.items[id];
        expect(item, isNotNull, reason: '${region.id}: $id');
        expect(item!.definition.ar.trim(), isNotEmpty, reason: id);
        expect(
          item.definition.ar.split('\n').length,
          lessThanOrEqualTo(2),
          reason: id,
        );
        expect(item.proverb.ar.trim(), isNotEmpty, reason: id);
        expect(item.sources, isNotEmpty, reason: id);
        expect(item.sources.first.title.trim(), isNotEmpty, reason: id);
        final page = resolveDetail(
          tables: assets,
          engine: engine,
          request: (target: ItemTarget(id), from: DateTime(2026)),
        );
        expect(page, isNotNull, reason: '${region.id}: $id');
      }
      // وكل دَرّ له صفحة من سجله (لا درور في السعودية، D50).
      if (!engine.hasDurur) continue;
      for (final day in index.days) {
        final page = resolveDetail(
          tables: assets,
          engine: engine,
          request: detailRequestFor(DialRing.durur, day),
        );
        expect(page?.kind, DetailKind.dar, reason: '${region.id} ${day.date}');
      }
    }
  });
}
