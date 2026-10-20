import 'dart:math' as math;

/// تخطيط الودجت (الميزة ٥، DECISIONS ١٥): كل عنصر مربع على شبكة عرضها [gridColumns] وحدات،
/// يُرصّ بالترتيب من اليمين ويلتفّ إلى صف جديد، بحد [maxGridRows] صفوف.
/// الخوارزمية نفسها في LamhaLogic.kt (packRows وrowHeights) مع اختبار بالحالات نفسها.

/// عناصر الودجت الثمانية بترتيبها الافتراضي.
enum WidgetElement {
  clock,
  dates,
  weather,
  prayer,
  qibla,
  deposit,
  season,
  tradSeason,
}

/// حجم الخط العام (شاشة الإعدادات): معامل يُضرب به كل حجم نص.
enum FontScale {
  small(0.9),
  medium(1.0),
  large(1.15),
  xlarge(1.3);

  const FontScale(this.factor);

  final double factor;

  static const fallback = FontScale.medium;

  static FontScale byName(String? name) => FontScale.values.firstWhere(
    (f) => f.name == name,
    orElse: () => fallback,
  );
}

/// لوحة ألوان الخط الثابتة (ARGB). اللون null = تلقائي حسب السمة والعنصر.
enum TileColor {
  white(0xFFFFFFFF),
  gold(0xFFD6AA5C),
  green(0xFF78BE96),
  blue(0xFF7FB2E5),
  purple(0xFFB39DDB),
  pink(0xFFEE9AB8),
  lightGray(0xFFCFCFCF);

  const TileColor(this.argb);

  final int argb;

  static TileColor? byName(String? name) =>
      TileColor.values.where((c) => c.name == name).firstOrNull;
}

const gridColumns = 3;
const maxGridRows = 5;

/// حجم خط المربع (الميزة ٥ب): شريط من [tileFontMin] إلى [tileFontMax] بخطوة [tileFontStep]،
/// يُضرب في حجم الخط العام.
const tileFontMin = 0.8;
const tileFontMax = 2.0;
const tileFontStep = 0.1;

/// معامل خط مربع ضمن المدى وعلى خطوة ٠٫١. القيمة المحفوظة قبل ٥ب اسم (FontScale)، فتُحوَّل لمعاملها.
double tileFontScale(Object? raw) {
  final v = raw is num
      ? raw.toDouble()
      : raw is String
      ? FontScale.byName(raw).factor
      : 1.0;
  return ((v.clamp(tileFontMin, tileFontMax) * 10 + 1e-9).round() / 10)
      .toDouble();
}

/// إعدادات مربع واحد.
class TileLayout {
  const TileLayout(
    this.id, {
    this.visible = true,
    this.span = 1,
    this.fontScale = 1.0,
    this.showTitle = true,
    this.showSub = true,
    this.primaryColor,
    this.secondaryColor,
  });

  factory TileLayout.fromJson(Map<String, dynamic> j) => TileLayout(
    WidgetElement.values.byName(j['id'] as String),
    visible: j['visible'] as bool? ?? true,
    span: ((j['span'] as num?)?.toInt() ?? 1).clamp(1, gridColumns),
    fontScale: tileFontScale(j['fontScale']),
    showTitle: j['showTitle'] as bool? ?? true,
    showSub: j['showSub'] as bool? ?? true,
    primaryColor: TileColor.byName(j['primaryColor'] as String?),
    secondaryColor: TileColor.byName(j['secondaryColor'] as String?),
  );

  final WidgetElement id;
  final bool visible;

  /// العرض بالوحدات: ١ صغير، ٢ متوسط، ٣ عريض.
  final int span;

  /// معامل خط المربع (٠٫٨–٢٫٠)، يُضرب في حجم الخط العام.
  final double fontScale;

  /// إظهار العنوان (مربعات المعلومات)، والسطر الفرعي (الثانويات، واليوم تحت الساعة، والميلادي).
  final bool showTitle;
  final bool showSub;

  /// لون الخط الرئيسي (القيمة) والفرعي (العنوان والثانويات)؛ null = تلقائي.
  final TileColor? primaryColor;
  final TileColor? secondaryColor;

  TileLayout copyWith({
    bool? visible,
    int? span,
    double? fontScale,
    bool? showTitle,
    bool? showSub,
    TileColor? Function()? primaryColor,
    TileColor? Function()? secondaryColor,
  }) => TileLayout(
    id,
    visible: visible ?? this.visible,
    span: span ?? this.span,
    fontScale: fontScale != null ? tileFontScale(fontScale) : this.fontScale,
    showTitle: showTitle ?? this.showTitle,
    showSub: showSub ?? this.showSub,
    primaryColor: primaryColor != null ? primaryColor() : this.primaryColor,
    secondaryColor: secondaryColor != null
        ? secondaryColor()
        : this.secondaryColor,
  );

