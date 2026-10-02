import 'package:durur/src/domain/month_day.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/period_finder.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';

/// الميزة 7: فترة العنصر أو الدَّرّ حول تاريخ مرجعي (تحتويه، وإلا التالية).
void main() {
  final tables = fixtureTables();
  final engine = CalendarEngine.fromTables(tables, 'a');

  group('findItemPeriod', () {
    test('الفترة التي تحتوي التاريخ', () {
      final p = findItemPeriod(
        engine,
        tables.items['s1']!,
        DateTime(2026, 3, 10),
      )!;
      expect(p.itemId, 's1');
      expect(p.start, DateTime.utc(2026, 1, 5));
      expect(p.end, DateTime.utc(2026, 6, 30));
      expect(p.record, isNotNull);
      expect(p.record!.sources.single.title, 'fixture');
    });

    test('خارجها ← الفترة التالية (عبر نهاية السنة)', () {
      final p = findItemPeriod(
        engine,
        tables.items['s1']!,
        DateTime(2026, 8, 1),
      )!;
      expect(p.start, DateTime.utc(2027, 1, 5));
    });

    test('موسم جو بعد فجوة، وموسم يلتف عبر نهاية السنة', () {
      final w2 = findItemPeriod(
        engine,
        tables.items['w2']!,
        DateTime(2026, 1, 20),
      )!;
      expect(w2.start, DateTime.utc(2026, 2, 25));
      expect(w2.end, DateTime.utc(2026, 2, 28));
      final w1 = findItemPeriod(
        engine,
        tables.items['w1']!,
        DateTime(2026, 1, 3),
      )!;
      expect(w1.start, DateTime.utc(2025, 12, 20));
      expect(w1.end, DateTime.utc(2026, 1, 10));
    });

    test('29 فبراير يدخل في موسم ينتهي 28 فبراير (extend_feb28)', () {
      final w2 = findItemPeriod(
        engine,
        tables.items['w2']!,
        DateTime(2028, 2, 29),
      )!;
      expect(w2.end, DateTime.utc(2028, 2, 29));
      expect(w2.length, 5);
    });

    test('عنصر لا يظهر في جدول المنطقة ← null', () {
      final t = fixtureTables(
        edit: (_, _, items) => items.add(item('st2', 'star')),
      );
      final e = CalendarEngine.fromTables(t, 'a');
      expect(findItemPeriod(e, t.items['st2']!, DateTime(2026, 1, 1)), isNull);
    });
  });

  group('findDarPeriod', () {
    test('الدَّرّ بتاريخ بدايته: يحتوي التاريخ أو التالي', () {
      final now = findDarPeriod(
        engine,
        const MonthDay(2, 20),
        DateTime(2026, 2, 22),
      )!;
      expect(now.start, DateTime.utc(2026, 2, 20));
      expect(now.end, DateTime.utc(2026, 2, 28));
      final next = findDarPeriod(
        engine,
        const MonthDay(2, 20),
        DateTime(2026, 3, 2),
      )!;
      expect(next.start, DateTime.utc(2027, 2, 20));
      expect(next.record.name.ar, 'ب');
    });

    test('بداية لا سجل لها ← null', () {
      expect(
        findDarPeriod(engine, const MonthDay(4, 4), DateTime(2026)),
        isNull,
      );
    });
  });
}
