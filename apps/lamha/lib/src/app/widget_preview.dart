import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/prayer.dart';
import '../engine/settings.dart';

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

class _Palette {
  const _Palette(this.accent, this.bgTop, this.bgBottom, this.wallTop,
      this.wallBottom, this.radius);

  final Color accent;
  final Color bgTop;
  final Color bgBottom;
  final Color wallTop;
  final Color wallBottom;
  final double radius;

  static const ios = _Palette(Color(0xFFD6AA5C), Color(0xFF3A3228),
      Color(0xFF181512), Color(0xFF3A3128), Color(0xFF0B0A09), 22);
  static const android = _Palette(Color(0xFF78BE96), Color(0xFF2E3A32),
      Color(0xFF141815), Color(0xFF2F3A33), Color(0xFF0A0B0A), 28);
}

const _text = Color(0xFFF4EFE6);
const _muted = Color(0xFFCFC6B8);
const _dim = Color(0xFFB9B0A2);

/// معاينة الودجت الكبيرة، تُبنى من الجدول نفسه الذي يُحفظ للودجت.
class WidgetPreview extends StatelessWidget {
  const WidgetPreview({
    super.key,
    required this.schedule,
    required this.now,
    this.backgroundPath,
  });

  final Map<String, Object?> schedule;
  final DateTime now;

  /// لقطة الخلفية (آيفون) لتظهر خلف المعاينة.
  final String? backgroundPath;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = Theme.of(context).platform == TargetPlatform.iOS
        ? _Palette.ios
        : _Palette.android;
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