  /// للإعدادات المحفوظة (اللونان بالأسماء).
  Map<String, Object?> toJson() => {
    'id': id.name,
    'visible': visible,
    'span': span,
    'fontScale': fontScale,
    'showTitle': showTitle,
    'showSub': showSub,
    'primaryColor': primaryColor?.name,
    'secondaryColor': secondaryColor?.name,
  };

  /// للجدول (قيم جاهزة): اللون ARGB أو null.
  Map<String, Object?> toScheduleJson() => {
    'id': id.name,
    'visible': visible,
    'span': span,
    'fontScale': fontScale,
    'showTitle': showTitle,
    'showSub': showSub,
    'primaryColor': primaryColor?.argb,
    'secondaryColor': secondaryColor?.argb,
  };

  @override
  bool operator ==(Object other) =>
      other is TileLayout &&
      other.id == id &&
      other.visible == visible &&
      other.span == span &&
      other.fontScale == fontScale &&
      other.showTitle == showTitle &&
      other.showSub == showSub &&
      other.primaryColor == primaryColor &&
      other.secondaryColor == secondaryColor;

  @override
  int get hashCode => Object.hash(
    id,
    visible,
    span,
    fontScale,
    showTitle,
    showSub,
    primaryColor,
    secondaryColor,
  );
}

/// الترتيب الافتراضي = الشكل السابق: الساعة واليوم يميناً، ويسارها التاريخان وتحتهما المدينة
/// والطقس (بعرضهما فيُكدَّسان، [stackCells])، ثم الصلاة والقبلة والإيداع، ثم الفصل والموسم.
const defaultLayout = <TileLayout>[
  TileLayout(WidgetElement.clock),
  TileLayout(WidgetElement.dates, span: 2),
  TileLayout(WidgetElement.weather, span: 2),
  TileLayout(WidgetElement.prayer),
  TileLayout(WidgetElement.qibla),
  TileLayout(WidgetElement.deposit),
  TileLayout(WidgetElement.season),
  TileLayout(WidgetElement.tradSeason, span: 2),
];

/// كل عنصر مرة واحدة: يُحذف المكرر، ويُضاف الناقص في آخر القائمة بإعداده الافتراضي.
List<TileLayout> normalizeLayout(Iterable<TileLayout> layout) {
  final seen = <WidgetElement>{};
  final out = <TileLayout>[
    for (final t in layout)
      if (seen.add(t.id)) t,
  ];
  for (final d in defaultLayout) {
    if (seen.add(d.id)) out.add(d);
  }
  return List.unmodifiable(out);
}

/// ترحيل إعدادات ما قبل الميزة ٥ (مفاتيح «ما يظهر على الودجت»): الترتيب الافتراضي، والإظهار
/// منها. الساعة كانت ثابتة، والتاريخان مربع واحد يظهر إذا ظهر أحدهما.
List<TileLayout> layoutFromVisible(Iterable<String> visible) {
  final v = visible.toSet();
  bool on(WidgetElement e) => switch (e) {
    WidgetElement.clock => true,
    WidgetElement.dates => v.contains('hijri') || v.contains('gregorian'),
    _ => v.contains(e.name),
  };
  return List.unmodifiable([
    for (final t in defaultLayout) t.copyWith(visible: on(t.id)),
  ]);
}

typedef GridCell = ({String id, int span});

/// توزيع المربعات الظاهرة [shown] (بالترتيب، الأول = الأيمن) على صفوف بعرض [columns]: كل مربع
/// في صف السابق إن اتسع وإلا في صف جديد، وآخر مربع في كل صف ناقص يتمدد ليملأه. ما بعد
/// [maxRows] صفوف لا يظهر (packRows في LamhaLogic.kt).
List<List<GridCell>> packRows(
  List<GridCell> shown, {
  int columns = gridColumns,
  int maxRows = maxGridRows,
}) {
  final rows = <List<GridCell>>[];
  var used = columns;
  for (final c in shown) {
    final span = c.span.clamp(1, columns);
    if (used + span > columns) {
      if (rows.length == maxRows) break;
      rows.add([]);
      used = 0;
    }
    rows.last.add((id: c.id, span: span));
    used += span;
  }
  for (final r in rows) {
    final total = r.fold<int>(0, (a, c) => a + c.span);
    if (total < columns) {
      r[r.length - 1] = (id: r.last.id, span: r.last.span + columns - total);
    }
  }
  return rows;
}

