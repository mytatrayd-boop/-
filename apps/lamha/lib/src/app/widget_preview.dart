import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/prayer.dart';
import '../engine/weather.dart';
import '../engine/widget_layout.dart';
import '../engine/widget_theme.dart';

/// مقاس الودجت الكبيرة في آيفون (DESIGN، mockups/widget-large-v2.png).
const previewWidgetSize = Size(338, 354);

/// ألفا خلفية الودجت من قيمة الشريط (ARCHITECTURE: ألفا = قيمة الشريط).
double backgroundAlpha(int opacity) => opacity.clamp(0, 100) / 100;

/// اسم مسبوق بلام الجر: «الشتاء» ← «للشتاء»، «سهيل» ← «لسهيل».
String withLam(String name) =>
    name.startsWith('ال') ? 'لل${name.substring(2)}' : 'ل$name';

/// ألوان النص التلقائية (DESIGN)؛ التمييز والخلفية من سمة الجدول.
const _text = Color(0xFFF4EFE6);
const _muted = Color(0xFFCFC6B8);
const _dim = Color(0xFFB9B0A2);

/// خلفية الشاشة خلف المعاينة.
const _wallTop = Color(0xFF34302B);
const _wallBottom = Color(0xFF0B0A09);

/// أحجام مربعات الساعة والتاريخين والمدينة (الميزة ٣د)، مطابقة لتخطيطاتها في أندرويد، وتُضرب في
/// معامل الخط. الساعة ٥٢ (و٤٢ في الودجت الضيقة بأندرويد)، وتصغر لتتسع في مربعها (fitTextSize).
const clockSize = 52.0;
const clockMinSize = 28.0;
const amPmSize = 18.0;
const weekdaySize = 18.0;
const hijriSize = 18.0;
const gregorianSize = 16.0;
const cityWeatherSize = 16.0;

/// أعرض نص ممكن للساعة، لتثبيت حجمها طوال اليوم.
const widestClockText = '١٢:٥٨';

/// ارتفاع أسطر التاريخين والمدينة، وسطر اليوم تحت الساعة.
const headLineHeight = 1.3;
const weekdayLineHeight = 1.2;

/// خانات بلا صندوق: صفوفها بقدر محتواها، وصفوف المربعات تقتسم الباقي (LINE_TILES في
/// LamhaWidgetReceiver.kt).
const _lineTiles = {'clock', 'dates', 'weather', datesWeatherCell};

/// حشوة الودجت، والتباعد بين المربعات والصفوف.
const widgetPadding = 14.0;
const tileSpacing = 8.0;

/// معامل حجم الخط العام من الجدول (١ لجدول أقدم بلاه).
double scheduleFontScale(Map<String, Object?> schedule) =>
    (schedule['fontScale'] as num?)?.toDouble() ?? 1.0;

/// مربع من تخطيط الجدول (الميزة ٥): المعامل رقماً واللونان ARGB أو null (تلقائي).
typedef ScheduleTile = ({
  WidgetElement id,
  bool visible,
  int span,
  double fontScale,
  int? primary,
  int? secondary,
});

/// تخطيط الجدول بترتيبه. جدول أقدم بلا `layout`: الترتيب الافتراضي والإظهار من `visible`.
List<ScheduleTile> scheduleLayout(Map<String, Object?> schedule) {
  final raw = schedule['layout'];
  final List<TileLayout> base;
  if (raw is List) {
    return [
      for (final t in raw.cast<Map>())
        if (WidgetElement.values.any((e) => e.name == t['id']))
          (
            id: WidgetElement.values.byName(t['id'] as String),
            visible: t['visible'] as bool? ?? true,
            span: ((t['span'] as num?)?.toInt() ?? 1).clamp(1, gridColumns),
            fontScale: (t['fontScale'] as num?)?.toDouble() ?? 1.0,
            primary: t['primaryColor'] as int?,
            secondary: t['secondaryColor'] as int?,
          ),
    ];
  }
  final v = (schedule['visible'] as Map?)?.cast<String, bool>() ?? const {};
  base = layoutFromVisible([
    for (final e in v.entries)
      if (e.value) e.key,
  ]);
  return [
    for (final t in base)
      (
        id: t.id,
        visible: t.visible,
        span: t.span,
        fontScale: t.fontScale.factor,
        primary: null,
        secondary: null,
      ),
  ];
}

