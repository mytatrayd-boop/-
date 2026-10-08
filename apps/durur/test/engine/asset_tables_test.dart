import 'dart:io';

import 'package:durur/src/domain/day_info.dart';
import 'package:durur/src/domain/item.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/table_validator.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:durur/src/repository/table_repository.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import 'engine_expectations.dart';

/// اختبارات الميزة 1 على جداول assets/tables الفعلية.
/// لا تفترض قيماً بعينها، فتبقى صالحة بعد استبدال البيانات التجريبية بالمعتمدة.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await TablesLoader((path) => File(path).readAsString()).load();
  final engines = {
    for (final r in tables.regions)
      r.id: CalendarEngine.fromTables(tables, r.id),
  };
  const years = (first: 2025, last: 2040);

  test('الجداول سليمة، والإطلاق ممنوع ما دام فيها سجل غير معتمد', () {
    final dev = const TableValidator().validate(tables);
    expect(dev.errors, isEmpty);
    final release = const TableValidator().validate(tables, release: true);
    expect(release.isValid, !tables.hasUnapproved);
  });

  test('4 مناطق ولكل منها جدول', () {
    expect(tables.regions, hasLength(4));
    expect(engines, hasLength(4));
  });

  test('TableRepository يحمّل الأصول المضمّنة نفسها', () async {
    final fromBundle = await TableRepository().load();
    expect(fromBundle.meta.dataVersion, tables.meta.dataVersion);
    expect(fromBundle.regionTables.keys, tables.regionTables.keys);
  });

  for (final region in tables.regions) {
    final engine = engines[region.id]!;
    final table = tables.regionTables[region.id]!;

    group('المنطقة ${region.id}', () {
      test('معيار 2 و7: كل يوم 2025–2040 نتيجة واحدة بلا فجوات ولا تداخل', () {
        DayInfo? prev;
        for (var y = years.first; y <= years.last; y++) {
          final index = YearIndex(engine, y);
          expect(index.length, isLeapYear(y) ? 366 : 365);
          for (final info in index.days) {
            expectConsistent(info);
            _expectItemsExist(tables, info);
            if (prev != null) expectContinuous(prev, info);
            prev = info;
          }
        }
      });

      test(
        'معيار 3 و4: بداية كل دَرّ = اليوم 1، والسابق = آخر يوم في السابق',
        () {
          for (final y in [years.first, 2027, 2028, years.last]) {
            for (final dar in table.durur) {
              final start = dar.start.inYear(y);
              final info = engine.resolve(start);
              expect(info.dar!.record, same(dar));
              expect(info.dar!.dayNumber, 1);
              expect(info.dar!.start, start);
              expect(info.majorSeason.itemId, dar.seasonId);

              final before = engine.resolve(
                start.subtract(const Duration(days: 1)),
              );
              expect(before.dar!.record, isNot(same(dar)));
              expect(before.dar!.dayNumber, before.dar!.length);
              expect(before.dar!.end, start.subtract(const Duration(days: 1)));
            }
          }
        },
      );

      test('نهاية السنة: 31 ديسمبر ثم 1 يناير متصلان', () {
        for (var y = years.first; y < years.last; y++) {
          final dec31 = engine.resolve(DateTime(y, 12, 31));
          final jan1 = engine.resolve(DateTime(y + 1, 1, 1));
          expectContinuous(dec31, jan1);
        }
      });

      test('معيار 6: 29 فبراير يتبع دَرّ 28 فبراير ويطوله يوماً', () {
        // منطقة بلا درور (السعودية، D50): لا دَرّ يطول.
        if (!table.hasDurur) return;
        for (final y in [2028, 2032, 2036, 2040]) {
          final feb28 = engine.resolve(DateTime(y, 2, 28));
          final feb29 = engine.resolve(DateTime(y, 2, 29));
          final mar1 = engine.resolve(DateTime(y, 3, 1));
          expect(feb29.dar!.record, same(feb28.dar!.record));
          expect(feb29.dar!.dayNumber, feb28.dar!.dayNumber + 1);
          expectContinuous(feb29, mar1);
          final common = engine.resolve(DateTime(y - 1, 2, 28));
          expect(common.dar!.record, same(feb28.dar!.record));
          expect(feb29.dar!.length, common.dar!.length + 1);
        }
      });

      test('معيار 8: الوقت داخل اليوم لا يغيّر النتيجة', () {
        final a = engine.resolve(DateTime(2026, 10, 2));
        final b = engine.resolve(DateTime(2026, 10, 2, 23, 59, 59));
        expect(b.date, a.date);
        expect(b.dar?.record, same(a.dar?.record));
        expect(b.dar?.dayNumber, a.dar?.dayNumber);
        expect(b.star.start, a.star.start);
      });
    });
  }

  test('معيار 5: تاريخ واحد على الأقل يختلف بين نجد والكويت', () {
    final najd = engines['najd']!;
    final kuwait = engines['kuwait']!;
    final differs = YearIndex(najd, 2026).days.any((info) {
      final other = kuwait.resolve(info.date);
      return other.dar?.record.name.ar != info.dar?.record.name.ar ||
          other.star.start != info.star.start ||
          other.majorSeason.itemId != info.majorSeason.itemId;
    });
    expect(differs, isTrue);
  });
}

void _expectItemsExist(Tables tables, DayInfo info) {
  expect(tables.items[info.majorSeason.itemId]?.kind, ItemKind.majorSeason);
  expect(tables.items[info.star.itemId]?.kind, ItemKind.star);
  final ws = info.weatherSeason;
  if (ws != null) {
    expect(tables.items[ws.itemId]?.kind, ItemKind.weatherSeason);
  }
}