/// ارتفاعات الصفوف بوزن المحتوى: [text] ارتفاع نص أطول مربع في كل صف بحجمه المطلوب، و[pads]
/// ما لا يصغر منه (حشوات)، و[gap] بين الصفوف. يصغر النص كله بمعامل واحد (حتى [minScale]) إن لم
/// يتسع في [available]. الصفوف غير [flexible] (الساعة والتاريخان والمدينة) بارتفاعها الطبيعي،
/// وصفوف المربعات تقتسم الباقي بالتساوي (ومن يحتاج أكثر يأخذ حاجته؛ وإن نقص: بنسبتها).
/// بلا صف مرن (أو بلا [flexible]): الكل بنسبته. مع [equal] الصفوف متساوية والمعامل من أضيقها
/// (أندرويد أقدم من ١٢). بلا ارتفاع معروف: المعامل ١ والارتفاعات الطبيعية.
({double scale, List<double> heights}) rowHeights(
  List<double> text,
  List<double> pads,
  double available,
  double gap, {
  bool equal = false,
  double minScale = 0.6,
  List<bool>? flexible,
}) {
  final n = text.length;
  if (n == 0) return (scale: 1.0, heights: const []);
  final space = available - gap * (n - 1);
  if (available <= 0) {
    return (
      scale: 1.0,
      heights: [for (var i = 0; i < n; i++) text[i] + pads[i]],
    );
  }
  if (equal) {
    final h = space / n;
    var s = 1.0;
    for (var i = 0; i < n; i++) {
      if (text[i] > 0) s = math.min(s, (h - pads[i]) / text[i]);
    }
    return (
      scale: s.clamp(minScale, 1.0).toDouble(),
      heights: List.filled(n, h),
    );
  }
  final sumText = text.fold<double>(0, (a, b) => a + b);
  final sumPads = pads.fold<double>(0, (a, b) => a + b);
  final s = sumText <= 0
      ? 1.0
      : ((space - sumPads) / sumText).clamp(minScale, 1.0).toDouble();
  final natural = [for (var i = 0; i < n; i++) text[i] * s + pads[i]];
  final sum = natural.fold<double>(0, (a, b) => a + b);
  final flex = [for (var i = 0; i < n; i++) flexible != null && flexible[i]];
  final count = flex.where((f) => f).length;
  var fixed = 0.0;
  var soft = 0.0;
  for (var i = 0; i < n; i++) {
    flex[i] ? soft += natural[i] : fixed += natural[i];
  }
  final rest = space - fixed;
  if (count > 0 && rest > 0) {
    final h = [...natural];
    if (soft > rest) {
      // نقص: صفوف المربعات بنسبتها.
      for (var i = 0; i < n; i++) {
        if (flex[i]) h[i] = natural[i] * rest / soft;
      }
    } else {
      // حصص متساوية، والصف الذي يحتاج أكثر من حصته يأخذ حاجته ويقتسم الباقون ما بقي.
      var open = [
        for (var i = 0; i < n; i++)
          if (flex[i]) i,
      ];
      var left = rest;
      while (open.isNotEmpty) {
        final share = left / open.length;
        final big = open.where((i) => natural[i] > share).toList();
        if (big.isEmpty) {
          for (final i in open) {
            h[i] = share;
          }
          break;
        }
        for (final i in big) {
          h[i] = natural[i];
          left -= natural[i];
        }
        open = open.where((i) => !big.contains(i)).toList();
      }
    }
    return (scale: s, heights: h);
  }
  return (scale: s, heights: [for (final h in natural) h * space / sum]);
}

/// معرّف خانة التاريخين وتحتهما المدينة والطقس (الشكل السابق).
const datesWeatherCell = 'dates+weather';

/// إذا جاء مربع المدينة والطقس بعد التاريخين مباشرة وبعرضهما، يُكدَّس تحتهما في خانة واحدة
/// [datesWeatherCell] (كالعمود الأيسر السابق). قبل [packRows] (stackCells في LamhaLogic.kt).
List<GridCell> stackCells(List<GridCell> shown) {
  final out = <GridCell>[];
  for (var i = 0; i < shown.length; i++) {
    final c = shown[i];
    if (c.id == WidgetElement.dates.name &&
        i + 1 < shown.length &&
        shown[i + 1].id == WidgetElement.weather.name &&
        shown[i + 1].span == c.span) {
      out.add((id: datesWeatherCell, span: c.span));
      i++;
    } else {
      out.add(c);
    }
  }
  return out;
}

/// معرّفات العناصر في خانة (اثنان للخانة المكدسة).
List<String> cellElements(String cellId) => cellId.split('+');

/// العناصر التي تظهر فعلاً في الودجت: التكديس ثم التوزيع كما ترسمها الودجت والمعاينة.
Set<String> placedElements(List<GridCell> shown) => {
  for (final r in packRows(stackCells(shown)))
    for (final cell in r) ...cellElements(cell.id),
};

/// سطر ثانوي في مربع: [height] ارتفاع سطره بالحجم المطلوب، و[maxLines] حده، و[fitWidth] عرضه إن
/// كان لا يُختصر بـ«…» (العدّاد واليوم)، فيصغر حتى [fitTile.minSubFit] وإلا يُخفى؛ 0 = يُختصر.
typedef SubLine = ({double height, int maxLines, double fitWidth});

