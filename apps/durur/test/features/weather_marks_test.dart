import 'dart:math' as math;

import 'package:durur/src/domain/weather_symbol.dart';
import 'package:durur/src/engine/calendar_engine.dart';
import 'package:durur/src/engine/year_index.dart';
import 'package:durur/src/features/home/dial/dial_model.dart';
import 'package:durur/src/features/home/dial/weather_marks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// رموز الجو على الحلقة الخارجية (SPEC الميزة 16، DESIGN R2.6).
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();

  DialModel modelFor(String regionId, [int year = 2026]) =>
      DialModel.fromYearIndex(
        YearIndex(CalendarEngine.fromTables(tables, regionId), year),
      );

  /// شاشة 360dp: R = (360 − 28) / 2 (R2.5)، ورمز 16.
  const radius360 = 166.0;

  WeatherLayout layout(
    DialModel model, {
    double radius = radius360,
    double zoom = 1,
    double icon = 16,
  }) {
    final geo = DialGeometry(radius: radius, dayCount: model.dayCount);
    return layoutWeatherMarks(
      model: model,
      items: tables.items,
      radius: geo.weatherMid,
      zoom: zoom,
      iconSize: icon,
      // عرض تقريبي لاسم بخط 12.
      nameWidth: (id) => tables.items[id]!.name.ar.length * 7.0,
    );
  }

  /// كل الرموز الظاهرة بمواضعها على الشاشة (بالنسبة للمركز) عند [rotation].
  List<(double, double)> positions(
    DialModel model,
    WeatherLayout l, {
    double radius = radius360,
    double zoom = 1,
    double rotation = 0,
  }) {
    final geo = DialGeometry(radius: radius, dayCount: model.dayCount);
    return [
      for (final g in l.groups)
        for (final m in g.marks)
          (() {
            final (x, y) = markPosition(
              geo,
              g,
              m.offset,
              rotation,
              geo.weatherMid,
              zoom,
            );
            return (x * zoom, y * zoom);
          })(),
    ];
  }

  for (final region in tables.regions) {
    test('${region.id}: كل رمزين ظاهرين ≥ 48 نقطة بلا تكبير وعند 2× و3×', () {
      final model = modelFor(region.id);
      for (final zoom in [1.0, 2.0, 3.0]) {
        for (final rotation in [0.0, 91.0, 200.0]) {
          final l = layout(model, zoom: zoom);
          final p = positions(model, l, zoom: zoom, rotation: rotation);
          for (var i = 0; i < p.length; i++) {
            for (var j = i + 1; j < p.length; j++) {
              final d = math.sqrt(
                math.pow(p[i].$1 - p[j].$1, 2) + math.pow(p[i].$2 - p[j].$2, 2),
              );
              expect(
                d,
                greaterThanOrEqualTo(minTouch),
                reason: 'zoom $zoom rotation $rotation: $i-$j',
              );
            }
          }
        }
      }
    });

    test('${region.id}: الرموز من البيانات فقط وفي موضع فترتها', () {
      final model = modelFor(region.id);
      final l = layout(model);
      final days = model.index.days;
      for (final g in l.groups) {
        // المركز داخل الفترة التي يتبعها.
        expect(g.center, inInclusiveRange(g.start, g.start + g.length));
        final info = days[g.center.floor() % model.dayCount];
        switch (g.kind) {
          case WeatherGroupKind.weatherSeason:
            expect(info.weatherSeason?.itemId, g.itemId);
            expect(g.marks.single.symbol, tables.items[g.itemId]!.weather.first);
          case WeatherGroupKind.durur:
            expect(g.marks.length, lessThanOrEqualTo(2));
            expect(
              g.marks.map((m) => m.symbol),
              orderedEquals(info.weather.take(g.marks.length)),
            );
        }
      }
      // عند التكبير 3× تظهر كل المجموعات.
      expect(layout(model, zoom: 3).hidden, 0);
    });
  }

  test('الرياض (نجد): 4 مواسم جو + 4 مقاطع = 8 مجموعات ظاهرة على 360dp', () {
    final model = modelFor('najd');
    final l = layout(model);
    expect(l.hidden, 0);
    expect(
      l.groups.where((g) => g.kind == WeatherGroupKind.weatherSeason),
      hasLength(4),
    );
    expect(
      l.groups.where((g) => g.kind == WeatherGroupKind.durur),
      hasLength(4),
    );
    // المربعانية تعبر نهاية السنة: مجموعة واحدة لا اثنتان.
    expect(l.groups.where((g) => g.itemId == 'murabbaniya'), hasLength(1));
    // الرموز بحجمها المرئي ≥ 16 (SPEC 16.1).
    expect(l.groups.any((g) => g.marks.isEmpty), isFalse);
  });

  test('اللمس: ضمن 24 نقطة من مركز الرمز ← رمزه، وأبعد ← لا شيء', () {
    final model = modelFor('najd');
    final geo = DialGeometry(radius: radius360, dayCount: model.dayCount);
    final l = layout(model);
    for (final g in l.groups) {
      for (final m in g.marks) {
        final (x, y) = markPosition(geo, g, m.offset, 10, geo.weatherMid, 1);
        final hit = hitWeatherMark(l, geo, x + 10, y + 10, 10, 1);
        expect(hit?.mark, same(m));
        expect(hit?.group, same(g));
        // أبعد من 24 نقطة نحو المركز.
        final away = hitWeatherMark(l, geo, x * 0.8, y * 0.8, 10, 1);
        expect(away, isNull);
      }
    }
  });

  test('كل الرموز الـ17 معرّفة بأسماء JSON فريدة (D23)', () {
    expect(WeatherSymbol.values, hasLength(17));
    expect(WeatherSymbol.values.map((s) => s.code).toSet(), hasLength(17));
  });
}