/// حجم خط يجعل نصاً عرضه [widthAtPreferred] بالحجم [preferred] يتسع في [maxWidth]، دون أن ينزل
/// عن [min]. العرض يتناسب طردياً مع الحجم (fitTextSize في LamhaLogic.kt).
double fitTextSize(
  double preferred,
  double widthAtPreferred,
  double maxWidth,
  double min,
) {
  if (widthAtPreferred <= 0 || widthAtPreferred <= maxWidth) return preferred;
  return math.max(min, preferred * maxWidth / widthAtPreferred);
}

/// أسطر سطر ثانوي أخير بحد [maxLines]: ما يتسع في [remaining] بعد بقية المحتوى، ولا يقل عن ١.
int fittingLines(double remaining, double lineHeight, int maxLines) {
  if (lineHeight <= 0) return maxLines;
  return (1 + (remaining / lineHeight).floor()).clamp(1, maxLines);
}

/// لونا الودجت من الجدول: ألوان النظام لسمة «ألوان النظام» إن توفرت (أندرويد ١٢+)، وإلا ألوان السمة.
({Color accent, Color background}) scheduleColors(
  Map<String, Object?> schedule,
  SystemColors? system,
) {
  final t = (schedule['theme'] as Map?)?.cast<String, Object?>();
  final theme = WidgetTheme.byName(t?['id'] as String?);
  final c = theme == WidgetTheme.system && system != null
      ? system
      : (
          accent: (t?['accent'] as int?) ?? theme.accent,
          background: (t?['background'] as int?) ?? theme.background,
        );
  return (accent: Color(c.accent), background: Color(c.background));
}

/// آخر قراءة طقس في الجدول، أو null.
WeatherReading? scheduleWeather(Map<String, Object?> schedule) {
  final w = (schedule['weather'] as Map?)?.cast<String, dynamic>();
  if (w == null || w['temp'] == null) return null;
  return WeatherReading.fromJson(w);
}

/// قياس عرض نص سطراً واحداً.
double _measure(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: TextDirection.rtl,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final w = painter.width;
  painter.dispose();
  return w;
}

