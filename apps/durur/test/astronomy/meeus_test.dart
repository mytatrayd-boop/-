import 'package:durur/src/astronomy/angles.dart';
import 'package:durur/src/astronomy/horizon.dart';
import 'package:durur/src/astronomy/precession.dart';
import 'package:durur/src/astronomy/sidereal.dart';
import 'package:durur/src/astronomy/stars.dart';
import 'package:durur/src/astronomy/sun.dart';
import 'package:durur/src/astronomy/time.dart';
import 'package:flutter_test/flutter_test.dart';

/// أمثلة Meeus «Astronomical Algorithms» (الطبعة 2) المحلولة.
void main() {
  test('Meeus 7.a: التاريخ اليولياني لـ 1957-10-04.81', () {
    // 0.81 يوم = 19:26:24.
    expect(
      julianDayUt(DateTime.utc(1957, 10, 4, 19, 26, 24)),
      closeTo(2436116.31, 1e-6),
    );
    expect(julianDayUt(DateTime.utc(2000, 1, 1, 12)), j2000);
  });

  test('التحويل من التاريخ اليولياني وإليه متعاكسان', () {
    final t = DateTime.utc(2026, 8, 27, 1, 23, 45);
    expect(dateTimeFromJulianDay(julianDayUt(t)), t);
  });

  test('Meeus 12.a و12.b: الزمن النجمي المتوسط في غرينتش', () {
    expect(greenwichMeanSiderealTime(2446895.5), closeTo(197.693195, 1e-5));
    expect(
      greenwichMeanSiderealTime(2446896.30625),
      closeTo(128.7378734, 1e-5),
    );
    // الشرق موجب في الزمن النجمي المحلي.
    expect(localSiderealTime(2446895.5, 10), closeTo(207.693195, 1e-5));
  });

  test('Meeus 25.a: موضع الشمس الظاهري 1992-10-13.0 TD', () {
    final sun = sunApparentPosition(2448908.5);
    expect(sun.ra, closeTo(198.38083, 1e-4));
    expect(sun.dec, closeTo(-7.78507, 1e-4));
  });

  test(
    'Meeus 21.b: θ Persei بالحركة الذاتية والمبادرة إلى 2028-11-13.19 TD',
    () {
      const dec0 = 49.228467; // +49°13′42.48″
      final thetaPersei = Star(
        id: 'theta_persei',
        raJ2000: 41.049942, // 2h44m11.986s
        decJ2000: dec0,
        // μα = +0.03425 ث زمنية/سنة = 0.51375″ في المطلع المستقيم.
        pmRaCosDec: 513.75 * cosDeg(dec0),
        pmDec: -89.5,
        magnitude: 4.1,
      );
      final p = thetaPersei.positionAt(2462088.69);
      expect(p.ra, closeTo(41.547214, 2e-5));
      expect(p.dec, closeTo(49.348483, 2e-5));
    },
  );

  test('المبادرة عند J2000 نفسها لا تغيّر الموضع', () {
    final p = precessFromJ2000(const Equatorial(95.98, -52.69), j2000);
    expect(p.ra, closeTo(95.98, 1e-9));
    expect(p.dec, closeTo(-52.69, 1e-9));
  });

  test('إحداثيات سهيل والثريا J2000 (SIMBAD)', () {
    expect(canopus.raJ2000, closeTo(95.98796, 1e-4));
    expect(canopus.decJ2000, closeTo(-52.69566, 1e-4));
    expect(alcyone.raJ2000, closeTo(56.87115, 1e-4));
    expect(alcyone.decJ2000, closeTo(24.10514, 1e-4));
  });

  group('الانكسار (Sæmundsson)', () {
    test('قرب الأفق ≈ نصف درجة، ويتناقص مع الارتفاع', () {
      final r0 = saemundssonRefraction(trueAltitudeForApparent(0));
      // الانكسار الأفقي المعتاد ≈ 34′.
      expect(r0, closeTo(0.57, 0.02));
      expect(saemundssonRefraction(10), lessThan(saemundssonRefraction(1)));
      expect(saemundssonRefraction(90), closeTo(0, 1e-3));
    });

    test('الارتفاع الحقيقي + الانكسار = الظاهري', () {
      for (final app in [0.0, 1.0, 5.0, 30.0]) {
        final h = trueAltitudeForApparent(app);
        expect(h, lessThan(app));
        expect(h + saemundssonRefraction(h), closeTo(app, 1e-8));
      }
    });
  });

  test('الارتفاع: جرم في سمت الرأس وعلى الأفق', () {
    // جرم ميله = خط العرض وزاويته الساعية صفر ← في سمت الرأس.
    expect(
      altitude(
        position: const Equatorial(100, 25),
        lat: 25,
        localSiderealTime: 100,
      ),
      closeTo(90, 1e-9),
    );
    // من خط الاستواء: جرم على خط الاستواء السماوي بزاوية ساعية 90° ← على الأفق.
    expect(
      altitude(
        position: const Equatorial(100, 0),
        lat: 0,
        localSiderealTime: 190,
      ),
      closeTo(0, 1e-9),
    );
  });
}
