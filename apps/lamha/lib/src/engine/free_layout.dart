/// التخطيط الحر (طلب المالك ١١/١١/٢٠٢٦، DECISIONS ٢٧): الودجت شبكة [freeCols]×[freeRows] خلية متساوية،
/// ولكل عنصر ظاهر مستطيل عليها (x من اليمين، y من الأعلى). في التعديل يُسحب العنصر ويُكبَّر ويُصغَّر،
/// وبعد كل تغيير تصعد العناصر لتملأ الفراغ ([compact]) فلا تبقى فجوات.
///
/// الودجتان الأصليتان لا تحسبان: يكتب التطبيق في الجدول «شجرة القص» ([cutTree]): تقسيم الودجت إلى صفوف
/// وأعمدة متداخلة بأوزان صحيحة، فترسمها SwiftUI بـ VStack/HStack وأندرويد بـ LinearLayout بالأوزان نفسها.
/// كل تخطيط يُقبل في المحرر يجب أن يُقسَم هكذا (لا تداخل «دوّامي»)، وإلا تُرفض الحركة.
library;

import 'widget_layout.dart';

const freeCols = 6;
const freeRows = 10;

/// مستطيل على الشبكة بالخلايا.
class GridRect {
  const GridRect(this.x, this.y, this.w, this.h);

  factory GridRect.fromJson(Object? j) {
    final l = (j as List).cast<num>();
    return GridRect(l[0].toInt(), l[1].toInt(), l[2].toInt(), l[3].toInt());
  }

  final int x, y, w, h;

  int get right => x + w;
  int get bottom => y + h;

  bool overlaps(GridRect o) => x < o.right && o.x < right && y < o.bottom && o.y < bottom;

  GridRect at(int nx, int ny) => GridRect(nx, ny, w, h);

  /// داخل الشبكة عرضاً (الارتفاع قد يتجاوز [freeRows] فيُعلَّم «لا يتسع»).
  GridRect clamped() {
    final cw = w.clamp(1, freeCols);
    final ch = h.clamp(1, freeRows);
    return GridRect(x.clamp(0, freeCols - cw), y < 0 ? 0 : y, cw, ch);
  }

  List<int> toJson() => [x, y, w, h];

  @override
  bool operator ==(Object other) =>
      other is GridRect && other.x == x && other.y == y && other.w == w && other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'GridRect($x, $y, $w, $h)';
}

/// أصغر مقاس لكل عنصر (عرض × ارتفاع) فلا يصغر حتى يتعذر قراءته.
({int w, int h}) minSize(WidgetElement e) => switch (e) {
      WidgetElement.clock => (w: 2, h: 2),
      WidgetElement.prayerTimes => (w: 4, h: 2),
      WidgetElement.deposit => (w: 2, h: 1),
      WidgetElement.qibla => (w: 2, h: 2),
      WidgetElement.tradPoints => (w: 3, h: 2),
      _ => (w: 2, h: 1),
    };

/// المقاس الافتراضي لعنصر يُظهَر أول مرة (ومن تخطيط قديم بلا مستطيلات).
({int w, int h}) defaultSize(WidgetElement e) => switch (e) {
      WidgetElement.clock => (w: 4, h: 2),
      WidgetElement.dayWeather => (w: 2, h: 2),
      WidgetElement.hijri || WidgetElement.gregorian => (w: 4, h: 1),
      WidgetElement.qibla => (w: 2, h: 2),
      WidgetElement.prayerTimes || WidgetElement.deposit || WidgetElement.tradPoints => (w: 6, h: 2),
      WidgetElement.dates => (w: 6, h: 1),
      // تصميم المالك ٣: الفصل ثلث الصف، والموسم ثلثاه.
      WidgetElement.season => (w: 2, h: 2),
      WidgetElement.tradSeason => (w: 4, h: 2),
      WidgetElement.weather => (w: 2, h: 1),
      WidgetElement.prayer => (w: 3, h: 2),
    };

/// أول موضع فارغ يتسع لـ [size] (من الأعلى، ومن اليمين في كل صف).
GridRect firstFit(({int w, int h}) size, List<GridRect> taken) {
  for (var y = 0;; y++) {
    for (var x = 0; x + size.w <= freeCols; x++) {
      final r = GridRect(x, y, size.w, size.h);
      if (!taken.any(r.overlaps)) return r;
    }
  }
}

/// يصعد كل مستطيل بالترتيب (من الأعلى ثم من اليمين) حتى يلامس ما فوقه أو أعلى الشبكة.
Map<WidgetElement, GridRect> compact(Map<WidgetElement, GridRect> rects) {
  final order = rects.keys.toList()
    ..sort((a, b) {
      final ra = rects[a]!, rb = rects[b]!;
      return ra.y != rb.y ? ra.y.compareTo(rb.y) : ra.x.compareTo(rb.x);
    });
  final out = <WidgetElement, GridRect>{};
  for (final id in order) {
    var r = rects[id]!;
    while (r.y > 0) {
      final up = r.at(r.x, r.y - 1);
      if (out.values.any(up.overlaps)) break;
      r = up;
    }
    out[id] = r;
  }
  return out;
}