/// معاينة الودجت الكبيرة، تُبنى من الجدول نفسه الذي يُحفظ للودجت.
/// هي المرجع لتخطيط ودجت أندرويد (LamhaWidgetReceiver.kt): المربعات من `layout` تُرصّ في صفوف
/// بـ [packRows]، وارتفاع الصفوف بوزن المحتوى بـ [rowHeights].
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.schedule,
    required this.now,
    this.backgroundPath,
    this.systemColors,
    this.onTileTap,
    this.selected,
  });

  final Map<String, Object?> schedule;
  final DateTime now;

  /// لقطة الخلفية (آيفون) لتظهر خلف المعاينة.
  final String? backgroundPath;

  /// ألوان النظام (أندرويد ١٢+) لسمة «ألوان النظام».
  final SystemColors? systemColors;

  /// الضغط على مربع (شاشة «تخصيص الودجت»)؛ null = بلا ضغط.
  final ValueChanged<WidgetElement>? onTileTap;

  /// مربع يُبرز بإطار (المفتوحة إعداداته).
  final WidgetElement? selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final radius = Theme.of(context).platform == TargetPlatform.iOS
        ? 22.0
        : 28.0;
    final colors = scheduleColors(schedule, systemColors);
    final accent = colors.accent;
    final opacity = schedule['opacity']! as int;
    final alpha = backgroundAlpha(opacity);
    // ظل للنص إذا زادت الشفافية عن ٦٠٪ (DESIGN).
    final shadows = alpha < 0.4
        ? const [Shadow(color: Color(0x99000000), blurRadius: 3)]
        : null;

    final city = schedule['city']! as Map;
    final loc = timeZone(city['timeZone'] as String);
    final local = tz.TZDateTime.from(now, loc);
    final days = (schedule['days']! as List).cast<Map>();
    var idx = days.indexWhere((d) => d['date'] == isoDate(local));
    if (idx < 0) idx = 0;
    final day = days[idx];
    final nextDay = idx + 1 < days.length ? days[idx + 1] : null;
    final weather =
        weatherText(scheduleWeather(schedule), now) ?? l.weatherUnknown;
    final global = scheduleFontScale(schedule);

    final layout = scheduleLayout(schedule);
    final byId = {for (final t in layout) t.id: t};
    final rows = packRows(
      stackCells([
        for (final t in layout)
          if (t.visible) (id: t.id.name, span: t.span),
      ]),
    );

    _Tile tileFor(WidgetElement e) {
      final t = byId[e]!;
      final tile = switch (e) {
        WidgetElement.clock => _Tile.clock(
          time: arabicClock(local),
          amPm: amPm(local),
          weekday: day['weekday'] as String,
          accent: accent,
        ),
        WidgetElement.dates => _Tile.lines(
          kind: e,
          lines: [
            (
              text: l.hijriDateText((day['hijri'] as Map)['text'] as String),
              size: hijriSize,
              bold: true,
              key: const Key('preview-hijri'),
            ),
            (
              text: l.gregorianDateText(
                (day['gregorian'] as Map)['text'] as String,
              ),
              size: gregorianSize,
              bold: false,
              key: const Key('preview-gregorian'),
            ),
          ],
        ),
        WidgetElement.weather => _Tile.lines(
          kind: e,
          lines: [
            (
              text: l.cityWeather(city['name'] as String, weather),
              size: cityWeatherSize,
              bold: false,
              key: const Key('preview-weather'),
            ),
          ],
        ),
        WidgetElement.prayer => _prayerTile(l, accent, day, nextDay),
        WidgetElement.qibla => _qiblaTile(l),
        WidgetElement.deposit => _depositTile(l, day),
        WidgetElement.season => _seasonTile(l, day),
        WidgetElement.tradSeason => _tradSeasonTile(l, day),
      };
      return tile.styled(
        scale: global * t.fontScale,
        primary: t.primary == null ? null : Color(t.primary!),
        secondary: t.secondary == null ? null : Color(t.secondary!),
      );
    }

    Widget grid(BuildContext context, BoxConstraints c) {
      // كل خانة مربع واحد، أو التاريخان وتحتهما المدينة والطقس (stackCells).
      final tiles = [
        for (final row in rows)
          [
            for (final cell in row)
              [
                for (final id in cellElements(cell.id))
                  tileFor(WidgetElement.values.byName(id)),
              ],
          ],
      ];
      // ارتفاعا كل مربع بعرضه: عرض [span] في صف من [k] مربعات (كتوزيع Expanded).
      double widthOf(int r, int i) =>
          (c.maxWidth - tileSpacing * (rows[r].length - 1)) *
          rows[r][i].span /
          gridColumns;
      final sizes = [
        for (var r = 0; r < rows.length; r++)
          [
            for (var i = 0; i < rows[r].length; i++)
              [for (final t in tiles[r][i]) t.heights(context, widthOf(r, i))],
          ],
      ];
      double sumOf(List<({double text, double pad})> h, bool text) =>
          h.fold<double>(0, (a, x) => a + (text ? x.text : x.pad));
      // ارتفاع كل صف بوزن أطول خانة فيه، ومعامل واحد يصغر به النص كله إن لم يتسع. صفوف
      // المربعات تقتسم الباقي، وصفوف الساعة والتاريخين والمدينة بقدر محتواها.
      final fit = rowHeights(
        [for (final r in sizes) r.map((h) => sumOf(h, true)).reduce(math.max)],
        [for (final r in sizes) r.map((h) => sumOf(h, false)).reduce(math.max)],
        c.maxHeight,
        tileSpacing,
        flexible: [
          for (final r in rows) r.any((cell) => !_lineTiles.contains(cell.id)),
        ],
      );
      Widget cellWidget(int r, int i) {
        final ids = cellElements(rows[r][i].id);
        if (ids.length == 1) {
          return _tap(
            WidgetElement.values.byName(ids.first),
            tiles[r][i].first.fitted(fit.scale),
          );
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var k = 0; k < ids.length; k++)
              SizedBox(
                height: sizes[r][i][k].text * fit.scale + sizes[r][i][k].pad,
                child: _tap(
                  WidgetElement.values.byName(ids[k]),
                  tiles[r][i][k].fitted(fit.scale),
                ),
              ),
          ],
        );
      }

      return Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: tileSpacing),
            SizedBox(
              height: fit.heights[r],
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows[r].length; i++) ...[
                    if (i > 0) const SizedBox(width: tileSpacing),
                    Expanded(flex: rows[r][i].span, child: cellWidget(r, i)),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }

    final widgetBox = DecoratedBox(
      key: const Key('preview-background'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: colors.background.withValues(alpha: alpha),
      ),
      child: Padding(
        padding: const EdgeInsets.all(widgetPadding),
        child: DefaultTextStyle.merge(
          style: TextStyle(shadows: shadows),
          child: LayoutBuilder(builder: grid),
        ),
      ),
    );

    final bg = backgroundPath;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        image: bg != null
            ? DecorationImage(image: FileImage(File(bg)), fit: BoxFit.cover)
            : null,
        gradient: bg == null
            ? const RadialGradient(
                center: Alignment(0.4, -0.8),
                radius: 1.2,
                colors: [_wallTop, _wallBottom],
              )
            : null,
      ),
      child: Center(
        child: FittedBox(
          child: SizedBox.fromSize(size: previewWidgetSize, child: widgetBox),
        ),
      ),
    );
  }

  Widget _tap(WidgetElement e, Widget child) {
    final keyed = KeyedSubtree(key: Key('tile-${e.name}'), child: child);
    final tap = onTileTap;
    if (tap == null) return keyed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => tap(e),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: selected == e
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
        child: keyed,
      ),
    );
  }

  _Tile _prayerTile(AppLocalizations l, Color accent, Map day, Map? nextDay) {
    Map? next;
    DateTime? at;
    final today = (day['prayers'] as Map).cast<String, Map>();
    for (final e in today.entries) {
      if (e.key == PrayerName.sunrise.name) continue;
      final t = DateTime.parse(e.value['time'] as String);
      if (t.isAfter(now)) {
        next = e.value;
        at = t;
        break;
      }
    }
    if (next == null && nextDay != null) {
      next = (nextDay['prayers'] as Map)['fajr'] as Map;
      at = DateTime.parse(next['time'] as String);
    }
    // الاسم، ثم وقت الصلاة، ثم العدّاد بصيغة Chronometer (كما في LamhaWidgetReceiver.kt).
    return _Tile(
      kind: WidgetElement.prayer,
      title: l.tilePrayer,
      highlight: accent,
      hideFirstSub: true,
      value: (next?['name'] as String?) ?? '',
      subs: [
        if (next != null) (text: next['text'] as String, lines: 1),
        if (at != null)
          (text: l.countdownText(countdownClock(at.difference(now))), lines: 1),
      ],
    );
  }

  _Tile _qiblaTile(AppLocalizations l) {
    final q = schedule['qibla']! as Map;
    final deg = (q['degrees'] as num).toDouble();
    // الزاوية، ثم الاتجاه.
    return _Tile(
      kind: WidgetElement.qibla,
      title: l.tileQibla,
      value: l.degrees(arabicDigits(deg.round())),
      subs: [(text: q['direction'] as String, lines: 1)],
    );
  }

  _Tile _depositTile(AppLocalizations l, Map day) {
    final deps = (day['deposits'] as List).cast<Map>();
    final first = deps.first;
    final two = deps.length > 1;
    // مع إيداعين: الاسم، ثم الباقي، ثم الثاني «راتب أكتوبر · باقي ٨ أيام» كاملاً إن اتسع وإلا بـ«…».
    // «الإيداع القادم» إن اتسع سطراً واحداً، وإلا «الإيداع» (كما في LamhaWidgetReceiver.kt).
    return _Tile(
      kind: WidgetElement.deposit,
      title: l.tileDeposit,
      shortTitle: l.tileDepositShort,
      value: first['label'] as String,
      subs: [
        (text: first['remainingText'] as String, lines: two ? 1 : 2),
        if (two)
          (text: '${deps[1]['label']} · ${deps[1]['remainingText']}', lines: 1),
      ],
    );
  }

  _Tile _seasonTile(AppLocalizations l, Map day) {
    final s = day['season'] as Map;
    return _Tile(
      kind: WidgetElement.season,
      title: l.tileSeason,
      value: s['name'] as String,
      subs: [
        (
          text: l.remainingToNext(
            s['remainingText'] as String,
            withLam((s['next'] as Map)['name'] as String),
          ),
          lines: 2,
        ),
      ],
    );
  }

  _Tile _tradSeasonTile(AppLocalizations l, Map day) {
    final s = day['tradSeason'] as Map;
    final description = s['description'] as String;
    return _Tile(
      kind: WidgetElement.tradSeason,
      title: l.tileTradSeason,
      value: s['name'] as String,
      subs: [
        (
          text: l.remainingToNext(
            s['remainingText'] as String,
            withLam((s['next'] as Map)['name'] as String),
          ),
          lines: 1,
        ),
        if (description.isNotEmpty) (text: description, lines: 2),
      ],
    );
  }
}

