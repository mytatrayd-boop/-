import 'package:durur/src/astronomy/heliacal.dart';
import 'package:durur/src/astronomy/heliacal_params.dart';
import 'package:durur/src/astronomy/time.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// ARCHITECTURE §6: الاتجاه مع خط العرض، الترتيب الجغرافي، الثبات بين السنوات،
/// وحالات الحدود.
Future<void> main() async {
  final Tables tables = await loadAssetTables();
  const calc = HeliacalCalculator();
  final years = [for (var y = 2025; y <= 2040; y++) y];

  DateTime rising(HeliacalParams p, String cityId, int year) {
    final c = tables.city(cityId)!;
    return calc.risingDate(p, lat: c.lat, lon: c.lon, year: year)!;
  }

  /// الفرق بالأيام بين يومين في سنتين مختلفتين بعد نقلهما لسنة واحدة غير كبيسة.
  int dayOfYearDiff(DateTime a, DateTime b) => DateTime.utc(
    2001,
    a.month,
    a.day,
  ).difference(DateTime.utc(2001, b.month, b.day)).inDays;

  test('SPEC 5.2: سهيل مسقط ≤ الرياض ≤ الكويت في كل سنة 2025–2040', () {
    for (final y in years) {
      final muscat = rising(suhailParams, 'muscat', y);
      final riyadh = rising(suhailParams, 'riyadh', y);
      final kuwait = rising(suhailParams, 'kuwait_city', y);
      expect(muscat.isAfter(riyadh), isFalse, reason: '$y');
      expect(riyadh.isAfter(kuwait), isFalse, reason: '$y');
    }
  });

  test('سهيل يطلع أبكر جنوباً: جازان < الرياض < الكويت < عرعر', () {
    for (final y in years) {
      final dates = [
        for (final id in ['jazan', 'riyadh', 'kuwait_city', 'arar'])
          rising(suhailParams, id, y),
      ];
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i - 1].isBefore(dates[i]), isTrue, reason: '$y $dates');
      }
    }
  });

  test('سهيل: التاريخ لا يتقدم كلما زاد خط العرض (15°–32° ش، خط طول ثابت)', () {
    DateTime? previous;
    for (var lat = 15.0; lat <= 32.0; lat += 0.5) {
      final d = calc.risingDate(suhailParams, lat: lat, lon: 47, year: 2026)!;
      if (previous != null) {
        expect(d.isBefore(previous), isFalse, reason: 'lat $lat');
      }
      previous = d;
    }
  });

  test('الثبات: الفرق بين سنتين متتاليتين ≤ يوم (كل المدن، 2025–2040)', () {
    for (final params in [suhailParams, thurayyaParams]) {
      for (final city in tables.cities) {
        DateTime? previous;
        for (final y in years) {
          final d = calc.risingDate(
            params,
            lat: city.lat,
            lon: city.lon,
            year: y,
          );
          expect(d, isNotNull, reason: '${params.star.id} ${city.id} $y');
          expect(d!.year, y);
          if (previous != null) {
            expect(
              dayOfYearDiff(d, previous).abs(),
              lessThanOrEqualTo(1),
              reason: '${params.star.id} ${city.id} $y',
            );
          }
          previous = d;
        }
      }
    }
  });

  test('كل المدن: الطلوع داخل نافذة البحث وبعيد عن طرفيها', () {
    for (final city in tables.cities) {
      final h = calc.compute(lat: city.lat, lon: city.lon, year: 2026);
      expect(h.suhail!.isAfter(DateTime.utc(2026, 7, 20)), isTrue);
      expect(h.suhail!.isBefore(DateTime.utc(2026, 9, 25)), isTrue);
      expect(h.thurayya!.isAfter(DateTime.utc(2026, 5, 20)), isTrue);
      expect(h.thurayya!.isBefore(DateTime.utc(2026, 7, 10)), isTrue);
    }
  });

  test(
    'بعد الطلوع يبقى النجم مرئياً كل يوم حتى نهاية النافذة، وقبله لا يُرى',
    () {
      for (final cityId in [
        'jazan',
        'muscat',
        'riyadh',
        'kuwait_city',
        'arar',
      ]) {
        final c = tables.city(cityId)!;
        for (final params in [suhailParams, thurayyaParams]) {
          final r = calc.risingDate(
            params,
            lat: c.lat,
            lon: c.lon,
            year: 2026,
          )!;
          final end = params.windowEnd.inYear(2026);
          for (
            var d = params.windowStart.inYear(2026);
            !d.isAfter(end);
            d = DateTime.utc(d.year, d.month, d.day + 1)
          ) {
            expect(
              calc.isVisible(params, lat: c.lat, lon: c.lon, date: d),
              !d.isBefore(r),
              reason: '${params.star.id} $cityId $d',
            );
          }
        }
      }
    },
  );

  test('يوم الطلوع: النجم يبلغ h_star قبل الشروق والشمس منخفضة ≥ AV', () {
    final c = tables.city('kuwait_city')!;
    final r = rising(suhailParams, 'kuwait_city', 2026);
    final t = calc.starRisingMoment(
      suhailParams,
      lat: c.lat,
      lon: c.lon,
      date: r,
    )!;
    final local = dateTimeFromJulianDay(t).add(const Duration(hours: 3));
    expect(local.day, r.day); // صباح اليوم نفسه بتوقيت الكويت
    expect(local.hour, inInclusiveRange(3, 5));
    expect(
      calc.sunAltitude(t, lat: c.lat, lon: c.lon),
      lessThanOrEqualTo(-suhailParams.arcusVisionis),
    );
    // في اليوم السابق الشمس أعلى من −AV لحظة بلوغ النجم h_star.
    final prev = DateTime.utc(r.year, r.month, r.day - 1);
    final tPrev = calc.starRisingMoment(
      suhailParams,
      lat: c.lat,
      lon: c.lon,
      date: prev,
    )!;
    expect(
      calc.sunAltitude(tPrev, lat: c.lat, lon: c.lon),
      greaterThan(-suhailParams.arcusVisionis),
    );
  });

  test('قوس رؤية أكبر يؤخر الطلوع', () {
    HeliacalParams withAv(double av) => HeliacalParams(
      star: suhailParams.star,
      starAltitude: suhailParams.starAltitude,
      arcusVisionis: av,
      windowStart: suhailParams.windowStart,
      windowEnd: suhailParams.windowEnd,
    );
    final c = tables.city('riyadh')!;
    final early = calc.risingDate(
      withAv(9),
      lat: c.lat,
      lon: c.lon,
      year: 2026,
    )!;
    final late = calc.risingDate(
      withAv(16),
      lat: c.lat,
      lon: c.lon,
      year: 2026,
    )!;
    expect(early.isBefore(late), isTrue);
  });

  group('حالات الحدود', () {
    test('شمال 37° ش: سهيل لا يرتفع فوق 1° ← لا طلوع، والثريا تُحسب', () {
      final h = calc.compute(lat: 40, lon: 30, year: 2026);
      expect(h.suhail, isNull);
      expect(h.thurayya, isNotNull);
      expect(
        calc.risingDate(suhailParams, lat: 37, lon: 47, year: 2026),
        isNull,
      );
    });

    test('جنوب −38°: سهيل لا يغيب أبداً ← لا طلوع فجري', () {
      expect(
        calc.risingDate(suhailParams, lat: -50, lon: 20, year: 2026),
        isNull,
      );
    });

    test('الطلوع قبل بداية النافذة (خط الاستواء) ← null لا تاريخ خاطئ', () {
      // عند خط الاستواء سهيل مرئي فجراً قبل 15 يوليو.
      expect(
        calc.isVisible(
          suhailParams,
          lat: 0,
          lon: 47,
          date: DateTime.utc(2026, 7, 15),
        ),
        isTrue,
      );
      expect(
        calc.risingDate(suhailParams, lat: 0, lon: 47, year: 2026),
        isNull,
      );
    });

    test('مدخلات خارج المدى ترمي RangeError', () {
      for (final call in <void Function()>[
        () => calc.compute(lat: 91, lon: 0, year: 2026),
        () => calc.compute(lat: -90.1, lon: 0, year: 2026),
        () => calc.compute(lat: double.nan, lon: 0, year: 2026),
        () => calc.compute(lat: 25, lon: 180.5, year: 2026),
        () => calc.compute(lat: 25, lon: 50, year: 1999),
        () => calc.compute(lat: 25, lon: 50, year: 2101),
      ]) {
        expect(call, throwsRangeError);
      }
    });

    test('حدود المدى المسموح تعمل', () {
      expect(calc.compute(lat: 25, lon: 180, year: 2000).suhail, isNotNull);
      expect(calc.compute(lat: 25, lon: -180, year: 2100).suhail, isNotNull);
    });

    test('السنة الكبيسة (2028) لا تكسر الحساب', () {
      final d = rising(suhailParams, 'riyadh', 2028);
      final d27 = rising(suhailParams, 'riyadh', 2027);
      expect(dayOfYearDiff(d, d27).abs(), lessThanOrEqualTo(1));
    });

    test('النتيجة تاريخ فقط (منتصف الليل UTC)', () {
      final d = rising(thurayyaParams, 'doha', 2026);
      expect(d.isUtc, isTrue);
      expect([d.hour, d.minute, d.second, d.millisecond], [0, 0, 0, 0]);
    });
  });
}
