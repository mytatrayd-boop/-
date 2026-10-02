import 'dart:math' as math;

import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:durur/src/features/home/dial/dial_model.dart';
import 'package:durur/src/repository/tables_loader.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// نموذج الدائرة وهندستها (SPEC 6.3، DESIGN 7.2–7.4).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

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
        final index = YearIndex(
          CalendarEngine.fromTables(tables, region.id),
          year,
        );
        final model = DialModel.fromYearIndex(index);
        expect(model.months, hasLength(12));
        expect(
          model.months.map((m) => m.length).reduce((a, b) => a + b),
          index.length,
        );
        expect(model.months[1].length, year == 2028 ? 29 : 28);
        for (final ring in [
          DialRing.months,
          DialRing.seasons,
          DialRing.durur,
          DialRing.stars,
        ]) {
          expectFullCover(model.segments(ring), index.length);
        }
        // كل يوم في قطعة الدَّرّ الصحيحة، ومواسم الجو فقط حيث توجد.
        for (var d = 0; d < index.length; d++) {
          final info = index.days[d];
          expect(
            model.segmentAt(DialRing.durur, d)!.dar,
            same(info.dar.record),
          );
          expect(
            model.segmentAt(DialRing.weather, d)?.itemId,
            info.weatherSeason?.itemId,
          );
          expect(
            model.segmentAt(DialRing.seasons, d)!.itemId,
            info.majorSeason.itemId,
          );
          expect(model.segmentAt(DialRing.stars, d)!.itemId, info.star.itemId);
        }
        // الدرور بلون مئتها (D25).
        for (final s in model.segments(DialRing.durur)) {
          expect(s.colorSeasonId, s.dar!.seasonId);
        }
      }
    });
  }

  group('الهندسة واللمس', () {
    const geo = DialGeometry(radius: 170, dayCount: 365);

    test('أنصاف أقطار الحلقات تتناسب مع القطر', () {
      const small = DialGeometry(radius: 144, dayCount: 365);
      expect(small.band(DialRing.months), (144.0, 146 / 170 * 144));
      expect(small.hubRadius, closeTo(58 / 170 * 144, 1e-9));
    });

    test('أعلى الدائرة = اليوم المعروض في كل حلقة', () {
      for (final (ring, r) in [
        (DialRing.months, 160.0),
        (DialRing.seasons, 138.0),
        (DialRing.durur, 116.0),
        (DialRing.stars, 90.0),
        (DialRing.weather, 70.0),
      ]) {
        final hit = geo.hitTest(0, -r, 274)! as RingHit;
        expect(hit.ring, ring);
        expect(hit.day, 274);
      }
    });

    test('الزمن مع عقارب الساعة: يمين المؤشر = أيام قادمة', () {
      // ربع دورة مع عقارب الساعة (يمين المركز) ≈ 91 يوماً بعد المعروض.
      final right = geo.hitTest(116, 0, 10)! as RingHit;
      expect(right.day, 10 + 91);
      final left = geo.hitTest(-116, 0, 10)! as RingHit;
      expect(left.day, (10 - 91) % 365);
      // التفاف عبر نهاية السنة.
      final wrap = geo.hitTest(0, -116, 364.6)! as RingHit;
      expect(wrap.day, 0);
    });

    test('المحور وخارج الدائرة', () {
      expect(geo.hitTest(0, 0, 0), isA<HubHit>());
      expect(geo.hitTest(30, 30, 0), isA<HubHit>());
      expect(geo.hitTest(171, 0, 0), isNull);
    });

    test('زاوية اليوم: اليوم المعروض متمركز تحت المؤشر', () {
      expect(geo.angleOf(100, 100), closeTo(-geo.step / 2, 1e-12));
      expect(geo.angleOf(101, 100), closeTo(geo.step / 2, 1e-12));
      expect(geo.step * 365, closeTo(2 * math.pi, 1e-9));
    });
  });

  test(
    'الأداء: تحميل الجداول وبناء سنة الدائرة أقل بكثير من ثانيتين',
    () async {
      final watch = Stopwatch()..start();
      final loaded = await TablesLoader((p) async => readAsset(p)).load();
      final model = DialModel.fromYearIndex(
        YearIndex(CalendarEngine.fromTables(loaded, 'najd'), 2026),
      );
      watch.stop();
      expect(model.dayCount, 365);
      // المعيار 6.1 (ثانيتان) على الجهاز؛ هنا حد أعلى للحساب وحده.
      expect(watch.elapsedMilliseconds, lessThan(1000));
    },
  );
}