/// أحجام المربعات (الميزة ٣د، بلا رموز): العنوان ١٣ عريض، والقيمة ٢٠ عريض، والثانوي ١٤، كلها
/// × معامل الخط، من الأعلى بتباعد ثابت [tileGap]. مطابقة لـ widget_tile_content.xml.
/// العنوان والقيمة سطر واحد يصغر خطه ليتسع (ثم «…»)، والثانوي بحد أسطر و«…».
const tileTitleSize = 13.0;
const tileValueSize = 20.0;
const tileSubSize = 14.0;
const tileGap = 3.0;
const tileLineHeight = 1.25;

/// حشوة المربع الرأسية (٨ + ٨) والأفقية (٩ + ٩).
const tilePadV = 8.0;
const tilePadH = 9.0;

/// هامش أمان (بكسل) عند قياس ما يتسع سطراً واحداً، كي لا يُقص بفرق التقريب.
const fitMargin = 2.0;

/// أدنى حجم للعنوان والقيمة عند تصغيرهما ليتسعا (نسبة من حجمهما).
const tileMinFit = 0.7;

/// أدنى حجم لسطور التاريخين والمدينة قبل «…».
const headMinFit = 0.75;

typedef _Line = ({String text, double size, bool bold, Key? key});

/// مربع واحد: مربعات المعلومات الخمسة (عنوان وقيمة وثانويات في صندوق)، أو الساعة واليوم، أو
/// أسطر بلا صندوق (التاريخان، المدينة والطقس) كما كان الصف العلوي.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.kind,
    required this.title,
    required this.value,
    this.shortTitle,
    this.subs = const [],
    this.highlight,
    this.hideFirstSub = false,
  }) : lines = const [],
       time = null,
       amPmText = null,
       accent = null,
       scale = 1,
       primary = null,
       secondary = null;

  const _Tile.clock({
    required this.time,
    required String amPm,
    required String weekday,
    required this.accent,
  }) : kind = WidgetElement.clock,
       amPmText = amPm,
       value = weekday,
       title = null,
       shortTitle = null,
       subs = const [],
       lines = const [],
       highlight = null,
       hideFirstSub = false,
       scale = 1,
       primary = null,
       secondary = null;

  const _Tile.lines({required this.kind, required this.lines})
    : title = null,
      shortTitle = null,
      value = '',
      subs = const [],
      highlight = null,
      hideFirstSub = false,
      time = null,
      amPmText = null,
      accent = null,
      scale = 1,
      primary = null,
      secondary = null;

  _Tile._copy(
    _Tile t, {
    required this.scale,
    required this.primary,
    required this.secondary,
  }) : kind = t.kind,
       title = t.title,
       shortTitle = t.shortTitle,
       value = t.value,
       subs = t.subs,
       highlight = t.highlight,
       hideFirstSub = t.hideFirstSub,
       lines = t.lines,
       time = t.time,
       amPmText = t.amPmText,
       accent = t.accent;

  final WidgetElement kind;
  final String? title;

  /// يحل محل [title] إذا لم يتسع سطراً واحداً.
  final String? shortTitle;

  /// قيمة المربع، أو اليوم في مربع الساعة.
  final String value;

  /// الثانويات: [lines] حدها الأقصى. الأخير ذو الأسطر المتعددة يأخذ ما يتسع منها.
  final List<({String text, int lines})> subs;
  final Color? highlight;

  /// أولوية الإخفاء عند ضيق الارتفاع: الثانويات تُخفى من الآخر، ومع [hideFirstSub] (الصلاة) يُخفى
  /// أولها (الوقت) قبل آخرها (العدّاد)، فلا يُخفى العدّاد أبداً قبل غيره.
  final bool hideFirstSub;

  /// أسطر مربع بلا صندوق: الأول بالخط الرئيسي والبقية بالفرعي.
  final List<_Line> lines;

  /// مربع الساعة.
  final String? time;
  final String? amPmText;
  final Color? accent;

  /// معامل الخط الفعلي (العام × المربع × ما يلزم ليتسع).
  final double scale;

  /// لونا الخط؛ null = تلقائي.
  final Color? primary;
  final Color? secondary;

  _Tile styled({required double scale, Color? primary, Color? secondary}) =>
      _Tile._copy(this, scale: scale, primary: primary, secondary: secondary);

  _Tile fitted(double fit) => _Tile._copy(
    this,
    scale: scale * fit,
    primary: primary,
    secondary: secondary,
  );

  /// ارتفاع المربع في عرض [width]: [text] نصه بالحجم المطلوب (يصغر مع معامل الملاءمة)، و[pad] ما لا
  /// يصغر (الحشوات، والساعة إن صغّرها العرض فلا تصغر أكثر).
  ({double text, double pad}) heights(BuildContext context, double width) {
    if (time != null) {
      final font = _clockFont(context, width);
      final weekday = weekdaySize * weekdayLineHeight * scale;
      return font < clockSize * scale
          ? (text: weekday, pad: font)
          : (text: font + weekday, pad: 0);
    }
    if (lines.isNotEmpty) {
      return (
        text:
            lines.fold<double>(0, (a, l) => a + l.size) *
            headLineHeight *
            scale,
        pad: 0,
      );
    }
    return (
      text:
          (tileTitleSize + tileValueSize + subs.length * tileSubSize) *
          tileLineHeight *
          scale,
      pad: tilePadV * 2 + tileGap * (subs.length + 1),
    );
  }

  /// حجم الساعة: ٥٢ × المعامل، ويصغر (حتى ٢٨) ليتسع أعرض نص لها مع «ص/م» في [width].
  double _clockFont(BuildContext context, double width) {
    final preferred = clockSize * scale;
    return fitTextSize(
      preferred,
      _measure(
        context,
        widestClockText,
        TextStyle(fontSize: preferred, fontWeight: FontWeight.w700),
      ),
      width - 4 - _measure(context, amPmText!, _amPmStyle) - fitMargin,
      clockMinSize,
    );
  }

  TextStyle get _amPmStyle => TextStyle(
    fontSize: amPmSize * scale,
    fontWeight: FontWeight.w700,
    color: _primary,
  );

  Color get _primary =>
      primary ?? (kind == WidgetElement.weather ? _muted : _text);

  Color get _secondary =>
      secondary ??
      switch (kind) {
        WidgetElement.clock => accent ?? _text,
        WidgetElement.dates => _muted,
        _ => _dim,
      };

  @override
  Widget build(BuildContext context) {
    if (time != null) return _clock(context);
    if (lines.isNotEmpty) return _lines(context);
    return _box(context);
  }

  Widget _clock(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final amPmStyle = _amPmStyle;
      // أعرض نص للساعة مع «ص/م» يتسع في المربع، وإلا يصغر (حتى ٢٨).
      final clockFont = _clockFont(context, c.maxWidth);
      final weekdayStyle = TextStyle(
        fontSize: weekdaySize * scale,
        fontWeight: FontWeight.w700,
        height: weekdayLineHeight,
        color: _secondary,
      );
      return ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Column(
            key: const Key('preview-clock-column'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // أمان: إن لم يتسع حتى بأدنى حجم (خط عريض جداً) يصغر كله ولا يُقص.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      time!,
                      key: const Key('preview-clock'),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: clockFont,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      amPmText!,
                      textAlign: TextAlign.right,
                      style: amPmStyle,
                    ),
                  ],
                ),
              ),
              Text(
                value,
                key: const Key('preview-weekday'),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: weekdayStyle.copyWith(
                  fontSize: fitTextSize(
                    weekdayStyle.fontSize!,
                    _measure(context, value, weekdayStyle),
                    c.maxWidth - fitMargin,
                    weekdayStyle.fontSize! * headMinFit,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  /// التاريخان أو المدينة والطقس: أسطر محاذاة يمين، كل سطر يصغر (حتى ٧٥٪) ثم «…».
  Widget _lines(BuildContext context) => LayoutBuilder(
    builder: (context, c) => ClipRect(
      child: OverflowBox(
        alignment: AlignmentDirectional.centerStart,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, line) in lines.indexed)
              // ما بعد الأول يُخفى إن لم يتسع، فلا يُقص.
              if (i == 0 ||
                  lines.take(i + 1).fold<double>(0, (a, l) => a + l.size) *
                          headLineHeight *
                          scale <=
                      c.maxHeight + 0.5)
                Builder(
                  builder: (context) {
                    final style = TextStyle(
                      fontSize: line.size * scale,
                      fontWeight: line.bold ? FontWeight.w700 : FontWeight.w400,
                      color: i == 0 ? _primary : _secondary,
                      height: headLineHeight,
                    );
                    return Text(
                      line.text,
                      key: line.key,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        fontSize: fitTextSize(
                          style.fontSize!,
                          _measure(context, line.text, style),
                          c.maxWidth - fitMargin,
                          style.fontSize! * headMinFit,
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    ),
  );

  Widget _box(BuildContext context) {
    final h = highlight;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // مربع الصلاة: لون التمييز بألفا ثابتة (كـ setImageAlpha في أندرويد).
        color:
            h?.withValues(alpha: 0.18) ?? Colors.white.withValues(alpha: 0.06),
        border: h == null
            ? Border.all(color: Colors.white.withValues(alpha: 0.07))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          tilePadH,
          tilePadV,
          tilePadH,
          tilePadV,
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final titleStyle = TextStyle(
              fontSize: tileTitleSize * scale,
              fontWeight: FontWeight.w700,
              color: _secondary,
              height: tileLineHeight,
            );
            // «الإيداع القادم» ← «الإيداع» إن لم يتسع، ثم تصغير الخط حتى يتسع سطراً واحداً.
            final short = shortTitle;
            final t =
                short != null &&
                    _measure(context, title!, titleStyle) >
                        c.maxWidth - fitMargin
                ? short
                : title!;
            final titleSize = fitTextSize(
              tileTitleSize * scale,
              _measure(context, t, titleStyle),
              c.maxWidth - fitMargin,
              tileTitleSize * scale * tileMinFit,
            );
            final valueStyle = TextStyle(
              fontSize: tileValueSize * scale,
              fontWeight: FontWeight.w700,
              color: _primary,
              height: tileLineHeight,
            );
            final valueSize = fitTextSize(
              tileValueSize * scale,
              _measure(context, value, valueStyle),
              c.maxWidth - fitMargin,
              tileValueSize * scale * tileMinFit,
            );
            final subLine = tileSubSize * scale * tileLineHeight;
            // الثانويات بالترتيب ما اتسع منها، وما بعده يُخفى فلا يُقص سطر في منتصفه.
            var used = (titleSize + valueSize) * tileLineHeight + tileGap;
            var shown = 0;
            while (shown < subs.length &&
                used + tileGap + subLine <= c.maxHeight + 0.5) {
              used += tileGap + subLine;
              shown++;
            }
            final visibleSubs = hideFirstSub
                ? subs.sublist(subs.length - shown)
                : subs.sublist(0, shown);
            final extra = fittingLines(c.maxHeight - used, subLine, 99);
            return ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      t,
                      key: const Key('tile-title'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle.copyWith(fontSize: titleSize),
                    ),
                    const SizedBox(height: tileGap),
                    Text(
                      value,
                      key: const Key('tile-value'),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle.copyWith(fontSize: valueSize),
                    ),
                    for (final (i, s) in visibleSubs.indexed) ...[
                      const SizedBox(height: tileGap),
                      Text(
                        s.text,
                        key: Key('tile-sub-$i'),
                        textAlign: TextAlign.right,
                        // الأخير وحده يأخذ أسطراً إضافية إن اتسعت.
                        maxLines: i == visibleSubs.length - 1
                            ? math.min(s.lines, extra)
                            : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tileSubSize * scale,
                          color: _secondary,
                          height: tileLineHeight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
