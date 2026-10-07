import 'dart:math' as math;

import '../../../domain/item.dart';
import '../../../domain/weather_symbol.dart';
import 'dial_model.dart';

/// رموز الجو على الحلقة الخارجية (DESIGN R2.6، الميزة 16). Dart صافٍ.
///
/// المصدران: (1) موسم الجو: رمزه الأول من `weather` لعنصره، قبل اسمه في
/// اتجاه القراءة إن اتسع القوس للاسم؛ (2) «مقاطع» الدرور المتتالية التي لها
/// قائمة `weather` نفسها: حتى رمزين في منتصف المقطع.
///
/// قاعدة الكثافة: المسافة بين مركزي أي رمزين ظاهرين ≥ [minTouch] نقطة على
/// الشاشة، فلكل رمز منطقة لمس 48×48 لا تتداخل (SPEC 16.2). الأولوية لمواسم
/// الجو ثم للمقاطع الأطول؛ المجموعة المتعارضة تنزلق يوماً بيوم داخل مقطعها،
/// وإن لم تجد مكاناً تُخفى وتظهر عند التكبير.

/// مسافة اللمس الدنيا بين مركزي رمزين (نقطة على الشاشة).
const double minTouch = 48;

/// أقل مسافة بين حافة الرمز وحافة الاسم المجاور.
const double _nameGap = 6;

/// هامش القوس حول الاسم ورمزه حتى يُكتب الاسم (R2.5: عرض الاسم + 22).
const double _nameMargin = 22;

/// مصدر مجموعة رموز.
enum WeatherGroupKind { weatherSeason, durur }

/// رمز واحد في مجموعة. [offset] بالنقاط على الشاشة من مركز المجموعة، موجب
/// باتجاه بداية القراءة (يمين المجموعة حين تكون قائمة في النصف العلوي).
class WeatherMark {
  const WeatherMark(this.symbol, this.offset);

  final WeatherSymbol symbol;
  final double offset;
}

/// مجموعة رموز على القوس: موسم جو أو مقطع درور.
class WeatherGroup {
  const WeatherGroup({
    required this.kind,
    required this.start,
    required this.length,
    required this.center,
    required this.marks,
    required this.width,
    this.itemId,
    this.nameOffset,
  });

  final WeatherGroupKind kind;

  /// الفترة التي تتبعها المجموعة: أول يوم (فهرس في السنة) وطولها بالأيام
  /// (قد تعبر نهاية السنة).
  final int start;
  final int length;

  /// موضع مركز المجموعة كفهرس يوم كسري (زاويته [DialGeometry.angleOf]).
  final double center;
  final List<WeatherMark> marks;

  /// عرض المجموعة على الشاشة (الرموز والاسم).
  final double width;

  /// موسم الجو (لـ [WeatherGroupKind.weatherSeason]).
  final String? itemId;

  /// موضع مركز الاسم إن كُتب على القوس، وإلا null.
  final double? nameOffset;
}

/// تخطيط الرموز لحجم دائرة ومستوى تكبير.
class WeatherLayout {
  const WeatherLayout(this.groups, this.hidden);

  final List<WeatherGroup> groups;

  /// عدد المجموعات المخفية بهذا التكبير (تظهر عند التكبير).
  final int hidden;

  static const empty = WeatherLayout([], 0);
}

