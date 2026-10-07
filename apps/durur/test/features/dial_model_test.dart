import 'dart:math' as math;

import 'package:durur/src/astronomy/seasons.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:durur/src/features/home/dial/dial_model.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// نموذج الدائرة وهندستها (DESIGN R3.1-3/4، R3.10، D41).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  DialModel modelFor(String regionId, int year) => DialModel.fromYearIndex(
    YearIndex(CalendarEngine.fromTables(tables, regionId), year),
    astro: AstroYear.compute(year, utcOffset: const Duration(hours: 3)),
    items: tables.items,
  );

  void expectFullCover(List<DialSegment> segs, int days) {
    expect(segs.first.start, 0);
    expect(segs.last.end, days);
    for (var i = 1; i < segs.length; i++) {
      expect(segs[i].start, segs[i - 1].end, reason: 'فجوة أو تداخل');
    }
  }

  for (final region in tables.regions) {
    test('الحلقات كاملة بلا فجوات: ${region.id}', () {
      for (final year in [2026, 2028]) {
        final model = modelFor(region.id, year);
        final index = model.index;
        expect(model.months, hasLength(12));
        expect(
          model.months.map((m) => m.length).reduce((a, b) => a + b),
          index.length,
        );
        expect(model.months[1].length, year == 2028 ? 29 : 28);
        expect(model.hasDurur, region.id != 'najd');
        for (final ring in [
          DialRing.months,
          DialRing.seasons,
          DialRing.zodiac,
          DialRing.stars,
          if (model.hasDurur) DialRing.durur,
        ]) {
          expectFullCover(model.segments(ring), index.length);
        }
        if (!model.hasDurur) expect(model.segments(DialRing.durur), isEmpty);
        for (var d = 0; d < index.length; d++) {
          final info = index.days[d];
          expect(model.segmentAt(DialRing.durur, d)?.dar, info.dar?.record);
          expect(
            model.segmentAt(DialRing.weather, d)?.itemId,
            info.weatherSeason?.itemId,
          );
          expect(model.segmentAt(DialRing.stars, d)!.itemId, info.star.itemId);
          // خلية الإطار: الدَّرّ، أو الطالع بلا درور (R3.10).
          final cell = model.cellAt(d)!;
          if (model.hasDurur) {
            expect(cell.dar, same(info.dar!.record));
            expect(cell.symbol, info.dar!.record.weather.firstOrNull);
          } else {
            expect(cell.starItemId, info.star.itemId);
            expect(cell.symbol, tables.items[info.star.itemId]!.weather.first);
          }
        }
        // الدرور بلون مئتها (D25).
        for (final s in model.segments(DialRing.durur)) {
          expect(s.colorSeasonId, s.dar!.seasonId);
        }
        // الفصول الأربعة والبروج الاثنا عشر بعد دمج نهاية السنة.
        expect(model.cyclicSegments(DialRing.seasons), hasLength(4));
        expect(model.cyclicSegments(DialRing.zodiac), hasLength(12));
      }
    });
  }

  test('خلايا الإطار: خلية لكل دَرّ (≈37) أو لكل طالع بلا درور', () {
    final gulf = modelFor('uae_oman', 2026);
    expect(
      gulf.cells.length,
      tables.regionTables['uae_oman']!.durur.length,
    );
    final najd = modelFor('najd', 2026);
    expect(najd.cells.length, tables.regionTables['najd']!.stars.length);
  });

  test('الاسم التراثي للفصل: الموسم الكبير في منتصفه (R3.2)', () {
    final model = modelFor('kuwait', 2026);
    String? heritage(AstroSeason s) => model.heritageFor(
      model.cyclicSegments(DialRing.seasons).firstWhere(
        (seg) => seg.astroSeason == s,
      ),
    );
    final mid = (AstroSeason s) {
      final p = model.astro.seasons.firstWhere(
        (p) => p.value == s && p.start.day.year == 2026,
      );
      return DateTime(
        p.start.day.year,
        p.start.day.month,
        p.start.day.day + p.days ~/ 2,
      );
    };
    final engine = CalendarEngine.fromTables(tables, 'kuwait');
    for (final s in [
      AstroSeason.spring,
      AstroSeason.summer,
      AstroSeason.autumn,
    ]) {
      expect(heritage(s), engine.resolve(mid(s)).majorSeason.itemId);
    }
  });

  group('الهندسة واللمس (R3.1-3 و4)', () {
    // 2026: 21 ديسمبر فهرسه 354.
    const geo = DialGeometry(radius: 200, dayCount: 365, anchor: 354);

    test('الحلقات السبع بنسب R3.1-4 بلا فجوات', () {
      expect(geo.rings, [
        DialRing.weather,
        DialRing.months,
        DialRing.days,
        DialRing.durur,
        DialRing.stars,
        DialRing.zodiac,
        DialRing.seasons,
      ]);
      expect(geo.band(DialRing.weather).$1, 200.0);
      expect(geo.band(DialRing.weather).$2, closeTo(176, 1e-9));
      expect(geo.band(DialRing.months).$2, closeTo(152, 1e-9));
      expect(geo.band(DialRing.days).$2, closeTo(138, 1e-9));
      expect(geo.band(DialRing.durur).$2, closeTo(98, 1e-9));
      expect(geo.band(DialRing.stars).$2, closeTo(84, 1e-9));
      expect(geo.band(DialRing.zodiac).$2, closeTo(68, 1e-9));
      expect(geo.band(DialRing.seasons).$2, closeTo(14, 1e-9));
      expect(geo.hubRadius, closeTo(14, 1e-9));
      final rings = geo.rings;
      for (var i = 1; i < rings.length; i++) {
        expect(
          geo.band(rings[i]).$1,
          closeTo(geo.band(rings[i - 1]).$2, 1e-9),
        );
      }
    });

    test('بلا درور (R3.10): الطوالع مكان الدرور، والبروج والمركز أوسع', () {
      const saudi = DialGeometry(
        radius: 200,
        dayCount: 365,
        anchor: 354,
        hasDurur: false,
      );
      expect(saudi.rings, isNot(contains(DialRing.durur)));
      expect(saudi.band(DialRing.stars).$1, closeTo(138, 1e-9));
      expect(saudi.band(DialRing.stars).$2, closeTo(102, 1e-9));
      expect(saudi.band(DialRing.zodiac).$2, closeTo(80, 1e-9));
      expect(saudi.band(DialRing.seasons).$2, closeTo(14, 1e-9));
    });

    test('21 ديسمبر عند الساعة 6، و20 مارس عند 3، و21 يونيو عند 12', () {
      // الزاوية مع عقارب الساعة من الأعلى: 6 = π، 3 = π/2، 12 = 0.
      expect(geo.centerAngle(354), closeTo(math.pi, 1e-12));
      double norm(double a) => (a % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
      expect(norm(geo.centerAngle(78)), closeTo(math.pi / 2, 3 * math.pi / 180));
      expect(norm(geo.centerAngle(171)), closeTo(0, 3 * math.pi / 180));
      expect(
        norm(geo.centerAngle(265)),
        closeTo(3 * math.pi / 2, 3 * math.pi / 180),
      );
      expect(geo.step * 365, closeTo(2 * math.pi, 1e-9));
    });

    test('الزمن عكس عقارب الساعة، واللمس يعيد اليوم نفسه', () {
      expect(geo.centerAngle(101), lessThan(geo.centerAngle(100)));
      for (final day in [0, 78, 171, 274, 354, 364]) {
        final (x, y) = DialGeometry.polar(geo.centerAngle(day), 120);
        final hit = geo.hitTest(x, y)! as RingHit;
        expect(hit.ring, DialRing.durur);
        expect(hit.day, day);
      }
      // 31 ديسمبر ثم 1 يناير متجاوران بلا قفزة.
      expect(
        (geo.angleOf(365) - geo.angleOf(0)) % (2 * math.pi),
        closeTo(0, 1e-9),
      );
    });

    test('كل حلقة تُصاب في مداها', () {
      for (final (ring, r) in [
        (DialRing.weather, 190.0),
        (DialRing.months, 160.0),
        (DialRing.days, 145.0),
        (DialRing.durur, 120.0),
        (DialRing.stars, 90.0),
        (DialRing.zodiac, 75.0),
        (DialRing.seasons, 40.0),
      ]) {
        final hit = geo.hitTest(0, -r)! as RingHit;
        expect(hit.ring, ring);
      }
    });

    test('المحور (لمس 48dp) وخارج الدائرة', () {
      expect(geo.hitTest(0, 0), isA<HubHit>());
      expect(geo.hitTest(15, 15), isA<HubHit>());
      expect(geo.hitTest(201, 0), isNull);
    });
  });

  test('القطع العابرة لنهاية السنة تُدمج في قطعة دائرية واحدة', () {
    final model = modelFor('najd', 2026);
    final cyc = model.cyclicSegments(DialRing.weather);
    final murabbaniya = cyc.where((s) => s.itemId == 'murabbaniya').single;
    expect(murabbaniya.end, greaterThan(model.dayCount));
    final winter = model
        .cyclicSegments(DialRing.seasons)
        .where((s) => s.astroSeason == AstroSeason.winter)
        .single;
    expect(winter.end, greaterThan(model.dayCount));
    for (final ring in [DialRing.stars, DialRing.seasons, DialRing.zodiac]) {
      expect(
        model.cyclicSegments(ring).fold<int>(0, (a, s) => a + s.length),
        model.dayCount,
      );
    }
  });

  test(
    'الأداء: تحميل الجداول وبناء سنة الدائرة أقل بكثير من ثانيتين',
    () async {
      final watch = Stopwatch()..start();
      final loaded = await TablesLoader((p) async => readAsset(p)).load();
      final model = DialModel.fromYearIndex(
        YearIndex(CalendarEngine.fromTables(loaded, 'najd'), 2026),
        astro: AstroYear.compute(2026),
        items: loaded.items,
      );
      watch.stop();
      expect(model.dayCount, 365);
      expect(watch.elapsedMilliseconds, lessThan(1000));
    },
  );
}