    final hideHeadInfo = !on(WidgetElement.hijri) &&
        !on(WidgetElement.gregorian) &&
        !on(WidgetElement.weather);

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
                    style: TextStyle(
                        fontSize: hideHeadInfo ? 60 : 44,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: _text)),
                const SizedBox(width: 3),
                Text(amPm(local),
                    style: TextStyle(
                        fontSize: hideHeadInfo ? 26 : 20,
                        fontWeight: FontWeight.w700,
                        color: _text)),
              ],
            ),
            const SizedBox(height: 4),
            Text(day['weekday'] as String,
                style: TextStyle(
                    fontSize: hideHeadInfo ? 19 : 15,
                    fontWeight: FontWeight.w700,
                    color: p.accent)),
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
                _line(l.cityWeather(city['name'] as String), 12.5,
                    FontWeight.w400, _muted),
            ],
          ),
          ),
        ),
      ],
    );

    final shown = [for (final e in gridElements) if (on(e)) e];
    final rows = gridRows(shown);

    Widget tileFor(WidgetElement e) => switch (e) {
          WidgetElement.prayer => _prayerTile(l, p, day, nextDay, local),
          WidgetElement.qibla => _qiblaTile(l, p),
          WidgetElement.deposit => _depositTile(l, day),
          WidgetElement.season => _seasonTile(l, day),
          _ => _tradSeasonTile(l, day),
        };

    final widgetBox = DecoratedBox(
      key: const Key('preview-background'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(p.radius),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            p.bgTop.withValues(alpha: 0.92 * alpha),
            p.bgBottom.withValues(alpha: 0.95 * alpha),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
            ? RadialGradient(
                center: const Alignment(0.4, -0.8),
                radius: 1.2,
                colors: [p.wallTop, p.wallBottom],
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

  static Widget _line(String s, double size, FontWeight w, Color c) => Text(
        s,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: size, fontWeight: w, color: c, height: 1.4),
      );

  Widget _prayerTile(AppLocalizations l, _Palette p, Map day, Map? nextDay,
      tz.TZDateTime local) {
    String? name;
    DateTime? at;
    final today = (day['prayers'] as Map).cast<String, Map>();
    for (final e in today.entries) {
      if (e.key == PrayerName.sunrise.name) continue;
      final t = DateTime.parse(e.value['time'] as String);
      if (t.isAfter(now)) {
        name = e.value['name'] as String;
        at = t;
        break;
      }
    }
    if (name == null && nextDay != null) {
      final fajr = (nextDay['prayers'] as Map)['fajr'] as Map;
      name = fajr['name'] as String;
      at = DateTime.parse(fajr['time'] as String);
    }
    final minutes =
        at == null ? 0 : (at.difference(now).inSeconds / 60).ceil();
    return _Tile(
      title: l.tilePrayer,
      emoji: '🕌',
      highlight: p.accent,
      value: name ?? '',
      sub: remainingMinutesText(minutes),
    );
  }

  Widget _qiblaTile(AppLocalizations l, _Palette p) {
    final q = schedule['qibla']! as Map;
    final deg = (q['degrees'] as num).toDouble();
    return _Tile(
      title: l.tileQibla,
      body: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l.degrees(arabicDigits(deg.round())),
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _text)),
          SizedBox.square(
            dimension: 38,
            child: CustomPaint(painter: _CompassPainter(deg, p.accent)),
          ),
        ],
      ),
    );
  }

  Widget _depositTile(AppLocalizations l, Map day) {
    final deps = (day['deposits'] as List).cast<Map>();
    final first = deps.first;
    return _Tile(
      title: l.tileDeposit,
      emoji: '💰',
      value: first['label'] as String,
      sub: first['remainingText'] as String,
      extra: deps.length > 1
          ? '${deps[1]['label']} · ${deps[1]['remainingText']}'
          : null,
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
      sub: l.remainingToNext(s['remainingText'] as String,
          withLam((s['next'] as Map)['name'] as String)),
    );
  }

  Widget _tradSeasonTile(AppLocalizations l, Map day) {
    final s = day['tradSeason'] as Map;
    return _Tile(
      title: l.tileTradSeason,
      emoji: '🌾',
      value: s['name'] as String,
      valueSuffix: ' · ${l.remainingToNext(s['remainingText'] as String, withLam((s['next'] as Map)['name'] as String))}',
      sub: s['description'] as String,
      subLines: 3,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.title,
    this.emoji,
    this.value,
    this.valueSuffix,
    this.sub,
    this.subLines = 2,
    this.extra,
    this.body,
    this.highlight,
  });

  final String title;
  final String? emoji;
  final String? value;
  final String? valueSuffix;
  final String? sub;
  final int subLines;
  final String? extra;
  final Widget? body;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final h = highlight;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: h == null ? Colors.white.withValues(alpha: 0.06) : null,
        gradient: h == null
            ? null
            : LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  h.withValues(alpha: 0.25),
                  h.withValues(alpha: 0.07),
                ],
              ),
        border: Border.all(
            color: h?.withValues(alpha: 0.3) ??
                Colors.white.withValues(alpha: 0.07)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        child: LayoutBuilder(builder: (context, box) {
          final bottom = body ??
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(text: value ?? '', children: [
                      if (valueSuffix != null)
                        TextSpan(
                            text: valueSuffix,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: _dim)),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _text,
                        height: 1.25),
                  ),
                  if (sub != null)
                    Text(sub!,
                        maxLines: subLines,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: _dim, height: 1.35)),
                  if (extra != null)
                    Text(extra!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 9.5, color: _dim, height: 1.35)),
                ],
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _dim)),
                  ),
                  if (emoji != null)
                    Text(emoji!, style: const TextStyle(fontSize: 18, height: 1)),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.bottomStart,
                    child: SizedBox(width: box.maxWidth, child: bottom),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// سهم القبلة: الزاوية من الشمال باتجاه عقارب الساعة.
class _CompassPainter extends CustomPainter {
  _CompassPainter(this.degrees, this.accent);

  final double degrees;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _text.withValues(alpha: 0.6));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(degrees * math.pi / 180);
    final s = r / 17;
    canvas.drawPath(
        Path()
          ..moveTo(0, -15 * s)
          ..lineTo(4 * s, 0)
          ..lineTo(0, -2 * s)
          ..lineTo(-4 * s, 0)
          ..close(),
        Paint()..color = accent);
    canvas.drawPath(
        Path()
          ..moveTo(0, 15 * s)
          ..lineTo(4 * s, 0)
          ..lineTo(0, 2 * s)
          ..lineTo(-4 * s, 0)
          ..close(),
        Paint()..color = _text.withValues(alpha: 0.45));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CompassPainter old) =>
      old.degrees != degrees || old.accent != accent;
}
