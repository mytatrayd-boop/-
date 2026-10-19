import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/prayer.dart';
import '../engine/settings.dart';
import '../engine/weather.dart';
import '../engine/widget_theme.dart';

/// مقاس الودجت الكبيرة في آيفون (DESIGN، mockups/widget-large-v2.png).
const previewWidgetSize = Size(338, 354);

/// مربعات الشبكة بترتيبها من اليمين (DESIGN: الشبكة ٣×٢).
const gridElements = [
  WidgetElement.prayer,
  WidgetElement.qibla,
  WidgetElement.deposit,
  WidgetElement.season,
  WidgetElement.tradSeason,
];

/// توزيع المربعات الظاهرة على صفوف (DESIGN: إعادة الترتيب عند الإخفاء).
/// كل مربع يأخذ مرونة ١، إلا الموسم في صف الخمسة فيأخذ عمودين.
List<List<({WidgetElement element, int flex})>> gridRows(
  List<WidgetElement> shown,
) {
  ({WidgetElement element, int flex}) one(WidgetElement e) =>
      (element: e, flex: 1);
  final n = shown.length;
  if (n == 0) return const [];
  if (n <= 2) return [shown.map(one).toList()];
  if (n == 5) {
    return [
      shown.sublist(0, 3).map(one).toList(),
      [one(shown[3]), (element: shown[4], flex: 2)],
    ];
  }
  // ٣: مربعان ثم واحد بعرض الصف. ٤: مربعان ومربعان.
  return [
    shown.sublist(0, 2).map(one).toList(),
    shown.sublist(2).map(one).toList(),
  ];
}

/// ألفا خلفية الودجت من قيمة الشريط (ARCHITECTURE: ألفا = قيمة الشريط).
double backgroundAlpha(int opacity) => opacity.clamp(0, 100) / 100;

/// اسم مسبوق بلام الجر: «الشتاء» ← «للشتاء»، «سهيل» ← «لسهيل».
String withLam(String name) =>
    name.startsWith('ال') ? 'لل${name.substring(2)}' : 'ل$name';

/// ألوان النص الثابتة (DESIGN)؛ التمييز والخلفية من سمة الجدول.
const _text = Color(0xFFF4EFE6);
const _muted = Color(0xFFCFC6B8);
const _dim = Color(0xFFB9B0A2);

/// خلفية الشاشة خلف المعاينة.
const _wallTop = Color(0xFF34302B);
const _wallBottom = Color(0xFF0B0A09);

/// أحجام الصف العلوي (الميزة ٣د)، مطابقة لـ widget_lamha.xml في أندرويد، وتُضرب في معامل
/// حجم الخط. الساعة ٥٢ (و٤٢ في الودجت الضيقة بأندرويد)، وتصغر إن لم تتسع (fitTextSize).
const clockSize = 52.0;
const clockMinSize = 28.0;
const amPmSize = 18.0;
const weekdaySize = 18.0;
const hijriSize = 18.0;
const gregorianSize = 16.0;
const cityWeatherSize = 16.0;

/// أعرض نص ممكن للساعة، لتثبيت حجمها طوال اليوم.
const widestClockText = '١٢:٥٨';

/// ارتفاع أسطر العمود الأيسر.
const headLineHeight = 1.3;

/// معامل حجم الخط من الجدول (١ لجدول أقدم بلاه).
double scheduleFontScale(Map<String, Object?> schedule) =>
    (schedule['fontScale'] as num?)?.toDouble() ?? 1.0;

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

/// العرض المتاح لأرقام الساعة: ما يبقى بعد العمود الأيسر [leftWidth] (وفاصل ٨)، ولا يقل عن ٤٠٪
/// من [contentWidth] (وما لا يتسع بعدها من العمود الأيسر يصغر خطه)، ناقصاً «ص/م» [amPmWidth] وفاصلها ٤ (clockAvailableDp في LamhaLogic.kt).
double clockAvailableWidth(
  double contentWidth,
  double leftWidth,
  double amPmWidth,
) => math.max(contentWidth - 8 - leftWidth, contentWidth * 0.4) - amPmWidth - 4;

/// عرض العمود الأيسر في الصف العلوي: ما يبقى بعد عمود الساعة (الأعرض من سطر الساعة [clockRowWidth]
/// واليوم [weekdayWidth]) وفاصل ٨ (leftColumnDp في LamhaLogic.kt).
double leftColumnWidth(
  double contentWidth,
  double clockRowWidth,
  double weekdayWidth,
) => contentWidth - 8 - math.max(clockRowWidth, weekdayWidth);

