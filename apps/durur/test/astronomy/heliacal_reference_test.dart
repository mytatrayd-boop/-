import 'package:durur/src/astronomy/heliacal.dart';
import 'package:durur/src/astronomy/heliacal_params.dart';
import 'package:durur/src/astronomy/stars.dart';
import 'package:durur/src/astronomy/sun.dart';
import 'package:durur/src/astronomy/horizon.dart';
import 'package:durur/src/astronomy/sidereal.dart';
import 'package:durur/src/astronomy/time.dart';
import 'package:durur/src/domain/tables.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import 'reference_risings.dart';

/// المعايرة على القيم المرجعية (SPEC الميزة 5، المعيار 3؛ ARCHITECTURE §6).
/// المعيار: الرؤية بالعين المجردة. انظر reference_risings.dart لتصنيف القيم.
Future<void> main() async {
  final Tables tables = await loadAssetTables();
  const calc = HeliacalCalculator();

  DateTime? computed(String star, String cityId, int year) {
    final city = tables.city(cityId)!;
    final params = star == 'suhail' ? suhailParams : thurayyaParams;
    return calc.risingDate(params, lat: city.lat, lon: city.lon, year: year);
  }

  group('مراجع العين المجردة: الفرق ≤ يومين', () {
    for (final ref in referenceRisings.where(
      (r) => r.kind == ReferenceKind.nakedEye,
    )) {
      test(
        '${ref.star} ${ref.cityId} ${ref.month}/${ref.day} (${ref.source})',
        () {
          for (final year in ref.years) {
            final got = computed(ref.star, ref.cityId, year)!;
            final diff = got
                .difference(DateTime.utc(year, ref.month, ref.day))
                .inDays;
            expect(
              diff.abs(),
              lessThanOrEqualTo(2),
              reason: '$year: المحسوب $got',
            );
          }
        },
      );
    }
  });

  test('عرعر (30.98° ش): العين المجردة في الثلث الأول من سبتمبر 2026 (S23) ±يومين', () {
    // «أقصى شمال السعودية ≈ 8 سبتمبر» تقريبي لمدى 30–31°؛ عرعر عند حده الشمالي.
    final got = computed('suhail', 'arar', 2026)!;
    expect(got.isBefore(DateTime.utc(2026, 8, 30)), isFalse);
    expect(got.isAfter(DateTime.utc(2026, 9, 12)), isFalse);
  });

  test('مرجع الدوحة S24 مصنّف «متعارض» مع سببه، لا «عين مجردة»', () {
    final doha = referenceRisings.singleWhere(
      (r) => r.cityId == 'doha' && r.source == 'S24',
    );
    expect(doha.kind, ReferenceKind.conflicting);
    expect(doha.conflict, isNotEmpty);
  });

  test('التعارض الهندسي: سهيل في الدوحة يطلع قبل الكويت بـ 7 أيام على الأقل '
      'في كل سنة 2025–2040', () {
    for (var year = 2025; year <= 2040; year++) {
      final doha = computed('suhail', 'doha', year)!;
      final kuwait = computed('suhail', 'kuwait_city', year)!;
      expect(
        kuwait.difference(doha).inDays,
        greaterThanOrEqualTo(7),
        reason: '$year: الدوحة $doha، الكويت $kuwait',
      );
    }
  });

  group('مراجع الأداة (أول رؤية بمنظار/تصوير): العين المجردة ليست قبلها', () {
    for (final ref in referenceRisings.where(
      (r) => r.kind == ReferenceKind.instrument && r.firstSighting,
    )) {
      test(
        '${ref.star} ${ref.cityId} ${ref.month}/${ref.day} (${ref.source})',
        () {
          for (final year in ref.years) {
            final got = computed(ref.star, ref.cityId, year)!;
            expect(
              got.isBefore(DateTime.utc(year, ref.month, ref.day)),
              isFalse,
              reason: '$year: المحسوب $got',
            );
          }
        },
      );
    }
  });

  test('الثريا، الإمارات 12 يونيو 2025 (S26، تصوير): هندسياً النجم فوق الأفق '
      'والشمس تحته قبل الشروق بـ 35 دقيقة', () {
    // لا يثبت تاريخ العين المجردة (ليس أول رؤية ولا بالعين)؛ فحص اتساق فقط.
    for (final cityId in ['dubai', 'abu_dhabi']) {
      final city = tables.city(cityId)!;
      final sunrise = _sunrise(city.lat, city.lon, DateTime.utc(2025, 6, 12));
      final t = sunrise - 35 / 1440;
      final star = alcyone.positionAt(julianEphemerisDay(t));
      final starAlt = altitude(
        position: star,
        lat: city.lat,
        localSiderealTime: localSiderealTime(t, city.lon),
      );
      expect(starAlt, greaterThan(0), reason: cityId);
      expect(calc.sunAltitude(t, lat: city.lat, lon: city.lon), lessThan(0));
    }
  });
}

/// شروق الشمس (الحافة العليا مع الانكسار: −0.833°) صباح اليوم المحلي [date].
double _sunrise(double lat, double lon, DateTime date) {
  double alt(double jd) => altitude(
    position: sunApparentPosition(julianEphemerisDay(jd)),
    lat: lat,
    localSiderealTime: localSiderealTime(jd, lon),
  );
  var lo = julianDayUt(date) - lon / 360; // منتصف الليل المحلي
  var hi = lo + 0.5; // الظهر تقريباً
  for (var i = 0; i < 40; i++) {
    final mid = (lo + hi) / 2;
    if (alt(mid) < -0.833) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}