/// يبني [WeatherLayout] لـ [model].
///
/// [radius] نصف قطر منتصف الحلقة A بنقاط الدائرة غير المكبّرة، و[zoom]
/// مقياس التكبير؛ المسافات على الشاشة = المسافة × [zoom]. [iconSize] حجم
/// الرمز المرئي على الشاشة (16 أو 18)، و[nameWidth] عرض اسم موسم الجو على
/// الشاشة (null ← لا يُكتب الاسم).
WeatherLayout layoutWeatherMarks({
  required DialModel model,
  required Map<String, Item> items,
  required double radius,
  required double zoom,
  required double iconSize,
  double? Function(String itemId)? nameWidth,
}) {
  final days = model.dayCount;
  final pxPerDay = 2 * math.pi * radius * zoom / days;
  if (pxPerDay <= 0) return WeatherLayout.empty;
  // +1: الوتر أقصر قليلاً من القوس، فتبقى المسافة المستقيمة ≥ 48.
  final pad = math.max(0.0, (minTouch + 1 - iconSize) / 2);

  // المجالات المحجوزة على القوس بالنقاط: (مركز بالأيام، نصف عرض بالنقاط).
  final placed = <(double, double)>[];

  double cyclicPx(double a, double b) {
    var d = (a - b).abs() % days;
    if (d > days / 2) d = days - d;
    return d * pxPerDay;
  }

  bool free(double center, double halfWidth) => placed.every(
    (p) => cyclicPx(center, p.$1) >= halfWidth + p.$2,
  );

  final groups = <WeatherGroup>[];
  var hidden = 0;

  /// ينزلق داخل [start]..[start+length] يوماً بيوم (يمين ثم يسار) من المنتصف.
  double? slot(int start, int length, double width) {
    final half = width / 2 + pad;
    final halfDays = (width / 2) / pxPerDay;
    for (var step = 0; step <= length; step++) {
      for (final k in step == 0 ? const [0] : [step, -step]) {
        final pos = length / 2 + k;
        if (pos - halfDays < 0 || pos + halfDays > length) continue;
        final c = start + pos;
        if (free(c, half)) {
          placed.add((c, half));
          return c;
        }
      }
    }
    return null;
  }

  // (1) مواسم الجو.
  for (final s in model.cyclicSegments(DialRing.weather)) {
    final symbol = items[s.itemId]?.weather.firstOrNull;
    if (symbol == null) continue;
    final arc = s.length * pxPerDay;
    final nw = nameWidth?.call(s.itemId!);
    final mid = s.start + s.length / 2;
    if (nw != null && arc >= iconSize + _nameGap + nw + _nameMargin) {
      final width = iconSize + _nameGap + nw;
      final half = width / 2 + pad;
      if (free(mid, half)) {
        placed.add((mid, half));
        groups.add(
          WeatherGroup(
            kind: WeatherGroupKind.weatherSeason,
            start: s.start,
            length: s.length,
            center: mid,
            width: width,
            itemId: s.itemId,
            marks: [WeatherMark(symbol, width / 2 - iconSize / 2)],
            nameOffset: -(width / 2 - nw / 2),
          ),
        );
        continue;
      }
    }
    final c = slot(s.start, s.length, iconSize);
    if (c == null) {
      hidden++;
      continue;
    }
    groups.add(
      WeatherGroup(
        kind: WeatherGroupKind.weatherSeason,
        start: s.start,
        length: s.length,
        center: c,
        width: iconSize,
        itemId: s.itemId,
        marks: [WeatherMark(symbol, 0)],
      ),
    );
  }

  // (2) مقاطع الدرور المتشابهة الجو، الأطول أولاً.
  final runs = <({int start, int length, List<WeatherSymbol> weather})>[];
  for (final s in model.cyclicSegments(DialRing.durur)) {
    final weather = s.dar!.weather;
    if (weather.isEmpty) continue;
    final last = runs.lastOrNull;
    if (last != null &&
        last.start + last.length == s.start &&
        _sameList(last.weather, weather)) {
      runs[runs.length - 1] = (
        start: last.start,
        length: last.length + s.length,
        weather: last.weather,
      );
    } else {
      runs.add((start: s.start, length: s.length, weather: weather));
    }
  }
  // دمج آخر مقطع بأوله إن تلاقيا عبر نهاية السنة.
  if (runs.length > 1) {
    final first = runs.first;
    final last = runs.last;
    if ((last.start + last.length) % days == first.start &&
        _sameList(first.weather, last.weather)) {
      runs.removeAt(0);
      runs[runs.length - 1] = (
        start: last.start,
        length: last.length + first.length,
        weather: last.weather,
      );
    }
  }
  runs.sort((a, b) => b.length.compareTo(a.length));
  for (final run in runs) {
    final n = math.min(2, run.weather.length);
    // رمزان في مقطع: مسافة اللمس بينهما (SPEC 16.2) لا 4dp فقط.
    final spacing = math.max(iconSize + 4, minTouch + 1);
    final width = iconSize + (n - 1) * spacing;
    final c = slot(run.start, run.length, width);
    if (c == null) {
      hidden++;
      continue;
    }
    groups.add(
      WeatherGroup(
        kind: WeatherGroupKind.durur,
        start: run.start,
        length: run.length,
        center: c,
        width: width,
        marks: [
          for (var q = 0; q < n; q++)
            WeatherMark(run.weather[q], ((n - 1) / 2 - q) * spacing),
        ],
      ),
    );
  }
  return WeatherLayout(groups, hidden);
}

bool _sameList(List<WeatherSymbol> a, List<WeatherSymbol> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// موضع رمز على الشاشة بالنسبة لمركز الدائرة غير المكبّرة، بعد التدوير
/// [rotation]. [radius] منتصف الحلقة A، و[zoom] التكبير. الإزاحة باتجاه بداية
/// القراءة: مع عقارب الساعة في النصف العلوي، وعكسها في السفلي (الاسم مقلوب
/// ليبقى قائماً).
(double x, double y) markPosition(
  DialGeometry geo,
  WeatherGroup group,
  double offset,
  double rotation,
  double radius,
  double zoom,
) {
  final a = groupAngle(geo, group, offset, rotation, radius, zoom);
  return DialGeometry.polar(a, radius);
}

/// زاوية نقطة على بعد [offset] (نقاط شاشة) من مركز [group].
double groupAngle(
  DialGeometry geo,
  WeatherGroup group,
  double offset,
  double rotation,
  double radius,
  double zoom,
) {
  final c = geo.angleOf(group.center, rotation);
  final top = math.cos(c) >= 0;
  return c + (top ? offset : -offset) / (radius * zoom);
}

/// أقرب رمز ظاهر ضمن نصف منطقة اللمس (24 نقطة على الشاشة) من النقطة
/// ([dx], [dy]) بنقاط الدائرة غير المكبّرة، أو null.
({WeatherGroup group, WeatherMark mark})? hitWeatherMark(
  WeatherLayout layout,
  DialGeometry geo,
  double dx,
  double dy,
  double rotation,
  double zoom,
) {
  final radius = geo.weatherMid;
  final limit = minTouch / 2 / zoom;
  ({WeatherGroup group, WeatherMark mark})? best;
  var bestDistance = double.infinity;
  for (final g in layout.groups) {
    for (final m in g.marks) {
      final (x, y) = markPosition(geo, g, m.offset, rotation, radius, zoom);
      final d = math.sqrt((x - dx) * (x - dx) + (y - dy) * (y - dy));
      if (d <= limit && d < bestDistance) {
        bestDistance = d;
        best = (group: g, mark: m);
      }
    }
  }
  return best;
}
