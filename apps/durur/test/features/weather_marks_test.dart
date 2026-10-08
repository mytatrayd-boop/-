import 'package:durur/src/astronomy/seasons.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:durur/src/features/home/dial/dial_model.dart';
import 'package:durur/src/features/home/dial/weather_marks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// الإطار الخارجي A (DESIGN R3.1-5، الميزة 16): رمز لكل خلية، وأسماء
/// مواسم الجو تُخفي الرموز تحتها، والخلايا لا تتداخل وكل منها ≥ 24dp.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  DialModel modelFor(String regionId, [int year = 2026]) =>
      DialModel.fromYearIndex(
        YearIndex(CalendarEngine.fromTables(tables, regionId), year),
        astro: AstroYear.compute(year, utcOffset: const Duration(hours: 4)),
        items: tables.items,
      );

  // شاشة 412dp: R = (412 − 16) / 2 (R3.1-2).
  const radius412 = 198.0;
  const radius360 = 172.0;

  FrameLayout layout(DialModel model, double radius, {bool names = true}) {
    final geo = DialGeometry.of(model, radius);
    return layoutFrame(
      model: model,
      radius: geo.weatherMid,
      // عرض تقريبي لاسم بخط 11.
      nameWidth: (id) => names ? tables.items[id]!.name.ar.length * 6.5 : null,
    );
  }

  test('بلا أسماء: رمز لكل خلية (≈37 للخليج)', () {
    final model = modelFor('uae_oman');
    final l = layout(model, radius412, names: false);
    expect(l.names, isEmpty);
    expect(l.marks, hasLength(model.cells.where((c) => c.symbol != null).length));
    expect(model.cells.length, greaterThanOrEqualTo(36));
  });

  test('الأسماء تُخفي الرموز تحتها فقط، ومنتصف الاسم منتصف موسمه', () {
    final model = modelFor('uae_oman');
    final l = layout(model, radius412);
    expect(l.names, isNotEmpty);
    for (final m in l.marks) {
      for (final n in l.names) {
        expect(n.covers(m.center, model.dayCount), isFalse);
      }
    }
    final hidden = model.cells.length - l.marks.length;
    expect(hidden, greaterThan(0));
    expect(hidden, lessThan(model.cells.length ~/ 2));
    for (final n in l.names) {
      final s = model
          .cyclicSegments(DialRing.weather)
          .firstWhere((s) => s.itemId == n.itemId);
      expect(n.center, s.start + s.length / 2);
    }
  });

  test('الخلايا لا تتداخل، وكل خلية ≥ 24dp على 360 و412 (D41)', () {
    for (final radius in [radius360, radius412]) {
      final model = modelFor('uae_oman');
      final geo = DialGeometry.of(model, radius);
      final (o, i) = geo.band(DialRing.weather);
      expect(o - i, greaterThanOrEqualTo(20.6)); // 0.12R
      final cells = [...model.cells]..sort((a, b) => a.start.compareTo(b.start));
      for (var k = 1; k < cells.length; k++) {
        expect(cells[k].start, greaterThanOrEqualTo(cells[k - 1].end));
      }
      for (final c in cells) {
        // سجل الأيام الخمسة (10–14 أغسطس) في المسودة بلا رقم ولا اسم ينتظر
        // قرار المراجع (D25)؛ الدرور العادية 9 أيام فأكثر.
        if (c.length < 9) continue;
        // طول القوس عند منتصف الإطار.
        final arc = c.length * geo.step * geo.weatherMid;
        expect(arc, greaterThanOrEqualTo(24), reason: 'خلية ${c.start}');
      }
    }
  });

  test('بلا درور (R3.10): خلية لكل طالع برمزه الأول', () {
    final model = modelFor('najd');
    final l = layout(model, radius412, names: false);
    expect(model.cells.length, tables.regionTables['najd']!.stars.length);
    for (final m in l.marks) {
      expect(m.cell.dar, isNull);
      expect(m.symbol, tables.items[m.cell.starItemId]!.weather.first);
    }
  });

  test('أرقام الأشهر تُخفي الرموز في مداها', () {
    final model = modelFor('uae_oman');
    final geo = DialGeometry.of(model, radius412);
    final all = layoutFrame(
      model: model,
      radius: geo.weatherMid,
      nameWidth: (_) => null,
    );
    final blocked = layoutFrame(
      model: model,
      radius: geo.weatherMid,
      nameWidth: (_) => null,
      blocked: [(all.marks.first.center, 0.5)],
    );
    expect(blocked.marks.length, all.marks.length - 1);
  });
}
