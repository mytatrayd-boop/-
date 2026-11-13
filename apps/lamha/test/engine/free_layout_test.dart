import 'dart:math';

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

  test('شجرة القص لا تتجاوز cutTreeMaxDepth (ودجت أندرويد تسقط بأكثر من ١٠ مستويات)', () {
    // سحب وتكبير عشوائيان: كل حركة مقبولة شجرتها ضمن الحد، والمرفوضة لا تغيّر شيئاً.
    final rnd = Random(7);
    var rects = rectsOf(defaultLayout);
    var accepted = 0;
    for (var i = 0; i < 3000; i++) {
      final id = rects.keys.elementAt(rnd.nextInt(rects.length));
      final next = place(rects, id, GridRect(rnd.nextInt(6), rnd.nextInt(10), 1 + rnd.nextInt(6), 1 + rnd.nextInt(4)));
      final tree = cutTree(next);
      if (tree == null) continue;
      expect(tree.depth, lessThanOrEqualTo(cutTreeMaxDepth));
      rects = next;
      accepted++;
    }
    expect(accepted, greaterThan(100));
    expect(cutTree(rectsOf(defaultLayout))!.depth, lessThanOrEqualTo(cutTreeMaxDepth));
  });

  test('شجرة أعمق من الحد تُرفض', () {
    // دوّامة متداخلة: كل عنصر يأخذ شريطاً ويترك الباقي للتالي، بالتناوب أفقياً ورأسياً.
    final ids = [c, dw, hi, gr, qi, pt, de, se, ts];
    final r = <WidgetElement, GridRect>{};
    var x = 0, y = 0, w = 6, h = 10;
    for (var i = 0; i < ids.length && w > 0 && h > 0; i++) {
      if (i.isEven) {
        r[ids[i]] = GridRect(x, y, w, 1);
        y++;
        h--;
      } else {
        r[ids[i]] = GridRect(x, y, 1, h);
        x++;
        w--;
      }
    }
    expect(r.length, 9);
    expect(cutTree(r), isNull);
    // rectsOf لا يعطي شجرة مرفوضة أبداً: يرجع إلى الرصّ بالصفوف.
    final layout = [for (final e in r.entries) TileLayout(e.key).copyWith(rect: () => e.value)];
    expect(cutTree(rectsOf(layout)), isNotNull);
  });

  group('المربعات العائمة (DECISIONS ٢٩)', () {
    const f = FloatRect(0.6, 0.1, 0.3, 0.2);
    final floating = [
      for (final t in defaultLayout) t.id == qi || t.id == pt ? t.copyWith(float: () => f) : t,
    ];

    test('العائم خارج الرصّ: لا مستطيل له ولا مكان في الشجرة، وغيره يملأ مكانه', () {
      final r = rectsOf(floating);
      expect(r.containsKey(qi), isFalse);
      expect(r.containsKey(pt), isFalse);
      expect(cutTree(r)!.tiles, isNot(contains(qi)));
      expect(cutTree(r)!.tiles, isNot(contains(pt)));
      expect(r.keys, containsAll([c, dw, hi, gr, de, se, ts]));
      // لا فجوات: لا يتجاوز شيء أسفل الشبكة ولا يتداخل اثنان.
      expect(overflowing(r), isEmpty);
      final list = r.values.toList();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          expect(list[i].overlaps(list[j]), isFalse);
        }
      }
    });

    test('كل المربعات عائمة: لا شجرة ولا رصّ، ولا يفشل شيء', () {
      final all = [for (final t in defaultLayout) t.copyWith(float: () => f)];
      expect(rectsOf(all), isEmpty);
      expect(reflow(all).length, all.length);
    });

    test('إعادة الرصّ تبقي العائم كما هو ولا تفقده', () {
      final out = reflow(floating);
      expect(out.length, floating.length);
      expect(out.firstWhere((t) => t.id == qi).float, f);
      expect(out.firstWhere((t) => t.id == pt).float, f);
    });

    test('FloatRect: JSON والموضع بالبكسل محصور في الودجت', () {
      expect(FloatRect.fromJson(f.toJson()), f);
      final p = f.within(300, 400);
      expect(p.width, 90);
      expect(p.height, 80);
      expect(p.right, 180);
      expect(p.top, 40);
      // خارج الحدود يُحصر: لا يخرج المربع من الودجت، والمقاس بين الحدين.
      final out = const FloatRect(5, 5, 5, 5).within(300, 400);
      expect(out.width, 300);
      expect(out.height, 400);
      expect(out.right, 0);
      expect(out.top, 0);
      final small = const FloatRect(0, 0, 0.01, 0.01).within(300, 400);
      expect(small.width, 0.12 * 300);
      expect(small.height, 0.06 * 400);
      // الذهاب والعودة بالبكسل.
      final back = FloatRect.fromPixels(180, 40, 90, 80, 300, 400);
      expect(back.x, closeTo(0.6, 1e-9));
      expect(back.y, closeTo(0.1, 1e-9));
      expect(back.w, closeTo(0.3, 1e-9));
      expect(back.h, closeTo(0.2, 1e-9));
      // الصيغة القديمة (قرص البوصلة [x, y, s]) تُقرأ ولا تنكسر.
      final old = FloatRect.fromJson([0.62, 0.08, 0.3]);
      expect(old.w, 0.3);
      expect(old.h, closeTo(0.3 * 338 / 440, 1e-9));
    });

    test('عرض المربع العائم بوحدات العرض: بعرض الودجت كله ٣ (لا ٢)، وتطابق Kotlin', () {
      // الحالات نفسها في LamhaLogicTest.floatSpanCases (خطأ أندرويد: كسر × ٣ بدل × ٦ فتظهر الإيداعات اثنين فقط).
      expect(floatSpan(1.0), 3);
      expect(floatSpan(0.84), 3);
      expect(floatSpan(0.5), 2);
      expect(floatSpan(0.67), 2);
      expect(floatSpan(0.33), 1);
      expect(floatSpan(0.12), 1);
      expect(maxDeposits(floatSpan(1.0)), 6);
    });

    test('TileLayout يحفظ float في الإعدادات والجدول وتعود قراءته', () {
      final t = floating.firstWhere((t) => t.id == qi);
      expect(t.floating, isTrue);
      expect(TileLayout.fromJson((t.toJson()).cast<String, dynamic>()).float, t.float);
      expect(t.toScheduleJson()['float'], [0.6, 0.1, 0.3, 0.2]);
      expect(defaultLayout.firstWhere((t) => t.id == qi).toScheduleJson().containsKey('float'), isFalse);
    });
  });
}
