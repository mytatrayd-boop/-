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
        fontScale: 1.3,
        showSub: false,
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
        'showTitle': true,
        'showSub': false,
        'primaryColor': 0xFFEE9AB8,
        'secondaryColor': null,
      });
      expect(t.copyWith(primaryColor: () => null).primaryColor, isNull);
      expect(TileColor.values.map((c) => c.name), [
        'white', 'gold', 'green', 'blue', 'purple', 'pink', 'lightGray',
      ]);
    });
  });

  test('placedElements: كل المربعات بعرض ٣ والتاريخ مكدس مع الطقس، فالإيداع (السادس) يظهر', () {
    final shown = [
      for (final id in ['clock', 'dates', 'weather', 'prayer', 'qibla', 'deposit', 'season', 'tradSeason'])
        (id: id, span: 3),
    ];
    final placed = placedElements(shown);
    expect(placed, containsAll(['clock', 'dates', 'weather', 'prayer', 'qibla', 'deposit']));
    expect(placed.contains('season'), isFalse);
  });

  group('الميزة ٥ب: حجم خط المربع والملاءمة (fitTileCases في LamhaLogicTest.kt)', () {
    test('tileFontScale: المدى ٠٫٨–٢٫٠ بخطوة ٠٫١، والأسماء القديمة', () {
      expect(tileFontScale(1.55), 1.6);
      expect(tileFontScale(3), 2.0);
      expect(tileFontScale(0.1), 0.8);
      expect(tileFontScale('xlarge'), 1.3);
      expect(tileFontScale('large'), 1.2);
      expect(tileFontScale(null), 1.0);
      final old = TileLayout.fromJson({'id': 'qibla', 'fontScale': 'small'});
      expect(old.fontScale, 0.9);
      expect(old.showTitle && old.showSub, isTrue);
      expect(const TileLayout(WidgetElement.qibla).copyWith(fontScale: 1.94).fontScale, 1.9);
    });

    test('wrapLines: التفاف عند المسافات فقط', () {
      expect(wrapLines([30, 20], 5, 80), 1);
      expect(wrapLines([30, 20], 5, 54), 2);
      expect(wrapLines([10, 10, 10], 0, 20), 2);
      expect(wrapLines([], 0, 10), 1);
    });

    TileFit fit(double height, double width, {bool fromStart = false, List<SubLine>? subs}) =>
        fitTile(
          height: height,
          width: width,
          titleHeight: 16,
          valueLineHeight: 25,
          valueWords: [30, 20],
          valueSpace: 5,
          subs: subs ??
              const [
                (height: 17.5, maxLines: 1, fitWidth: 0),
                (height: 17.5, maxLines: 2, fitWidth: 0),
              ],
          hideFromStart: fromStart,
          gap: 3,
        );

    test('يتسع كله بالحجم المطلوب، والأخير يأخذ سطره الثاني إن بقي مكان', () {
      final a = fit(100, 80);
      expect((a.title, a.valueScale, a.valueLines, a.lastSubLines), (true, 1.0, 1, 1));
      expect(a.subs, [0, 1]);
      expect(fit(120, 80).lastSubLines, 2);
      // بلا مقاس معروف: الكل.
      final u = fit(0, 0);
      expect((u.title, u.valueLines, u.lastSubLines), (true, 1, 2));
      expect(u.subs, [0, 1]);
    });

    test('ضيق الارتفاع: الثانويات بأولويتها، ثم العنوان، ثم أدنى تصغير للقيمة', () {
      expect(fit(60, 80).subs, isEmpty);
      expect(fit(60, 80).title, isTrue);
      expect(fit(70, 80, fromStart: true).subs, [1]);
      final c = fit(30, 80);
      expect((c.title, c.valueScale), (false, 1.0));
      expect(c.subs, isEmpty);
      // القيمة في سطرين (عرض ٤٠).
      final d = fit(100, 40);
      expect((d.valueLines, d.title), (2, true));
      expect(d.subs, [0]);
      expect((fit(60, 40).title, fit(60, 40).valueLines), (false, 2));
      // لا مكان لسطريها: تصغر بأدنى تصغير لتظهر كاملة (سطران بمعامل ٠٫٨).
      expect(fit(40, 40).valueLines, 2);
      expect(fit(40, 40).valueScale, closeTo(0.8, 1e-6));
      final f = fitTile(height: 20, width: 80, valueLineHeight: 25, valueWords: [30]);
      expect(f.valueScale, closeTo(0.8, 1e-9));
    });

    test('القيمة تصغر عرضياً فقط إن لم تتسع أعرض كلمة، وبأدنى تصغير', () {
      final e = fit(200, 24);
      expect(e.valueScale, closeTo(0.8, 1e-9));
      expect(e.valueLines, 2);
      expect(fit(200, 30).valueScale, 1.0);
    });

    test('سطر لا يُختصر (العدّاد): يصغر حتى ٧٠٪ وإلا يُخفى', () {
      final g = fit(200, 80, subs: const [
        (height: 17.5, maxLines: 1, fitWidth: 100),
        (height: 17.5, maxLines: 1, fitWidth: 200),
      ]);
      expect(g.subs, [0]);
      expect(g.subScales.single, closeTo(0.8, 1e-9));
    });
  });
}
