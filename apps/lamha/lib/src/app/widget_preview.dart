import 'dart:io';

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
    List<WidgetElement> shown) {
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

/// أحجام الصف العلوي، مطابقة لـ widget_lamha.xml في أندرويد (الميزة ٣ج).
const clockSize = 42.0;
const amPmSize = 18.0;
const weekdaySize = 15.0;

/// لونا الودجت من الجدول: ألوان النظام لسمة «ألوان النظام» إن توفرت (أندرويد ١٢+)، وإلا ألوان السمة.
({Color accent, Color background}) scheduleColors(
    Map<String, Object?> schedule, SystemColors? system) {
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
    final radius =
        Theme.of(context).platform == TargetPlatform.iOS ? 22.0 : 28.0;
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
    final weather = weatherText(scheduleWeather(schedule), now) ?? l.weatherUnknown;

    // من اليمين: الساعة و«ص/م» وتحتهما اليوم، ثم يساراً التاريخان والمدينة والطقس.
    final head = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(arabicClock(local),
                    key: const Key('preview-clock'),
                    style: const TextStyle(
                        fontSize: clockSize,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: _text)),
                const SizedBox(width: 4),
                Text(amPm(local),
                    style: const TextStyle(
                        fontSize: amPmSize,
                        fontWeight: FontWeight.w700,
                        color: _text)),
              ],
            ),
            const SizedBox(height: 4),
            Text(day['weekday'] as String,
                key: const Key('preview-weekday'),
                style: TextStyle(
                    fontSize: weekdaySize,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (on(WidgetElement.hijri))
                  _line(l.hijriDateText((day['hijri'] as Map)['text'] as String),
                      14, FontWeight.w700, _text),
                if (on(WidgetElement.gregorian))
                  _line(
                      l.gregorianDateText(
                          (day['gregorian'] as Map)['text'] as String),
                      13,
                      FontWeight.w400,
                      _muted),
                if (on(WidgetElement.weather))
                  _line(l.cityWeather(city['name'] as String, weather), 12,
                      FontWeight.w400, _muted,
                      key: const Key('preview-weather')),
              ],
            ),
          ),
        ),
      ],
    );

    final shown = [for (final e in gridElements) if (on(e)) e];
    final rows = gridRows(shown);

    Widget tileFor(WidgetElement e) => switch (e) {
          WidgetElement.prayer => _prayerTile(l, accent, day, nextDay, local),
          WidgetElement.qibla => _qiblaTile(l),
          WidgetElement.deposit => _depositTile(l, day),
          WidgetElement.season => _seasonTile(l, day),
          _ => _tradSeasonTile(l, day),
        };

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
                      height: 1, color: Colors.white.withValues(alpha: 0.08)),
                ),
                Expanded(
                  child: Column(
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
                                    child: tileFor(rows[r][i].element),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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

  static Widget _line(String s, double size, FontWeight w, Color c,
          {Key? key}) =>
      Text(
        s,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.4),
      );

  Widget _prayerTile(AppLocalizations l, Color accent, Map day, Map? nextDay,
      tz.TZDateTime local) {
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
    final minutes =
        at == null ? 0 : (at.difference(now).inSeconds / 60).ceil();
    // الاسم، ثم وقت الصلاة، ثم الباقي (كما في LamhaWidget.kt).
    return _Tile(
      title: l.tilePrayer,
      emoji: '🕌',
      highlight: accent,
      value: (next?['name'] as String?) ?? '',
      subs: [
        if (next != null) (text: next['text'] as String, lines: 1),
        (text: remainingMinutesText(minutes), lines: 1),
      ],
    );
  }

  Widget _qiblaTile(AppLocalizations l) {
    final q = schedule['qibla']! as Map;
    final deg = (q['degrees'] as num).toDouble();
    // الزاوية سطر، والاتجاه سطر أصغر تحته.
    return _Tile(
      title: l.tileQibla,
      value: l.degrees(arabicDigits(deg.round())),
      emoji: '🧭',
      subs: [(text: q['direction'] as String, lines: 1)],
    );
  }

  Widget _depositTile(AppLocalizations l, Map day) {
    final deps = (day['deposits'] as List).cast<Map>();
    final first = deps.first;
    return _Tile(
      title: l.tileDeposit,
      emoji: '💰',
      value: first['label'] as String,
      subs: [
        (text: first['remainingText'] as String, lines: deps.length > 1 ? 1 : 2),
        if (deps.length > 1)
          (text: '${deps[1]['label']} · ${deps[1]['remainingText']}', lines: 1),
      ],
    );
  }

  Widget _seasonTile(AppLocalizations l, Map day) {
    final s = day['season'] as Map;
    const emoji = {
      'spring': '🌸',
      'summer': '☀️',
      'autumn': '🍂',
      'winter': '❄️',
    };
    return _Tile(
      title: l.tileSeason,
      emoji: emoji[s['id']] ?? '🍂',
      value: s['name'] as String,
      subs: [
        (
          text: l.remainingToNext(s['remainingText'] as String,
              withLam((s['next'] as Map)['name'] as String)),
          lines: 2
        ),
      ],
    );
  }

  Widget _tradSeasonTile(AppLocalizations l, Map day) {
    final s = day['tradSeason'] as Map;
    final description = s['description'] as String;
    return _Tile(
      title: l.tileTradSeason,
      emoji: '🌾',
      value: s['name'] as String,
      subs: [
        (
          text: l.remainingToNext(s['remainingText'] as String,
              withLam((s['next'] as Map)['name'] as String)),
          lines: 1
        ),
        if (description.isNotEmpty) (text: description, lines: 2),
      ],
    );
  }
}

/// أحجام المربعات الموحدة: العنوان ١٢، والقيمة ١٧ عريض، والثانوي ١٢، والمحتوى من الأعلى
/// بتباعد ثابت [tileGap]. مطابقة لـ widget_tile_content.xml. العنوان والقيمة بلا قص
/// (يلتفّان)، والثانوي وحده بحد أسطر وعلامة «…».
const tileTitleSize = 12.0;
const tileValueSize = 17.0;
const tileSubSize = 12.0;
const tileGap = 3.0;

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    required this.emoji,
    required this.value,
    this.subs = const [],
    this.highlight,
  });

  final String title;
  final String emoji;
  final String value;
  final List<({String text, int lines})> subs;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final h = highlight;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        // مربع الصلاة: لون التمييز بألفا ثابتة (كـ setImageAlpha في أندرويد).
        color: h?.withValues(alpha: 0.18) ?? Colors.white.withValues(alpha: 0.06),
        border: h == null
            ? Border.all(color: Colors.white.withValues(alpha: 0.07))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        // ما لا يتسع يُقص من الأسفل كما في الودجت، بلا تصغير.
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title,
                        key: const Key('tile-title'),
                        style: const TextStyle(
                            fontSize: tileTitleSize,
                            fontWeight: FontWeight.w700,
                            color: _dim)),
                  ),
                  Text(emoji, style: const TextStyle(fontSize: 16, height: 1)),
                ],
              ),
              const SizedBox(height: tileGap),
              Text(value,
                  key: const Key('tile-value'),
                  style: const TextStyle(
                      fontSize: tileValueSize,
                      fontWeight: FontWeight.w700,
                      color: _text,
                      height: 1.2)),
              for (final (i, s) in subs.indexed) ...[
                const SizedBox(height: tileGap),
                Text(s.text,
                    key: Key('tile-sub-$i'),
                    maxLines: s.lines,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: tileSubSize, color: _dim, height: 1.25)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