/// يضع [id] في [target] ويدفع ما يتداخل معه إلى الأسفل (متتابعاً)، ثم يصعد الجميع ([compact]).
Map<WidgetElement, GridRect> place(Map<WidgetElement, GridRect> rects, WidgetElement id, GridRect target) {
  final moved = target.clamped();
  final out = <WidgetElement, GridRect>{id: moved};
  // الباقون بالترتيب من الأعلى: كل متداخل ينزل تحت ما يتداخل معه.
  final others = rects.keys.where((k) => k != id).toList()
    ..sort((a, b) => rects[a]!.y != rects[b]!.y ? rects[a]!.y.compareTo(rects[b]!.y) : rects[a]!.x.compareTo(rects[b]!.x));
  for (final k in others) {
    var r = rects[k]!;
    while (out.values.any(r.overlaps)) {
      final below = out.values.where(r.overlaps).map((o) => o.bottom).reduce((a, b) => a > b ? a : b);
      r = r.at(r.x, below);
    }
    out[k] = r;
  }
  return compact(out);
}

/// مستطيلات العناصر الظاهرة: المحفوظة، وما ينقصه مستطيل يوضع في أول فراغ بمقاسه الافتراضي.
Map<WidgetElement, GridRect> rectsOf(List<TileLayout> layout) {
  final out = <WidgetElement, GridRect>{};
  for (final t in layout.where((t) => t.visible && t.rect != null)) {
    out[t.id] = t.rect!.clamped();
  }
  for (final t in layout.where((t) => t.visible && t.rect == null)) {
    out[t.id] = firstFit(defaultSize(t.id), out.values.toList());
  }
  final packed = compact(out);
  if (cutTree(packed) != null) return packed;
  // ترتيب تلقائي لا يُقسم صفوفاً وأعمدة: رصّ بالصفوف بالترتيب نفسه (يُقسم دائماً).
  return shelfPack([
    for (final t in layout.where((t) => t.visible)) (id: t.id, size: (w: packed[t.id]!.w, h: packed[t.id]!.h)),
  ]);
}

/// رصّ بالصفوف: من اليمين حتى يمتلئ الصف، وارتفاع الصف بأطول عنصر فيه. كل صف يُقطع أعمدةً فيقسم دائماً.
Map<WidgetElement, GridRect> shelfPack(List<({WidgetElement id, ({int w, int h}) size})> items) {
  final out = <WidgetElement, GridRect>{};
  var x = 0, y = 0, rowH = 0;
  for (final it in items) {
    final w = it.size.w.clamp(1, freeCols);
    if (x + w > freeCols) {
      y += rowH;
      x = 0;
      rowH = 0;
    }
    out[it.id] = GridRect(x, y, w, it.size.h);
    x += w;
    if (it.size.h > rowH) rowH = it.size.h;
  }
  return out;
}

/// يكتب المستطيلات في التخطيط (المخفي يحتفظ بمستطيله الأخير).
List<TileLayout> withRects(List<TileLayout> layout, Map<WidgetElement, GridRect> rects) => [
      for (final t in layout) rects.containsKey(t.id) ? t.copyWith(rect: () => rects[t.id]) : t,
    ];

/// ما يتجاوز أسفل الشبكة لا يظهر في الودجت.
Set<WidgetElement> overflowing(Map<WidgetElement, GridRect> rects) =>
    {for (final e in rects.entries) if (e.value.bottom > freeRows) e.key};

/// عقدة في شجرة القص: [tile] لعنصر، أو [children] مكدسة رأسياً (column) أو أفقياً (row) بأوزان صحيحة.
/// فراغ بلا عنصر = عقدة بلا tile ولا children.
class CutNode {
  const CutNode.tile(WidgetElement this.tile)
      : vertical = false,
        children = const [];
  const CutNode.empty()
      : tile = null,
        vertical = false,
        children = const [];
  const CutNode.split({required this.vertical, required this.children}) : tile = null;

  final WidgetElement? tile;

  /// true: الأبناء من الأعلى للأسفل؛ false: من اليمين لليسار.
  final bool vertical;
  final List<({int weight, CutNode node})> children;

  bool get isEmpty => tile == null && children.isEmpty;

  /// من الجدول (عكس [toJson])؛ مدخل غير مفهوم = فراغ.
  factory CutNode.fromJson(Map j) {
    final t = j['tile'];
    if (t is String && WidgetElement.values.any((e) => e.name == t)) {
      return CutNode.tile(WidgetElement.values.byName(t));
    }
    final ch = j['children'];
    if (ch is List && ch.isNotEmpty) {
      return CutNode.split(vertical: j['dir'] == 'v', children: [
        for (final c in ch.cast<Map>()) (weight: (c['w'] as num?)?.toInt() ?? 1, node: CutNode.fromJson(c)),
      ]);
    }
    return const CutNode.empty();
  }

