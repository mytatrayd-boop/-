import 'package:durur/src/domain/day_info.dart';
import 'package:durur/src/domain/weather_symbol.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/fixture_tables.dart';
import 'engine_expectations.dart';

void main() {
  final tables = fixtureTables();
  CalendarEngine engineFor(String id) => CalendarEngine(
      region: tables.region(id)!, table: tables.regionTables[id]!);
  final a = engineFor('a');
  final b = engineFor('b');

  DateTime utc(int y, int m, int d) => DateTime.utc(y, m, d);

  group('معيار 1: محتوى النتيجة', () {
    test('يُرجع الدَّرّ ورقمه واليوم والموسم والنجم وموسم الجو والجو', () {
      final info = a.resolve(DateTime(2026, 1, 8));
      expect(info.regionId, 'a');
      expect(info.date, utc(2026, 1, 8));
      expect(info.dar!.name.ar, 'أ');
      expect(info.dar!.number, 1);
      expect(info.dar!.dayNumber, 4);
      expect(info.dar!.length, 46); // 01-05 .. 02-19
      expect(info.majorSeason.itemId, 's1');
      expect(info.star.itemId, 'st1');
      expect(info.weatherSeason?.itemId, 'w1');
      expect(info.weather, [WeatherSymbol.cold]);
      expect(info.weatherNote?.ar, 'ملاحظة');
    });

    test('موسم الجو قد يكون غير موجود', () {
      expect(a.resolve(DateTime(2026, 1, 11)).weatherSeason, isNull);
      expect(a.resolve(DateTime(2026, 6, 1)).weatherSeason, isNull);
    });
  });

  group('معيار 3 و4: حدود الدَّرّ', () {
    test('يوم البداية = اليوم 1، واليوم السابق = آخر يوم في السابق', () {
      final first = a.resolve(DateTime(2026, 3, 1));
      expect(first.dar!.name.ar, 'ج');
      expect(first.majorSeason.itemId, 's1');
      expect(first.dar!.dayNumber, 1);
      expect(first.dar!.start, utc(2026, 3, 1));

      final before = a.resolve(DateTime(2026, 2, 28));
      expect(before.dar!.name.ar, 'ب');
      expect(before.dar!.dayNumber, before.dar!.length);
      expect(before.dar!.end, utc(2026, 2, 28));
    });

    test('حدود الموسم الكبير', () {
      expect(a.resolve(DateTime(2026, 7, 1)).majorSeason.itemId, 's2');
      expect(a.resolve(DateTime(2026, 7, 1)).majorSeason.dayNumber, 1);
      expect(a.resolve(DateTime(2026, 6, 30)).majorSeason.itemId, 's1');
    });
  });

  group('نهاية السنة (التفاف)', () {
    test('أيام يناير قبل أول بداية تتبع آخر دَرّ من السنة السابقة', () {
      final dec31 = a.resolve(DateTime(2026, 12, 31));
      final jan1 = a.resolve(DateTime(2027, 1, 1));
      final jan4 = a.resolve(DateTime(2027, 1, 4));
      final jan5 = a.resolve(DateTime(2027, 1, 5));
      expect(dec31.dar!.name.ar, 'د');
      expect(dec31.dar!.dayNumber, 7);
      expect(jan1.dar!.name.ar, 'د');
      expect(jan1.dar!.dayNumber, 8);
      expect(jan1.dar!.start, utc(2026, 12, 25));
      expect(jan4.dar!.dayNumber, jan4.dar!.length);
      expect(jan4.dar!.end, utc(2027, 1, 4));
      expect(jan5.dar!.name.ar, 'أ');
      expect(jan5.dar!.dayNumber, 1);
      expect(jan1.majorSeason.itemId, 's2');
    });

    test('موسم الجو الملتف عبر السنة', () {
      final jan5 = a.resolve(DateTime(2027, 1, 5));
      expect(jan5.weatherSeason!.itemId, 'w1');
      expect(jan5.weatherSeason!.start, utc(2026, 12, 20));
      expect(jan5.weatherSeason!.end, utc(2027, 1, 10));
      expect(jan5.weatherSeason!.dayNumber, 17);
      final dec20 = a.resolve(DateTime(2026, 12, 20)).weatherSeason!;
      expect(dec20.dayNumber, 1);
      expect(dec20.end, utc(2027, 1, 10));
      expect(a.resolve(DateTime(2026, 12, 19)).weatherSeason, isNull);
    });

    test('طبقة بسجل واحد تغطي السنة كاملة', () {
      final star = a.resolve(DateTime(2026, 4, 30)).star;
      expect(star.itemId, 'st1');
      expect(star.start, utc(2025, 5, 1));
      expect(star.dayNumber, star.length);
      expect(star.length, 365);
    });
  });

  group('معيار 5: اختلاف المناطق', () {
    test('التاريخ نفسه يُرجع دَرّاً مختلفاً في جدول آخر', () {
      final date = DateTime(2026, 3, 2);
      expect(a.resolve(date).dar!.name.ar, 'ج');
      expect(b.resolve(date).dar!.name.ar, 'ب');
    });
  });

  group('معيار 6: 29 فبراير', () {
    test('يتبع دَرّ 28 فبراير ويطول ذلك الدَّرّ يوماً', () {
      final feb28 = a.resolve(DateTime(2028, 2, 28));
      final feb29 = a.resolve(DateTime(2028, 2, 29));
      final mar1 = a.resolve(DateTime(2028, 3, 1));
      expect(feb29.dar!.name.ar, 'ب');
      expect(feb29.dar!.dayNumber, feb28.dar!.dayNumber + 1);
      expect(feb29.dar!.length, 10);
      expect(feb29.dar!.dayNumber, feb29.dar!.length);
      expect(mar1.dar!.name.ar, 'ج');
      expect(mar1.dar!.dayNumber, 1);
      // في السنة غير الكبيسة طوله 9.
      expect(a.resolve(DateTime(2027, 2, 28)).dar!.length, 9);
    });

    test('موسم جو ينتهي 28 فبراير يشمل 29 فبراير', () {
      final ws = a.resolve(DateTime(2028, 2, 29)).weatherSeason!;
      expect(ws.itemId, 'w2');
      expect(ws.end, utc(2028, 2, 29));
      expect(ws.dayNumber, ws.length);
      expect(a.resolve(DateTime(2027, 2, 28)).weatherSeason!.end,
          utc(2027, 2, 28));
      expect(a.resolve(DateTime(2028, 3, 1)).weatherSeason, isNull);
    });

    test('قاعدة القرن: 2100 ليست كبيسة و2000 كبيسة', () {
      expect(YearIndex(a, 2100).length, 365);
      expect(YearIndex(a, 2000).length, 366);
      expect(a.resolve(DateTime(2000, 2, 29)).dar!.length, 10);
    });
  });

  group('معيار 8: اليوم يبدأ منتصف الليل بتوقيت الجهاز', () {
    test('الوقت داخل اليوم لا يغيّر النتيجة', () {
      final late = a.resolve(DateTime(2026, 2, 28, 23, 59, 59));
      final midnight = a.resolve(DateTime(2026, 3, 1));
      final morning = a.resolve(DateTime(2026, 3, 1, 8, 30));
      expect(late.dar!.name.ar, 'ب');
      expect(midnight.dar!.name.ar, 'ج');
      expect(morning.dar!.name.ar, 'ج');
      expect(morning.date, utc(2026, 3, 1));
    });
  });

  group('معيار 2 و7: كل يوم نتيجة واحدة متصلة 2025–2040', () {
    for (final id in ['a', 'b']) {
      test('المنطقة $id', () {
        final engine = engineFor(id);
        DayInfo? prev;
        for (var y = 2025; y <= 2040; y++) {
          final index = YearIndex(engine, y);
          expect(index.length, isLeapYear(y) ? 366 : 365);
          for (final info in index.days) {
            expectConsistent(info);
            if (prev != null) expectContinuous(prev, info);
            prev = info;
          }
        }
      });
    }
  });

  test('YearIndex.dayOf', () {
    final index = YearIndex(a, 2028);
    expect(index.dayOf(DateTime(2028, 12, 31)).date, utc(2028, 12, 31));
    expect(() => index.dayOf(DateTime(2029, 1, 1)), throwsArgumentError);
  });
}