/// معامل خط المربعات: معامل المستخدم [fontScale]، أو أصغر منه إن لم تتسع أسطر المربع الأطول
/// [lineSizes] (كل سطر بارتفاع [tileLineHeight] × حجمه، وبينها [tileGap]) في [innerHeight].
/// لا ينزل عن ٠٫٦. بلا ارتفاع معروف: [fontScale] (tileFitScale في LamhaLogic.kt).
double tileFitScale(
  double fontScale,
  double innerHeight,
  List<double> lineSizes,
) {
  if (innerHeight <= 0 || lineSizes.isEmpty) return fontScale;
  final gaps = tileGap * (lineSizes.length - 1);
  final base = lineSizes.fold<double>(0, (a, b) => a + b) * tileLineHeight;
  return math.min(fontScale, math.max(0.6, (innerHeight - gaps) / base));
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

/// معاينة الودجت الكبيرة، تُبنى من الجدول نفسه الذي يُحفظ للودجت.
/// هي المرجع لتخطيط ودجت أندرويد (android/app/src/main/res/layout/widget_lamha.xml).
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.schedule,
    required this.now,
    this.backgroundPath,
    this.systemColors,
  });

  final Map<String, Object?> schedule;
  final DateTime now;

  /// لقطة الخلفية (آيفون) لتظهر خلف المعاينة.
  final String? backgroundPath;

  /// ألوان النظام (أندرويد ١٢+) لسمة «ألوان النظام».
  final SystemColors? systemColors;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final radius = Theme.of(context).platform == TargetPlatform.iOS
        ? 22.0
        : 28.0;
    final colors = scheduleColors(schedule, systemColors);
    final accent = colors.accent;
    final visibleMap = (schedule['visible']! as Map).cast<String, bool>();
    bool on(WidgetElement e) => visibleMap[e.name] ?? false;
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

    final scale = scheduleFontScale(schedule);
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: TextDirection.rtl,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    // العمود الأيسر: الهجري ١٨ عريض، ثم الميلادي ١٦، ثم المدينة والطقس ١٦.
    final leftLines = <({String text, TextStyle style, Key? key})>[
      if (on(WidgetElement.hijri))
        (
          text: l.hijriDateText((day['hijri'] as Map)['text'] as String),
          style: TextStyle(
            fontSize: hijriSize * scale,
            fontWeight: FontWeight.w700,
            color: _text,
            height: headLineHeight,
          ),
          key: null,
        ),
      if (on(WidgetElement.gregorian))
        (
          text: l.gregorianDateText(
            (day['gregorian'] as Map)['text'] as String,
          ),
          style: TextStyle(
            fontSize: gregorianSize * scale,
            color: _muted,
            height: headLineHeight,
          ),
          key: null,
        ),
      if (on(WidgetElement.weather))
        (
          text: l.cityWeather(city['name'] as String, weather),
          style: TextStyle(
            fontSize: cityWeatherSize * scale,
            color: _muted,
            height: headLineHeight,
          ),
          key: const Key('preview-weather'),
        ),
    ];
    final leftWidth = leftLines.fold<double>(
      0,
      (m, e) => math.max(m, width(e.text, e.style)),
    );
    final amPmStyle = TextStyle(
      fontSize: amPmSize * scale,
      fontWeight: FontWeight.w700,
      color: _text,
    );
    final amPmText = amPm(local);
    // الساعة ٥٢ × المعامل، وتصغر إن لم يتسع أعرض نص لها بجانب العمود الأيسر.
    final contentWidth = previewWidgetSize.width - 28;
    final clockPreferred = clockSize * scale;
    final clockFont = fitTextSize(
      clockPreferred,
      width(
        widestClockText,
        TextStyle(fontSize: clockPreferred, fontWeight: FontWeight.w700),
      ),
      clockAvailableWidth(contentWidth, leftWidth, width(amPmText, amPmStyle)),
      clockMinSize,
    );
    // ما يبقى للعمود الأيسر بعد عمود الساعة؛ السطر الذي لا يتسع يصغر خطه (حتى ٧٥٪) قبل «…».
    final weekdayStyle = TextStyle(
      fontSize: weekdaySize * scale,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: accent,
    );
    final leftAvailable = leftColumnWidth(
      contentWidth,
      width(
            widestClockText,
            TextStyle(fontSize: clockFont, fontWeight: FontWeight.w700),
          ) +
          4 +
          width(amPmText, amPmStyle),
      width(day['weekday'] as String, weekdayStyle),
    );
    TextStyle fitted(TextStyle st, String text) => st.copyWith(
      fontSize: fitTextSize(
        st.fontSize!,
        width(text, st),
        leftAvailable - fitMargin,
        st.fontSize! * 0.75,
      ),
    );

    // من اليمين: الساعة و«ص/م» وتحتهما اليوم مباشرة، ثم يساراً التاريخان والمدينة والطقس.
    // العمودان يتوسطان رأسياً معاً.
    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          key: const Key('preview-clock-column'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  arabicClock(local),
                  key: const Key('preview-clock'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: clockFont,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: _text,
                  ),
                ),
                const SizedBox(width: 4),
                Text(amPmText, textAlign: TextAlign.right, style: amPmStyle),
              ],
            ),
            Text(
              day['weekday'] as String,
              key: const Key('preview-weekday'),
              textAlign: TextAlign.right,
              style: weekdayStyle,
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Column(
              key: const Key('preview-date-column'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final e in leftLines)
                  Text(
                    e.text,
                    key: e.key,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: fitted(e.style, e.text),
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    final shown = [
      for (final e in gridElements)
        if (on(e)) e,
    ];
    final rows = gridRows(shown);

    _Tile tileFor(WidgetElement e) => switch (e) {
      WidgetElement.prayer => _prayerTile(l, accent, day, nextDay),
      WidgetElement.qibla => _qiblaTile(l),
      WidgetElement.deposit => _depositTile(l, day),
      WidgetElement.season => _seasonTile(l, day),
      _ => _tradSeasonTile(l, day),
    };

    // الصفوف متساوية الارتفاع؛ معامل المربعات واحد للشبكة كلها من المربع الأطول.
    Widget grid(BuildContext context, BoxConstraints c) {
      final tiles = [
        for (final row in rows) [for (final cell in row) tileFor(cell.element)],
      ];
      final inner = (c.maxHeight - 8 * (rows.length - 1)) / rows.length - 16;
      var tallest = const <double>[];
      for (final t in tiles.expand((r) => r)) {
        final sizes = t.coreSizes;
        if (sizes.fold<double>(0, (a, b) => a + b) >
            tallest.fold<double>(0, (a, b) => a + b)) {
          tallest = sizes;
        }
      }
      final tileScale = tileFitScale(scale, inner, tallest);
      return Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows[r].length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      flex: rows[r][i].flex,
                      child: KeyedSubtree(
                        key: Key('tile-${rows[r][i].element.name}'),
                        child: tiles[r][i].withScale(tileScale),
                      ),
                    ),
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
        padding: const EdgeInsets.all(14),
        child: DefaultTextStyle.merge(
          style: TextStyle(shadows: shadows),
          child: Column(
            children: [
              if (rows.isEmpty) Expanded(child: head) else head,
              if (rows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                Expanded(child: LayoutBuilder(builder: grid)),
              ],
            ],
          ),
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
      title: l.tilePrayer,
      highlight: accent,
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

/// هامش أمان (بكسل) عند قياس ما يتسع سطراً واحداً، كي لا يُقص بفرق التقريب.
const fitMargin = 2.0;

/// أدنى حجم للعنوان والقيمة عند تصغيرهما ليتسعا (نسبة من حجمهما).
const tileMinFit = 0.7;

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.value,
    this.shortTitle,
    this.subs = const [],
    this.highlight,
    this.scale = 1,
  });

  final String title;

  /// يحل محل [title] إذا لم يتسع سطراً واحداً.
  final String? shortTitle;
  final String value;

  /// الثانويات: [lines] حدها الأقصى. الأخير ذو الأسطر المتعددة يأخذ ما يتسع منها.
  final List<({String text, int lines})> subs;
  final Color? highlight;

  /// معامل الخط الفعلي (tileFitScale).
  final double scale;

  _Tile withScale(double s) => _Tile(
    title: title,
    shortTitle: shortTitle,
    value: value,
    subs: subs,
    highlight: highlight,
    scale: s,
  );

  /// أحجام الأسطر الأساسية (كل ثانوي سطر واحد) لحساب معامل الشبكة.
  List<double> get coreSizes => [
    tileTitleSize,
    tileValueSize,
    for (final _ in subs) tileSubSize,
  ];

  @override
  Widget build(BuildContext context) {
    final h = highlight;
    final base = DefaultTextStyle.of(context).style;
    final scaler = MediaQuery.textScalerOf(context);
    double width(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: base.merge(style)),
        textDirection: TextDirection.rtl,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

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
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        child: LayoutBuilder(
          builder: (context, c) {
            final titleStyle = TextStyle(
              fontSize: tileTitleSize * scale,
              fontWeight: FontWeight.w700,
              color: _dim,
              height: tileLineHeight,
            );
            // «الإيداع القادم» ← «الإيداع» إن لم يتسع، ثم تصغير الخط حتى يتسع سطراً واحداً.
            final short = shortTitle;
            final t =
                short != null &&
                    width(title, titleStyle) > c.maxWidth - fitMargin
                ? short
                : title;
            final titleSize = fitTextSize(
              tileTitleSize * scale,
              width(t, titleStyle),
              c.maxWidth - fitMargin,
              tileTitleSize * scale * tileMinFit,
            );
            final valueStyle = TextStyle(
              fontSize: tileValueSize * scale,
              fontWeight: FontWeight.w700,
              color: _text,
              height: tileLineHeight,
            );
            final valueSize = fitTextSize(
              tileValueSize * scale,
              width(value, valueStyle),
              c.maxWidth - fitMargin,
              tileValueSize * scale * tileMinFit,
            );
            final subLine = tileSubSize * scale * tileLineHeight;
            final used =
                (titleSize + valueSize) * tileLineHeight +
                subs.length * subLine +
                tileGap * (subs.length + 1);
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
                    for (final (i, s) in subs.indexed) ...[
                      const SizedBox(height: tileGap),
                      Text(
                        s.text,
                        key: Key('tile-sub-$i'),
                        textAlign: TextAlign.right,
                        // الأخير وحده يأخذ أسطراً إضافية إن اتسعت.
                        maxLines: i == subs.length - 1
                            ? math.min(s.lines, extra)
                            : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tileSubSize * scale,
                          color: _dim,
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
