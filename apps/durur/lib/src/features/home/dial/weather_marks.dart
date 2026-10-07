import 'dart:math' as math;

import '../../../domain/weather_symbol.dart';
import 'dial_model.dart';

/// الإطار الخارجي A (DESIGN R3.1-5، الميزة 16). Dart صافٍ.
///
/// - **رمز واحد لكل خلية:** خلية لكل دَرّ (أو لكل طالع في منطقة بلا درور،
///   R3.10)، والرمز هو الأول في `weather`، ويُكرَّر حتى لو طابق جاره.
/// - **أسماء مواسم الجو** تُكتب على طول القوس في منتصف موسمها إن اتسع له،
///   والمساحة التي يشغلها الاسم تُخفي الرموز تحته (تبقى في الفقاعة).
/// - **اللمس بالخلايا** (لا بمسافة 48dp): كل خلية منطقة لمس لا تتداخل،
///   ≥ 24×24dp (WCAG 2.2 معيار 2.5.8، D41).

/// هامش حول الاسم على القوس (من كل جانب) يُخفي ما تحته من رموز.
const double _nameMargin = 4;

/// اسم موسم جو على الإطار.
class FrameName {
  const FrameName({
    required this.itemId,
    required this.center,
    required this.halfSpan,
  });

  final String itemId;

  /// منتصف الاسم كفهرس يوم كسري.
  final double center;

  /// نصف المدى الذي يغطيه الاسم بالأيام (مع الهامش).
  final double halfSpan;

  bool covers(double day, int dayCount) {
    var d = (day - center) % dayCount;
    if (d > dayCount / 2) d -= dayCount;
    return d.abs() <= halfSpan;
  }
}

/// رمز ظاهر في خلية.
class FrameMark {
  const FrameMark(this.cell, this.symbol);

  final WeatherCell cell;
  final WeatherSymbol symbol;

  /// منتصف الخلية كفهرس يوم كسري.
  double get center => cell.center;
}

/// تخطيط الإطار لحجم دائرة ومستوى تكبير.
class FrameLayout {
  const FrameLayout(this.names, this.marks);

  static const empty = FrameLayout([], []);

  final List<FrameName> names;
  final List<FrameMark> marks;
}

/// يحسب الأسماء الظاهرة والرموز غير المغطاة. [radius] نصف قطر منتصف الإطار،
/// و[nameWidth] عرض اسم موسم الجو بالنقاط (null = بلا اسم). [blocked] مدى
/// أرقام الأشهر (منتصف، نصف مدى بالأيام) التي تُخفي الرموز تحتها.
FrameLayout layoutFrame({
  required DialModel model,
  required double radius,
  required double? Function(String itemId) nameWidth,
  double zoom = 1,
  List<(double center, double halfSpan)> blocked = const [],
}) {
  final n = model.dayCount;
  final pxPerDay = 2 * math.pi / n * radius * zoom;
  final names = <FrameName>[];
  for (final s in model.cyclicSegments(DialRing.weather)) {
    final id = s.itemId;
    final w = id == null ? null : nameWidth(id);
    if (id == null || w == null) continue;
    final arc = s.length * pxPerDay;
    if (arc < w + 2 * _nameMargin) continue;
    names.add(
      FrameName(
        itemId: id,
        center: s.start + s.length / 2,
        halfSpan: (w / 2 + _nameMargin) / pxPerDay,
      ),
    );
  }
  final marks = <FrameMark>[
    for (final c in model.cells)
      if (c.symbol case final symbol?)
        if (!names.any((name) => name.covers(c.center, n)) &&
            !blocked.any((b) => _near(c.center, b.$1, b.$2, n)))
          FrameMark(c, symbol),
  ];
  return FrameLayout(names, marks);
}

bool _near(double a, double b, double half, int n) {
  var d = (a - b) % n;
  if (d > n / 2) d -= n;
  return d.abs() <= half;
}
