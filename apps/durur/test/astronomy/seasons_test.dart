import 'package:durur/src/astronomy/seasons.dart';
import 'package:flutter_test/flutter_test.dart';

/// الفصول الفلكية والبروج (DESIGN R3.2 وR3.7-3/4، D40).
///
/// القيم المرجعية: جدول USNO «Earth's Seasons — Equinoxes, Solstices,
/// Perihelion, and Aphelion» (UTC، مقربة للدقيقة)، وطابقناها بحساب مستقل
/// بمكتبة PyEphem 4 (VSOP87) فاتفقتا في حدود دقيقة. الدقة المطلوبة ±2 دقيقة.
void main() {
  // (السنة، الحدث) ← (شهر، يوم، ساعة، دقيقة) UTC.
  const usno = <(int, SolarEvent), (int, int, int, int)>{
    (2025, SolarEvent.marchEquinox): (3, 20, 9, 1),
    (2025, SolarEvent.juneSolstice): (6, 21, 2, 42),
    (2025, SolarEvent.septemberEquinox): (9, 22, 18, 19),
    (2025, SolarEvent.decemberSolstice): (12, 21, 15, 3),
    (2026, SolarEvent.marchEquinox): (3, 20, 14, 46),
    (2026, SolarEvent.juneSolstice): (6, 21, 8, 24),
    (2026, SolarEvent.septemberEquinox): (9, 23, 0, 5),
    (2026, SolarEvent.decemberSolstice): (12, 21, 20, 50),
    (2027, SolarEvent.marchEquinox): (3, 20, 20, 25),
    (2027, SolarEvent.juneSolstice): (6, 21, 14, 11),
    (2027, SolarEvent.septemberEquinox): (9, 23, 6, 2),
    (2027, SolarEvent.decemberSolstice): (12, 22, 2, 42),
    (2028, SolarEvent.marchEquinox): (3, 20, 2, 17),
    (2028, SolarEvent.juneSolstice): (6, 20, 20, 2),
    (2028, SolarEvent.septemberEquinox): (9, 22, 11, 45),
    (2028, SolarEvent.decemberSolstice): (12, 21, 8, 19),
    (2029, SolarEvent.marchEquinox): (3, 20, 8, 1),
    (2029, SolarEvent.juneSolstice): (6, 21, 1, 48),
    (2029, SolarEvent.septemberEquinox): (9, 22, 17, 38),
    (2029, SolarEvent.decemberSolstice): (12, 21, 14, 14),
    (2030, SolarEvent.marchEquinox): (3, 20, 13, 51),
    (2030, SolarEvent.juneSolstice): (6, 21, 7, 31),
    (2030, SolarEvent.septemberEquinox): (9, 22, 23, 27),
    (2030, SolarEvent.decemberSolstice): (12, 21, 20, 9),
  };

  group('الاعتدالان والانقلابان 2025–2030 مقابل USNO (±2 دقيقة)', () {
    usno.forEach((key, value) {
      final (year, event) = key;
      final (m, d, h, min) = value;
      test('$year ${event.name}', () {
        final expected = DateTime.utc(year, m, d, h, min);
        final actual = seasonEventUtc(year, event);
        expect(
          actual.difference(expected).inSeconds.abs(),
          lessThanOrEqualTo(120),
          reason: 'المحسوب $actual والمنشور $expected',
        );
      });
    });
  });

  group('يوم البداية بالتوقيت المحلي (R3.2)', () {
    const riyadh = Duration(hours: 3);
    const dubai = Duration(hours: 4);

    test('قيم 2026 في جدول R3.2 للرياض', () {
      final y = AstroYear.compute(2026, utcOffset: riyadh);
      DateTime startOf(AstroSeason s) => y.seasons
          .firstWhere((p) => p.value == s && p.start.day.year == 2026)
          .start
          .day;
      expect(startOf(AstroSeason.spring), DateTime(2026, 3, 20));
      expect(startOf(AstroSeason.summer), DateTime(2026, 6, 21));
      expect(startOf(AstroSeason.autumn), DateTime(2026, 9, 23));
      expect(startOf(AstroSeason.winter), DateTime(2026, 12, 21));
    });

    test('الانقلاب الشتوي 2026: 21 ديسمبر في الرياض و22 في دبي', () {
      final instant = seasonEventUtc(2026, SolarEvent.decemberSolstice);
      expect(localDateOf(instant, utcOffset: riyadh), DateTime(2026, 12, 21));
      expect(localDateOf(instant, utcOffset: dubai), DateTime(2026, 12, 22));
      final r = AstroYear.compute(2026, utcOffset: riyadh);
      final d = AstroYear.compute(2026, utcOffset: dubai);
      expect(r.seasonAt(DateTime(2026, 12, 21)).value, AstroSeason.winter);
      expect(d.seasonAt(DateTime(2026, 12, 21)).value, AstroSeason.autumn);
      expect(d.seasonAt(DateTime(2026, 12, 22)).value, AstroSeason.winter);
    });

    test('يوم الحدث أول أيام الفصل الجديد', () {
      final y = AstroYear.compute(2026, utcOffset: riyadh);
      expect(y.seasonAt(DateTime(2026, 9, 22)).value, AstroSeason.summer);
      expect(y.seasonAt(DateTime(2026, 9, 23)).value, AstroSeason.autumn);
    });

    test('الفصول تغطي السنة بلا فجوة، وطول كل فصل 88–95 يوماً', () {
      for (var year = 2025; year <= 2040; year++) {
        final y = AstroYear.compute(year, utcOffset: riyadh);
        for (var i = 1; i < y.seasons.length; i++) {
          expect(y.seasons[i].start.day, y.seasons[i - 1].end.day);
        }
        for (final p in y.seasons.sublist(1, 4)) {
          expect(p.days, inInclusiveRange(88, 95), reason: '$year ${p.value}');
        }
        for (
          var d = DateTime(year);
          d.year == year;
          d = DateTime(d.year, d.month, d.day + 1)
        ) {
          expect(() => y.seasonAt(d), returnsNormally);
          expect(() => y.zodiacAt(d), returnsNormally);
        }
      }
    });

    test('مثال R3.2: الخريف 2026 مدته ٨٩ يوماً، ومضى ١٤ يوماً في 7 أكتوبر', () {
      final y = AstroYear.compute(2026, utcOffset: riyadh);
      final autumn = y.seasonAt(DateTime(2026, 10, 7));
      expect(autumn.value, AstroSeason.autumn);
      expect(autumn.days, 89);
      expect(
        DateTime.utc(2026, 10, 7).difference(DateTime.utc(2026, 9, 23)).inDays,
        14,
      );
    });
  });

  group('البروج (R3.1-10، R3.7-4)', () {
    test('بداية الحمل يوم الاعتدال الربيعي، والجدي يوم الانقلاب الشتوي', () {
      for (var year = 2025; year <= 2040; year++) {
        for (final offset in const [Duration(hours: 3), Duration(hours: 4)]) {
          final y = AstroYear.compute(year, utcOffset: offset);
          AstroPeriod<T> first<T>(List<AstroPeriod<T>> list, T v) =>
              list.firstWhere((p) => p.value == v && p.start.day.year == year);
          expect(
            first(y.zodiac, ZodiacSign.aries).start.day,
            first(y.seasons, AstroSeason.spring).start.day,
          );
          expect(
            first(y.zodiac, ZodiacSign.cancer).start.day,
            first(y.seasons, AstroSeason.summer).start.day,
          );
          expect(
            first(y.zodiac, ZodiacSign.libra).start.day,
            first(y.seasons, AstroSeason.autumn).start.day,
          );
          expect(
            first(y.zodiac, ZodiacSign.capricorn).start.day,
            first(y.seasons, AstroSeason.winter).start.day,
          );
        }
      }
    });

    test('بدايات البروج 2026 قريبة من PyEphem (±30 دقيقة)', () {
      // PyEphem 4: طول الشمس على دائرة البروج لتاريخه (UTC). فرق منهجي نحو
      // 6 دقائق (الزيغ)، فالسماح 30 دقيقة، ويكفي لليوم.
      final reference = <ZodiacSign, DateTime>{
        ZodiacSign.aquarius: DateTime.utc(2026, 1, 20, 1, 39),
        ZodiacSign.pisces: DateTime.utc(2026, 2, 18, 15, 46),
        ZodiacSign.taurus: DateTime.utc(2026, 4, 20, 1, 33),
        ZodiacSign.gemini: DateTime.utc(2026, 5, 21, 0, 31),
        ZodiacSign.leo: DateTime.utc(2026, 7, 22, 19, 8),
        ZodiacSign.virgo: DateTime.utc(2026, 8, 23, 2, 14),
        ZodiacSign.scorpio: DateTime.utc(2026, 10, 23, 9, 33),
        ZodiacSign.sagittarius: DateTime.utc(2026, 11, 22, 7, 18),
      };
      final y = AstroYear.compute(2026, utcOffset: Duration.zero);
      reference.forEach((sign, expected) {
        final p = y.zodiac.firstWhere(
          (p) => p.value == sign && p.start.instant.year == 2026,
        );
        expect(
          p.start.instant.difference(expected).inMinutes.abs(),
          lessThanOrEqualTo(30),
          reason: '${sign.name}: ${p.start.instant} مقابل $expected',
        );
      });
    });

    test('7 أكتوبر 2026: الشمس في برج الميزان', () {
      final y = AstroYear.compute(2026, utcOffset: const Duration(hours: 3));
      expect(y.zodiacAt(DateTime(2026, 10, 7)).value, ZodiacSign.libra);
      expect(y.zodiac.length, 13);
    });
  });

  group('بديل فشل الحساب (R3.4، SPEC 19.10)', () {
    for (final year in [2026, 2028]) {
      test('$year: أرباع متساوية من 21 ديسمبر، بلا بروج، computed = false', () {
        final y = AstroYear.fallback(year);
        expect(y.computed, isFalse);
        expect(y.zodiac, isEmpty);
        expect(y.seasons.map((p) => p.value), [
          AstroSeason.winter,
          AstroSeason.spring,
          AstroSeason.summer,
          AstroSeason.autumn,
          AstroSeason.winter,
        ]);
        expect(y.seasons[0].start.day, DateTime(year - 1, 12, 21));
        expect(y.seasons[4].start.day, DateTime(year, 12, 21));
        // متصلة بلا فجوة، وكل ربع 91–92 يوماً، فالصليب على المحورين.
        for (var i = 0; i < 4; i++) {
          expect(y.seasons[i].end.day, y.seasons[i + 1].start.day);
          expect(y.seasons[i].days, inInclusiveRange(91, 92));
        }
        for (
          var d = DateTime(year);
          d.year == year;
          d = DateTime(d.year, d.month, d.day + 1)
        ) {
          expect(() => y.seasonAt(d), returnsNormally);
        }
      });
    }

    test('الحساب السليم: computeOrFallback يعيد المحسوب', () {
      final y = AstroYear.computeOrFallback(2026);
      expect(y.computed, isTrue);
      expect(y.zodiac, isNotEmpty);
    });
  });
}