/// ما يظهر في مربع وبأي حجم (fitTile).
typedef TileFit = ({
  bool title,
  double valueScale,
  int valueLines,
  List<int> subs,
  List<double> subScales,
  int lastSubLines,
});

/// أسطر نص كلماته بعرض [words] (ومسافته [space]) في عرض [width]، بالتفاف عند المسافات فقط.
int wrapLines(List<double> words, double space, double width) {
  if (words.isEmpty) return 1;
  var lines = 1;
  var line = words.first;
  for (final w in words.skip(1)) {
    if (line + space + w <= width) {
      line += space + w;
    } else {
      lines++;
      line = w;
    }
  }
  return lines;
}

/// ملاءمة مربع (الميزة ٥ب): حجم الخط المطلوب يُحترم، ومقاس المربع ([height]×[width]) ثابت.
/// [titleHeight] سطر العنوان (0 = بلا عنوان)، و[valueLineHeight] سطر القيمة، و[valueWords] عرض
/// كلماتها، و[subs] الثانويات بترتيب عرضها، و[gap] بين الأسطر؛ كلها بالحجم المطلوب.
/// - القيمة تلتفّ عند المسافات، ولا تصغر عرضياً إلا إذا لم تتسع أعرض كلمة فيها، وبأدنى تصغير.
/// - ثانوي له [SubLine.fitWidth] أعرض من المربع يصغر حتى [minSubFit] وإلا يُخفى.
/// - إن لم يتسع الارتفاع: تُخفى الثانويات بأولويتها (من الآخر، أو من الأول مع [hideFromStart]:
///   الصلاة)، ثم العنوان، وآخراً تصغر القيمة بأدنى تصغير لتظهر كاملة (لا «…» في القيمة).
/// - الثانوي الأخير يأخذ أسطراً إضافية (حتى حده) إن بقي مكان.
/// بلا مقاس معروف (0): الكل بالحجم المطلوب. مطابقة لـ fitTile في LamhaLogic.kt.
TileFit fitTile({
  required double height,
  required double width,
  double titleHeight = 0,
  required double valueLineHeight,
  required List<double> valueWords,
  double valueSpace = 0,
  List<SubLine> subs = const [],
  bool hideFromStart = false,
  double gap = 0,
  double minSubFit = 0.7,
}) {
  var k = 1.0;
  final widest = valueWords.fold<double>(0, math.max);
  if (width > 0 && widest > width) k = width / widest;
  var lines = width > 0
      ? wrapLines([for (final w in valueWords) w * k], valueSpace * k, width)
      : 1;
  final scales = <int, double>{};
  for (var i = 0; i < subs.length; i++) {
    final f = subs[i].fitWidth;
    final s = width > 0 && f > width ? width / f : 1.0;
    if (s >= minSubFit) scales[i] = s;
  }
  final kept = scales.keys.toList();
  var title = titleHeight > 0;
  double used() {
    final items = (title ? 1 : 0) + 1 + kept.length;
    return (title ? titleHeight : 0) +
        lines * valueLineHeight * k +
        kept.fold<double>(0, (a, i) => a + subs[i].height * scales[i]!) +
        gap * (items - 1);
  }

  var lastLines = kept.isEmpty ? 1 : subs[kept.last].maxLines;
  if (height > 0) {
    while (used() > height && kept.isNotEmpty) {
      hideFromStart ? kept.removeAt(0) : kept.removeLast();
    }
    if (used() > height && title) title = false;
    if (used() > height && valueLineHeight > 0) {
      // القيمة كاملة بأدنى تصغير: أكبر معامل تتسع به أسطرها (بعد الالتفاف) في الارتفاع.
      int linesAt(double f) =>
          width > 0 ? wrapLines(valueWords, valueSpace, width / f) : 1;
      var lo = 0.0;
      var hi = k;
      for (var i = 0; i < 40; i++) {
        final mid = (lo + hi) / 2;
        linesAt(mid) * valueLineHeight * mid <= height ? lo = mid : hi = mid;
      }
      k = lo;
      lines = linesAt(k);
    }
    if (kept.isNotEmpty) {
      final last = subs[kept.last];
      final line = last.height * scales[kept.last]!;
      lastLines = line <= 0
          ? last.maxLines
          : (1 + ((height - used()) / line + 1e-6).floor()).clamp(
              1,
              last.maxLines,
            );
    }
  }
  return (
    title: title,
    valueScale: k,
    valueLines: lines,
    subs: List.unmodifiable(kept),
    subScales: List.unmodifiable([for (final i in kept) scales[i]!]),
    lastSubLines: lastLines,
  );
}
