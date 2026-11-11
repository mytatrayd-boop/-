import 'package:flutter_test/flutter_test.dart';
import 'package:lamha/src/engine/widget_layout.dart';

const c = WidgetElement.clock,
    dw = WidgetElement.dayWeather,
    hi = WidgetElement.hijri,
    gr = WidgetElement.gregorian,
    qi = WidgetElement.qibla,
    pt = WidgetElement.prayerTimes,
    de = WidgetElement.deposit,
    se = WidgetElement.season,
    ts = WidgetElement.tradSeason;

void main() {
  test('التخطيط الافتراضي بلا مستطيلات يملأ الشبكة ٦×١٠ بتصميم المالك', () {
    final r = rectsOf(defaultLayout);
    expect(r[c], const GridRect(0, 0, 4, 2));
    expect(r[dw], const GridRect(4, 0, 2, 2));
    expect(r[hi], const GridRect(0, 2, 4, 1));
    expect(r[gr], const GridRect(0, 3, 4, 1));
    expect(r[qi], const GridRect(4, 2, 2, 2));
    expect(r[pt], const GridRect(0, 4, 6, 2));
    expect(r[de], const GridRect(0, 6, 6, 2));
    expect(r[se], const GridRect(0, 8, 2, 2));
    expect(r[ts], const GridRect(2, 8, 4, 2));
    expect(overflowing(r), isEmpty);
  });

  test('الإخفاء لا يترك فجوة: ما تحته يصعد', () {
    final r = rectsOf([for (final t in defaultLayout) t.id == pt ? t.copyWith(visible: false) : t]);
    expect(r.containsKey(pt), isFalse);
    expect(r[de], const GridRect(0, 4, 6, 2));
    expect(r[se]!.y, 6);
  });

  test('تكبير البوصلة يدفع ما تحتها ثم يصعد الجميع بلا فجوات', () {
    final base = rectsOf(defaultLayout);
    final r = place(base, qi, const GridRect(4, 2, 2, 4));
    expect(r[qi], const GridRect(4, 2, 2, 4));
    expect(r[pt]!.y, 6, reason: 'المواقيت تنزل تحت البوصلة');
    for (final a in r.entries) {
      for (final b in r.entries) {
        if (a.key != b.key) expect(a.value.overlaps(b.value), isFalse, reason: '${a.key} ${b.key}');
      }
    }
    expect(overflowing(r), containsAll([se, ts]), reason: 'آخر صف خرج من الشبكة');
  });

  test('تحريك عنصر إلى الأعلى يزيح غيره، والمكان القديم يمتلئ', () {
    final r = place(rectsOf(defaultLayout), pt, const GridRect(0, 0, 6, 2));
    expect(r[pt], const GridRect(0, 0, 6, 2));
    expect(r[c], const GridRect(0, 2, 4, 2));
    expect(r[de]!.y, 6);
  });

  test('شجرة القص للتخطيط الافتراضي: صفوف رأسية بأوزانها، والصف الأول عمودان', () {
    final t = cutTree(rectsOf(defaultLayout))!;
    expect(t.vertical, isTrue);
    expect([for (final ch in t.children) ch.weight], [2, 2, 2, 2, 2]);
    final top = t.children.first.node;
    expect(top.vertical, isFalse);
    expect([for (final ch in top.children) (ch.weight, ch.node.tile)], [(4, c), (2, dw)]);
    final dates = t.children[1].node;
    expect(dates.children.first.node.vertical, isTrue, reason: 'الهجري فوق الميلادي');
    expect(t.toJson()['dir'], 'v');
  });

  test('الفراغ يصبح عقدة فارغة، والترتيب الدوّامي يُرفض', () {
    final t = cutTree({c: const GridRect(0, 0, 4, 2)})!;
    expect(t.toJson(), {
      'dir': 'v',
      'children': [
        {'w': 2, 'dir': 'h', 'children': [{'w': 4, 'tile': 'clock'}, {'w': 2, 'empty': true}]},
        {'w': 8, 'empty': true},
      ],
    });
    // دوّامة: أربعة مستطيلات حول مربع أوسط.
    final pin = {
      c: const GridRect(0, 0, 4, 2),
      dw: const GridRect(4, 0, 2, 4),
      hi: const GridRect(2, 4, 4, 2),
      gr: const GridRect(0, 2, 2, 4),
    };
    expect(cutTree(pin), isNull);
  });

  test('المستطيل يُحفظ ويُقرأ، والقديم بلا مستطيل يبقى null', () {
    final t = const TileLayout(WidgetElement.qibla).copyWith(rect: () => const GridRect(4, 2, 2, 3));
    final back = TileLayout.fromJson(t.toJson());
    expect(back.rect, const GridRect(4, 2, 2, 3));
    expect(back, t);
    expect(TileLayout.fromJson(const TileLayout(WidgetElement.qibla).toJson()).rect, isNull);
    expect(t.toScheduleJson()['rect'], [4, 2, 2, 3]);
  });

  test('ترتيب تلقائي لا يُقسم: رصّ بالصفوف يُقسم دائماً ولا يتداخل', () {
    // أي ترتيب للعناصر يعطي شجرة.
    final ids = [qi, c, pt, dw, hi, se, gr, de, ts];
    for (var k = 0; k < ids.length; k++) {
      final order = [...ids.skip(k), ...ids.take(k)];
      final r = rectsOf([for (final id in order) TileLayout(id)]);
      expect(cutTree(r), isNotNull, reason: '$order');
    }
  });
}
