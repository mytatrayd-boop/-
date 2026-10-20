import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/widget_layout.dart';

/// الحالات نفسها في LamhaLogicTest.kt (packRowsCases وrowHeightsCases).
List<List<String>> shape(List<GridCell> cells) => [
      for (final r in packRows(cells)) [for (final c in r) '${c.id}${c.span}'],
    ];

List<GridCell> cells(String spec) => [
      for (final p in spec.split(' '))
        (id: p.substring(0, p.length - 1), span: int.parse(p.substring(p.length - 1))),
    ];

void main() {
  group('packRows', () {
    test('الترتيب الافتراضي = الشكل السابق (المدينة تحت التاريخين)', () {
      expect(
        shape(stackCells([
          for (final t in defaultLayout) (id: t.id.name, span: t.span),
        ])),
        [
          ['clock1', 'dates+weather2'],
          ['prayer1', 'qibla1', 'deposit1'],
          ['season1', 'tradSeason2'],
        ],
      );
      expect(cellElements('dates+weather'), ['dates', 'weather']);
    });

    test('stackCells: الطقس بعد التاريخين مباشرة وبعرضهما فقط', () {
      expect(shape(stackCells(cells('dates2 weather1 qibla1'))), [
        ['dates2', 'weather1'],
        ['qibla3'],
      ]);
      expect(shape(stackCells(cells('weather2 dates2'))), [
        ['weather3'],
        ['dates3'],
      ]);
      expect(shape(stackCells(cells('dates3 weather3 prayer1'))), [
        ['dates+weather3'],
        ['prayer3'],
      ]);
    });

    test('آخر مربع في الصف الناقص يتمدد', () {
      expect(shape(cells('a1 b1 c1 d1')), [
        ['a1', 'b1', 'c1'],
        ['d3'],
      ]);
      expect(shape(cells('a1 b1')), [
        ['a1', 'b2'],
      ]);
    });

    test('ما لا يتسع يلتف إلى صف جديد، والصف الذي قبله يمتلئ', () {
      expect(shape(cells('a2 b2 c1')), [
        ['a3'],
        ['b2', 'c1'],
      ]);
    });

    test('حد خمسة صفوف: ما بعدها لا يظهر', () {
      expect(shape(cells('a3 b3 c3 d3 e3 f1')), [
        ['a3'],
        ['b3'],
        ['c3'],
        ['d3'],
        ['e3'],
      ]);
      expect(shape(cells('a3 b3 c3 d3 e2 f1 g1')), [
        ['a3'],
        ['b3'],
        ['c3'],
        ['d3'],
        ['e2', 'f1'],
      ]);
    });

    test('بلا مربعات، والعرض خارج ١–٣ يُقصر', () {
      expect(shape(const []), isEmpty);
      expect(shape(cells('a5')), [
        ['a3'],
      ]);
      expect(shape(cells('a0 b1')), [
        ['a1', 'b2'],
      ]);
    });

    test('ترتيب مخصص: الصلاة بعرض ٣ في الأعلى، والساعة بعرض ١', () {
      expect(shape(cells('prayer3 clock1 dates2 weather1 qibla1 deposit1')), [
        ['prayer3'],
        ['clock1', 'dates2'],
        ['weather1', 'qibla1', 'deposit1'],
      ]);
    });
  });

  group('rowHeights', () {
    test('يتسع: المعامل ١ والباقي يوزع بنسبة كل صف', () {
      final r = rowHeights([80, 20, 100], [0, 0, 20], 300, 8);
      expect(r.scale, 1);
      final k = 284 / 220;
      expect(r.heights[0], closeTo(80 * k, 1e-9));
      expect(r.heights[1], closeTo(20 * k, 1e-9));
      expect(r.heights[2], closeTo(120 * k, 1e-9));
    });

    test('لا يتسع: معامل واحد يصغر النص، والحشوات كما هي', () {
      final r = rowHeights([80, 20, 100], [0, 0, 20], 200, 8);
      expect(r.scale, closeTo(0.82, 1e-9));
      expect(r.heights[0], closeTo(65.6, 1e-9));
      expect(r.heights[2], closeTo(102, 1e-9));
      expect(r.heights.reduce((a, b) => a + b), closeTo(184, 1e-9));
    });

    test('حد أدنى ٠٫٦، وبلا ارتفاع معروف: الطبيعي', () {
      expect(rowHeights([80, 20, 100], [0, 0, 20], 50, 8).scale, 0.6);
      final n = rowHeights([80, 20], [4, 4], 0, 8);
      expect(n.scale, 1);
      expect(n.heights, [84, 24]);
      expect(rowHeights(const [], const [], 300, 8).heights, isEmpty);
    });

    test('صفوف السطور بقدر محتواها، وصفوف المربعات تقتسم الباقي بالتساوي', () {
      final a = rowHeights([80, 20, 100], [0, 0, 20], 300, 0,
          flexible: [false, false, true]);
      expect(a.scale, 1);
      expect(a.heights, [80, 20, 200]);
      final b = rowHeights([50, 60, 70], [0, 20, 20], 300, 0,
          flexible: [false, true, true]);
      expect(b.heights, [50, 125, 125]);
      // لا يتسع بأدنى معامل: النقص من صفوف المربعات بنسبتها.
      final c = rowHeights([80, 20, 100], [0, 0, 20], 120, 0,
          flexible: [false, false, true]);
      expect(c.scale, 0.6);
      expect(c.heights[0], closeTo(48, 1e-9));
      expect(c.heights[1], closeTo(12, 1e-9));
      expect(c.heights[2], closeTo(60, 1e-9));
    });

    test('صفوف متساوية (أندرويد أقدم من ١٢): المعامل من أضيقها', () {
      final r = rowHeights([80, 20, 100], [0, 0, 20], 300, 0, equal: true);
      expect(r.heights, [100, 100, 100]);
      expect(r.scale, closeTo(0.8, 1e-9));
    });
  });

  group('التخطيط', () {
    test('normalizeLayout: كل عنصر مرة، والناقص في الآخر بالافتراضي', () {
      final l = normalizeLayout(const [
        TileLayout(WidgetElement.prayer, span: 3),
        TileLayout(WidgetElement.prayer),
        TileLayout(WidgetElement.clock),
      ]);
      expect(l.map((t) => t.id).toList(), [
        WidgetElement.prayer,
        WidgetElement.clock,
        WidgetElement.dates,
        WidgetElement.weather,
        WidgetElement.qibla,
        WidgetElement.deposit,
        WidgetElement.season,
        WidgetElement.tradSeason,
      ]);
      expect(l.first.span, 3);
    });

    test('ترحيل visible القديم إلى تخطيط افتراضي يطابقه', () {
      final l = layoutFromVisible(['gregorian', 'prayer', 'tradSeason']);
      expect({for (final t in l) t.id.name: t.visible}, {
        'clock': true,
        'dates': true,
        'weather': false,
        'prayer': true,
        'qibla': false,
        'deposit': false,
        'season': false,
        'tradSeason': true,
      });
      expect(l.map((t) => t.span), defaultLayout.map((t) => t.span));
      expect(layoutFromVisible(const []).where((t) => t.visible).map((t) => t.id),
          [WidgetElement.clock]);
    });

    test('الحفظ والقراءة، والجدول بقيم جاهزة', () {
      const t = TileLayout(
        WidgetElement.qibla,
        visible: false,
        span: 2,
        fontScale: FontScale.xlarge,
        primaryColor: TileColor.pink,
      );
      final back = TileLayout.fromJson(
          jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(back, t);
      expect(t.toJson()['secondaryColor'], isNull);
      expect(t.toScheduleJson(), {
        'id': 'qibla',
        'visible': false,
        'span': 2,
        'fontScale': 1.3,
        'primaryColor': 0xFFEE9AB8,
        'secondaryColor': null,
      });
      expect(t.copyWith(primaryColor: () => null).primaryColor, isNull);
      expect(TileColor.values.map((c) => c.name), [
        'white', 'gold', 'green', 'blue', 'purple', 'pink', 'lightGray',
      ]);
    });
  });
}
