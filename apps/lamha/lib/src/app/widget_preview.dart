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
import 'kaaba.dart';

part 'widget_preview_tiles.dart';

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
/// معامل الخط. الساعة ٥٢ (و٤٢ في الودجت الضيقة بأندرويد)، وتصغر بقدر عرض مربعها فقط (fitTile).
const clockSize = 52.0;
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
const _lineTiles = {
  'clock',
  'dates',
  'weather',
  'dayWeather',
  datesWeatherCell,
};

/// حشوة الودجت، والتباعد بين المربعات والصفوف.
const widgetPadding = 14.0;
const tileSpacing = 8.0;

/// معامل حجم الخط العام من الجدول (١ لجدول أقدم بلاه).
double scheduleFontScale(Map<String, Object?> schedule) =>
    (schedule['fontScale'] as num?)?.toDouble() ?? 1.0;

/// شكل الأرقام من الجدول (عربية لجدول أقدم بلاه).
DigitStyle scheduleDigits(Map<String, Object?> schedule) =>
    DigitStyle.byName(schedule['digits'] as String?);

/// مربع من تخطيط الجدول (الميزة ٥): المعامل رقماً واللونان ARGB أو null (تلقائي).
typedef ScheduleTile = ({
  WidgetElement id,
  bool visible,
  int span,
  double fontScale,
  bool showTitle,
  bool showSub,
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
            showTitle: t['showTitle'] as bool? ?? true,
            showSub: t['showSub'] as bool? ?? true,
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
        fontScale: t.fontScale,
        showTitle: true,
        showSub: true,
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
    final digits = scheduleDigits(schedule);
    final reading = freshWeather(scheduleWeather(schedule), now);
    final weather = weatherText(reading, now, digits) ?? l.weatherUnknown;
    final global = scheduleFontScale(schedule);

    final layout = scheduleLayout(schedule);
    final byId = {for (final t in layout) t.id: t};
    final rows = packRows(
      stackCells([
        for (final t in layout)
          if (t.visible) (id: t.id.name, span: t.span),
      ]),
    );

    final placed = placedElements([
      for (final t in layout)
        if (t.visible) (id: t.id.name, span: t.span),
    ]);

    _Cell tileFor(WidgetElement e, int span) {
      final t = byId[e]!;
      final _Cell tile = switch (e) {
        WidgetElement.clock => _Tile.clock(
          time: formatDigits(arabicClock(local), digits),
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
        WidgetElement.prayer => _prayerTile(l, accent, day, nextDay, digits),
        WidgetElement.qibla => _QiblaTile(title: l.tileQibla),
        WidgetElement.deposit => _DepositsTile(
          title: l.depositsTitle,
          items: [
            for (final d in (day['deposits'] as List).cast<Map>().take(
              math.min(3, span),
            ))
              (name: d['label'] as String, sub: d['daysText'] as String),
          ],
        ),
        WidgetElement.season => _seasonTile(l, day),
        WidgetElement.tradSeason => _tradSeasonTile(
          l,
          day,
          withDescription: !placed.contains(WidgetElement.tradPoints.name),
        ),
        WidgetElement.dayWeather => _DayWeatherTile(
          weekday: day['weekday'] as String,
          city: l.cityIcon(
            city['name'] as String,
            reading == null ? '' : weatherCondition(reading.code).emoji,
          ).trim(),
          temp: reading == null
              ? l.weatherUnknown
              : temperatureText(reading.temp, digits),
        ),
        WidgetElement.hijri => _CapsuleTile(
          kind: e,
          text: l.hijriDateText((day['hijri'] as Map)['text'] as String),
        ),
        WidgetElement.gregorian => _CapsuleTile(
          kind: e,
          text: l.gregorianDateText(
            (day['gregorian'] as Map)['text'] as String,
          ),
        ),
        WidgetElement.prayerTimes => _PrayerTimesTile(
          items: [
            for (final p in rotatePrayers(
              _slots(day),
              nextDay == null ? null : _slots(nextDay),
              now,
            ))
              (name: p.name, sub: p.text),
          ],
          accent: accent,
        ),
        WidgetElement.tradPoints => _PointsTile(
          title: l.tradPointsTitle(
            ((day['tradSeason'] as Map)['name'] as String),
          ),
          points: [
            for (final p
                in ((day['tradSeason'] as Map)['points'] as List? ?? const [])
                    .cast<String>())
              l.pointText(p),
          ],
        ),
      };
      return tile.styled(
        scale: global * t.fontScale,
        showTitle: t.showTitle,
        showSub: t.showSub,
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
                  tileFor(WidgetElement.values.byName(id), cell.span),
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
              [
                for (final t in tiles[r][i])
                  t.base.heights(context, widthOf(r, i)),
              ],
          ],
      ];
      double sumOf(List<({double text, double pad})> h, bool text) =>
          h.fold<double>(0, (a, x) => a + (text ? x.text : x.pad));
      // مقاس المربعات بالحجم الأساسي (١) لا بحجم الخط المختار، فلا يتغير بتغيّره (الميزة ٥ب): كل
      // صف بوزن أطول خانة فيه، وصفوف المربعات تقتسم الباقي، وصفوف الساعة والتاريخين والمدينة بقدر
      // محتواها. ثم يلائم كل مربع نصه بحجمه المطلوب داخل مقاسه (fitTile).
      // كل صف بأطول خانة فيه (نصها وحشوتها معاً).
      final tallest = [
        for (final r in sizes)
          r
              .map((h) => (text: sumOf(h, true), pad: sumOf(h, false)))
              .reduce((a, b) => a.text + a.pad >= b.text + b.pad ? a : b),
      ];
      final fit = rowHeights(
        [for (final t in tallest) t.text],
        [for (final t in tallest) t.pad],
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
            tiles[r][i].first,
          );
        }
        // الكبسولتان تقتسمان الخانة بالتساوي.
        if (rows[r][i].id == hijriGregorianCell) {
          return Column(
            children: [
              for (var k = 0; k < ids.length; k++)
                Expanded(
                  child: _tap(
                    WidgetElement.values.byName(ids[k]),
                    tiles[r][i][k],
                  ),
                ),
            ],
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
                  tiles[r][i][k],
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
          borderRadius: BorderRadius.circular(tileRadius),
          border: selected == e
              ? Border.all(color: Colors.white, width: 2)
              : null,
        ),
        child: keyed,
      ),
    );
  }

  /// صلوات يوم من الجدول (لـ [rotatePrayers]).
  static List<PrayerSlot> _slots(Map day) => [
    for (final e in (day['prayers'] as Map).cast<String, Map>().entries)
      (
        key: e.key,
        name: e.value['name'] as String,
        time: DateTime.parse(e.value['time'] as String),
        text: e.value['text'] as String,
      ),
  ];

  _Tile _prayerTile(
    AppLocalizations l,
    Color accent,
    Map day,
    Map? nextDay,
    DigitStyle digits,
  ) {
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
        if (next != null)
          (text: next['text'] as String, lines: 1, compact: null),
        // العدّاد لا يُختصر: بلا «باقي» إن لم يتسع، ثم يصغر قليلاً، وإلا يُخفى.
        if (at != null)
          (
            text: l.countdownText(
              formatDigits(countdownClock(at.difference(now)), digits),
            ),
            lines: 1,
            compact: formatDigits(countdownClock(at.difference(now)), digits),
          ),
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
          text: l.nextAfter(
            (s['next'] as Map)['name'] as String,
            s['afterText'] as String,
          ),
          lines: 2,
          compact: null,
        ),
      ],
    );
  }

  /// الوصف سطر ثانوي إن لم يظهر مربع «وصف الموسم» ([withDescription]).
  _Tile _tradSeasonTile(
    AppLocalizations l,
    Map day, {
    required bool withDescription,
  }) {
    final s = day['tradSeason'] as Map;
    final description = withDescription ? s['description'] as String : '';
    return _Tile(
      kind: WidgetElement.tradSeason,
      title: l.tileTradSeason,
      value: s['name'] as String,
      subs: [
        (
          text: l.nextAfter(
            (s['next'] as Map)['name'] as String,
            s['afterText'] as String,
          ),
          lines: description.isEmpty ? 2 : 1,
          compact: null,
        ),
        if (description.isNotEmpty)
          (text: description, lines: 2, compact: null),
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

/// سطر ثانوي: [lines] حده الأقصى، و[compact] صيغته المختصرة إن كان لا يُختصر بـ«…» (العدّاد).
typedef _Sub = ({String text, int lines, String? compact});

/// عرض كلمات [text] (للالتفاف عند المسافات فقط) وعرض المسافة بينها، بالحجم [style].
({List<double> words, double space}) _words(
  BuildContext context,
  String text,
  TextStyle style,
) {
  final parts = text.split(' ').where((w) => w.isNotEmpty).toList();
  final words = [for (final w in parts) _measure(context, w, style)];
  final sum = words.fold<double>(0, (a, b) => a + b);
  final space = parts.length > 1
      ? math.max(0.0, (_measure(context, parts.join(' '), style) - sum)) /
            (parts.length - 1)
      : 0.0;
  return (words: words, space: space);
}

/// مربع واحد: مربعات المعلومات الخمسة (عنوان وقيمة وثانويات في صندوق)، أو الساعة واليوم، أو
/// أسطر بلا صندوق (التاريخان، المدينة والطقس) كما كان الصف العلوي.
/// الحجم المطلوب يُحترم داخل مقاس المربع (fitTile، الميزة ٥ب): تُخفى الأسطر الأقل أولية قبل أي تصغير.
class _Tile extends _Cell {
  const _Tile({
    required this.kind,
    required this.title,
    required this.value,
    this.subs = const [],
    this.highlight,
    this.hideFirstSub = false,
  }) : lines = const [],
       time = null,
       amPmText = null,
       accent = null,
       scale = 1,
       showTitle = true,
       showSub = true,
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
       subs = const [],
       lines = const [],
       highlight = null,
       hideFirstSub = false,
       scale = 1,
       showTitle = true,
       showSub = true,
       primary = null,
       secondary = null;

  const _Tile.lines({required this.kind, required this.lines})
    : title = null,
      value = '',
      subs = const [],
      highlight = null,
      hideFirstSub = false,
      time = null,
      amPmText = null,
      accent = null,
      scale = 1,
      showTitle = true,
      showSub = true,
      primary = null,
      secondary = null;

  _Tile._copy(
    _Tile t, {
    required this.scale,
    required this.showTitle,
    required this.showSub,
    required this.primary,
    required this.secondary,
  }) : kind = t.kind,
       title = t.title,
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

  /// قيمة المربع، أو اليوم في مربع الساعة.
  final String value;

  /// الثانويات بترتيب عرضها. الأخير ذو الأسطر المتعددة يأخذ ما يتسع منها.
  final List<_Sub> subs;
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

  /// معامل الخط المطلوب (العام × المربع).
  final double scale;

  /// مفتاحا «إظهار العنوان» و«إظهار السطر الفرعي».
  final bool showTitle;
  final bool showSub;

  /// لونا الخط؛ null = تلقائي.
  final Color? primary;
  final Color? secondary;

  @override
  _Tile styled({
    required double scale,
    required bool showTitle,
    required bool showSub,
    Color? primary,
    Color? secondary,
  }) => _Tile._copy(
    this,
    scale: scale,
    showTitle: showTitle,
    showSub: showSub,
    primary: primary,
    secondary: secondary,
  );

  /// المربع بالحجم الأساسي وكل أسطره، لحساب مقاس الشبكة (لا يتغير بحجم الخط). والعنوان والسطر
  /// الفرعي المطفآن لا يأخذان مكاناً (الميزة ٦).
  @override
  _Tile get base => _Tile._copy(
    this,
    scale: 1,
    showTitle: showTitle,
    showSub: showSub,
    primary: primary,
    secondary: secondary,
  );

  /// ارتفاع المربع في عرض [width]: [text] نصه، و[pad] ما لا يتغير (الحشوات، والساعة إن صغّرها
  /// العرض).
  @override
  ({double text, double pad}) heights(BuildContext context, double width) {
    if (time != null) {
      final font = clockSize * scale * _clockFit(context, width);
      final weekday = showSub ? weekdaySize * weekdayLineHeight * scale : 0.0;
      return font < clockSize * scale
          ? (text: weekday, pad: font)
          : (text: font + weekday, pad: 0);
    }
    if (lines.isNotEmpty) {
      return (
        text:
            lines
                .take(showSub ? lines.length : 1)
                .fold<double>(0, (a, l) => a + l.size) *
            headLineHeight *
            scale,
        pad: 0,
      );
    }
    return (
      text:
          ((showTitle ? tileTitleSize : 0) +
              tileValueSize +
              (showSub ? subs.length : 0) * tileSubSize) *
          tileLineHeight *
          scale,
      pad: tilePadV * 2 + tileGap * ((showSub ? subs.length : 0) + 1),
    );
  }

  TextStyle get _clockStyle => TextStyle(
    fontSize: clockSize * scale,
    height: 1,
    fontWeight: FontWeight.w700,
    color: _primary,
  );

  /// عرض الساعة (أعرض نص لها) و«ص/م» بجانبها، بالحجم المطلوب.
  double _clockWidth(BuildContext context) =>
      _measure(context, widestClockText, _clockStyle) +
      4 +
      _measure(context, amPmText!, _amPmStyle);

  /// معامل الساعة ليتسع عرضها في [width] (كلمة واحدة: أدنى تصغير).
  double _clockFit(BuildContext context, double width) {
    final w = _clockWidth(context);
    return w > width - fitMargin ? (width - fitMargin) / w : 1.0;
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
      final weekdayStyle = TextStyle(
        fontSize: weekdaySize * scale,
        fontWeight: FontWeight.w700,
        height: weekdayLineHeight,
        color: _secondary,
      );
      // الساعة كلمة واحدة: تصغر فقط إن لم يتسع عرضها. اليوم يُخفى قبل أن تصغر لضيق الارتفاع.
      final fit = fitTile(
        height: c.maxHeight,
        width: c.maxWidth - fitMargin,
        valueLineHeight: clockSize * scale,
        valueWords: [_clockWidth(context)],
        subs: [
          if (showSub)
            (
              height: weekdaySize * scale * weekdayLineHeight,
              maxLines: 1,
              fitWidth: _measure(context, value, weekdayStyle),
            ),
        ],
        minSubFit: headMinFit,
      );
      final k = fit.valueScale;
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
              // أمان: إن لم يتسع (فرق قياس) يصغر كله ولا يُقص.
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
                      style: _clockStyle.copyWith(
                        fontSize: clockSize * scale * k,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      amPmText!,
                      textAlign: TextAlign.right,
                      style: _amPmStyle.copyWith(
                        fontSize: amPmSize * scale * k,
                      ),
                    ),
                  ],
                ),
              ),
              if (fit.subs.isNotEmpty)
                Text(
                  value,
                  key: const Key('preview-weekday'),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: weekdayStyle.copyWith(
                    fontSize: weekdaySize * scale * fit.subScales.first,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );

  /// التاريخان أو المدينة والطقس: الأول قيمة تلتفّ عند المسافات، والميلادي يُخفى إن لم يتسع.
  Widget _lines(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      TextStyle styleOf(int i) => TextStyle(
        fontSize: lines[i].size * scale,
        fontWeight: lines[i].bold ? FontWeight.w700 : FontWeight.w400,
        color: i == 0 ? _primary : _secondary,
        height: headLineHeight,
      );
      final first = _words(context, lines.first.text, styleOf(0));
      final fit = fitTile(
        height: c.maxHeight,
        width: c.maxWidth - fitMargin,
        valueLineHeight: lines.first.size * scale * headLineHeight,
        valueWords: first.words,
        valueSpace: first.space,
        subs: [
          if (showSub)
            for (var i = 1; i < lines.length; i++)
              (
                height: lines[i].size * scale * headLineHeight,
                maxLines: 1,
                fitWidth: _measure(context, lines[i].text, styleOf(i)),
              ),
        ],
        minSubFit: headMinFit,
      );
      Text line(int i, double factor, int maxLines) => Text(
        lines[i].text,
        key: lines[i].key,
        textAlign: TextAlign.right,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: styleOf(i).copyWith(fontSize: lines[i].size * scale * factor),
      );
      return ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              line(0, fit.valueScale, fit.valueLines),
              for (final (j, i) in fit.subs.indexed)
                line(i + 1, fit.subScales[j], 1),
            ],
          ),
        ),
      );
    },
  );

  Widget _box(BuildContext context) {
    final h = highlight;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tileRadius),
        // مربع الصلاة: لون التمييز بألفا ثابتة (كـ setImageAlpha في أندرويد)، وغيره رمادي مزرق.
        color: h?.withValues(alpha: 0.18) ?? tileBoxColor,
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
            final width = c.maxWidth - fitMargin;
            final titleStyle = TextStyle(
              fontSize: tileTitleSize * scale,
              fontWeight: FontWeight.w700,
              color: _secondary,
              height: tileLineHeight,
            );
            // العنوان يصغر حتى يتسع سطراً واحداً، وإلا يُخفى.
            final t = title!;
            final titleSize = fitTextSize(
              tileTitleSize * scale,
              _measure(context, t, titleStyle),
              width,
              tileTitleSize * scale * tileMinFit,
            );
            final valueStyle = TextStyle(
              fontSize: tileValueSize * scale,
              fontWeight: FontWeight.w700,
              color: _primary,
              height: tileLineHeight,
            );
            final subStyle = TextStyle(
              fontSize: tileSubSize * scale,
              color: _secondary,
              height: tileLineHeight,
            );
            // العدّاد بلا «باقي» إن لم يتسع.
            final texts = [
              for (final s in subs)
                s.compact != null && _measure(context, s.text, subStyle) > width
                    ? s.compact!
                    : s.text,
            ];
            final words = _words(context, value, valueStyle);
            final fit = fitTile(
              height: c.maxHeight,
              width: width,
              // العنوان الذي لا يتسع حتى بأدنى حجم يُخفى (لا «…»).
              titleHeight:
                  showTitle &&
                      _measure(
                            context,
                            t,
                            titleStyle.copyWith(fontSize: titleSize),
                          ) <=
                          width + 0.5
                  ? titleSize * tileLineHeight
                  : 0,
              valueLineHeight: tileValueSize * scale * tileLineHeight,
              valueWords: words.words,
              valueSpace: words.space,
              subs: [
                if (showSub)
                  for (final (i, s) in subs.indexed)
                    (
                      height: tileSubSize * scale * tileLineHeight,
                      maxLines: s.lines,
                      fitWidth: s.compact != null
                          ? _measure(context, texts[i], subStyle)
                          : 0,
                    ),
              ],
              hideFromStart: hideFirstSub,
              gap: tileGap,
            );
            return ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fit.title) ...[
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
                    ],
                    Text(
                      value,
                      key: const Key('tile-value'),
                      textAlign: TextAlign.right,
                      maxLines: fit.valueLines,
                      overflow: TextOverflow.ellipsis,
                      style: valueStyle.copyWith(
                        fontSize: tileValueSize * scale * fit.valueScale,
                      ),
                    ),
                    for (final (j, i) in fit.subs.indexed) ...[
                      const SizedBox(height: tileGap),
                      Text(
                        texts[i],
                        key: Key('tile-sub-$j'),
                        textAlign: TextAlign.right,
                        // الأخير وحده يأخذ أسطراً إضافية إن اتسعت.
                        maxLines: j == fit.subs.length - 1
                            ? fit.lastSubLines
                            : 1,
                        overflow: TextOverflow.ellipsis,
                        style: subStyle.copyWith(
                          fontSize: tileSubSize * scale * fit.subScales[j],
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