  /// عدد المستويات (المربع والفراغ مستوى واحد).
  int get depth => children.isEmpty ? 1 : 1 + children.map((c) => c.node.depth).reduce((a, b) => a > b ? a : b);

  /// العناصر الظاهرة في الشجرة.
  Set<WidgetElement> get tiles => tile != null ? {tile!} : {for (final c in children) ...c.node.tiles};

  Map<String, Object?> toJson() => tile != null
      ? {'tile': tile!.name}
      : children.isEmpty
          ? {'empty': true}
          : {
              'dir': vertical ? 'v' : 'h',
              'children': [
                for (final c in children) {'w': c.weight, ...c.node.toJson()},
              ],
            };
}

/// أقصى عمق لشجرة القص (المربع مستوى). ودجت أندرويد تضيف مستوى addView لكل عمق، والنظام يرفض أكثر من
/// ١٠ مستويات فيسقط التطبيق (1.1.0+10). يطابق FREE_MAX_DEPTH في LamhaLogic.kt.
const cutTreeMaxDepth = 6;

/// يقسم الشبكة بقطع كاملة (أفقية ثم رأسية) حتى يبقى عنصر واحد أو فراغ في كل جزء.
/// null إذا تعذر القطع (ترتيب دوّامي) أو كانت الشجرة أعمق من [cutTreeMaxDepth]، ولا يُقبل.
CutNode? cutTree(Map<WidgetElement, GridRect> rects) {
  final tree = _cut(rects);
  return tree == null || tree.depth > cutTreeMaxDepth ? null : tree;
}

CutNode? _cut(Map<WidgetElement, GridRect> rects, {GridRect box = const GridRect(0, 0, freeCols, freeRows)}) {
  // ما يتجاوز أسفل الشبكة لا يظهر ولا يدخل القسمة.
  rects = {for (final e in rects.entries) if (e.value.bottom <= freeRows) e.key: e.value};
  final inside = {
    for (final e in rects.entries)
      if (e.value.overlaps(box)) e.key: e.value,
  };
  if (inside.isEmpty) return const CutNode.empty();
  if (inside.length == 1) {
    final r = inside.values.single;
    if (r == box) return CutNode.tile(inside.keys.single);
  }
  for (final vertical in [true, false]) {
    final start = vertical ? box.y : box.x;
    final end = vertical ? box.bottom : box.right;
    // خطوط القطع: حيث لا يعبر أي مستطيل.
    final cuts = <int>[start];
    for (var p = start + 1; p < end; p++) {
      final crossed = inside.values.any((r) => vertical ? (r.y < p && r.bottom > p) : (r.x < p && r.right > p));
      if (!crossed) cuts.add(p);
    }
    cuts.add(end);
    // قطع الحواف الملتصقة بعناصر فقط، لا بين خلايا فارغة متجاورة.
    final edges = <int>[start];
    for (var i = 1; i < cuts.length - 1; i++) {
      final p = cuts[i];
      final isEdge = inside.values.any((r) => vertical ? (r.y == p || r.bottom == p) : (r.x == p || r.right == p));
      if (isEdge) edges.add(p);
    }
    edges.add(end);
    if (edges.length <= 2) continue;
    final parts = <({int weight, CutNode node})>[];
    for (var i = 0; i + 1 < edges.length; i++) {
      final sub = vertical
          ? GridRect(box.x, edges[i], box.w, edges[i + 1] - edges[i])
          : GridRect(edges[i], box.y, edges[i + 1] - edges[i], box.h);
      final node = _cut(inside, box: sub);
      if (node == null) return null;
      parts.add((weight: edges[i + 1] - edges[i], node: node));
    }
    return CutNode.split(vertical: vertical, children: parts);
  }
  // عنصر واحد لا يملأ صندوقه، أو تداخل دوّامي.
  if (inside.length == 1) return CutNode.tile(inside.keys.single);
  return null;
}

/// عرض المستطيل بوحدات التخطيط القديم (١ صغير، ٢ متوسط، ٣ عريض) لمحتوى يتغير بالعرض (عدد الإيداعات).
int spanOfWidth(int w) => w <= 2 ? 1 : w <= 4 ? 2 : 3;

/// إعادة الرصّ بترتيب [ordered] مع إبقاء مقاس كل عنصر (ترتيب القائمة في شاشة «الودجت»).
List<TileLayout> reflow(List<TileLayout> ordered) {
  final current = rectsOf(ordered);
  final cleared = [for (final t in ordered) t.copyWith(rect: () => null)];
  final placed = <WidgetElement, GridRect>{};
  for (final t in cleared.where((t) => t.visible)) {
    final r = current[t.id];
    placed[t.id] = firstFit(r == null ? defaultSize(t.id) : (w: r.w, h: r.h), placed.values.toList());
  }
  var next = compact(placed);
  if (cutTree(next) == null) {
    next = shelfPack([for (final t in cleared.where((t) => t.visible)) (id: t.id, size: (w: next[t.id]!.w, h: next[t.id]!.h))]);
  }
  return withRects(cleared, next);
}
