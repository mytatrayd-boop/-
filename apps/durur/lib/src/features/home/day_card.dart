import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/day_info.dart';
import '../../domain/tables.dart';
import '../../theme/app_theme.dart';
import '../common/chips.dart';
import '../common/weather_icon.dart';
import '../../formatting/digits.dart';
import 'day_text.dart';
import 'dial/day_dial.dart';
import 'dial/dial_model.dart';

/// بطاقة اليوم تحت الدائرة (DESIGN 8.4 بند 5): كل معلومة في الدائرة نصاً
/// عادياً يتكبّر مع خط الجهاز. لمنطقة تستعير الدرور (D24) تأتي المواسم
/// والطوالع أولاً، ثم الدَّرّ تحتها مع السطر الثابت من البيانات.
class DayCard extends StatelessWidget {
  const DayCard({
    super.key,
    required this.info,
    required this.tables,
    required this.onOpen,
    required this.onOpenOrigin,
    this.digits = DigitStyle.arabicIndic,
  });

  static const cardKey = Key('dayCard');
  static const borrowNoteKey = Key('dururBorrowNote');
  static const originLinkKey = Key('originLink');

  final DayInfo info;
  final Tables tables;
  final DialOpen onOpen;

  /// رابط «أصل التقويم» في قسم الدَّرّ المستعار (D24).
  final VoidCallback onOpenOrigin;

  /// شكل الأرقام (DESIGN 8.7).
  final DigitStyle digits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    String name(String? id) => tables.items[id]?.name.ar ?? '';

    final seasonChip = SeasonChip(
      label: name(info.majorSeason.itemId),
      color: colors.season(info.majorSeason.itemId),
      onTap: () => onOpen(DialRing.seasons, info),
    );

    final starRow = _InfoRow(
      icon: CustomPaint(
        size: const Size.square(20),
        painter: _StarIconPainter(colors.starMark),
      ),
      title: l10n.homeStar,
      value: name(info.star.itemId),
      onTap: () => onOpen(DialRing.stars, info),
    );

    final ws = info.weatherSeason;
    final wsSymbol = ws == null
        ? null
        : tables.items[ws.itemId]?.weather.firstOrNull;
    final weatherSeasonRow = ws == null
        ? Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 12),
            child: Text(
              l10n.homeNoWeatherSeason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkSoft,
              ),
            ),
          )
        : _InfoRow(
            icon: wsSymbol == null
                ? const Icon(Icons.cloud_outlined, size: 20)
                : WeatherIcon(wsSymbol, color: colors.ink),
            title: l10n.homeWeatherSeason,
            value: name(ws.itemId),
            onTap: () => onOpen(DialRing.weather, info),
          );

    final progress = Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
      child: _DarProgress(
        info: info,
        color: colors.season(info.dar.record.seasonId),
        label: dayOfDarLabel(l10n, info, digits: digits),
      ),
    );

    final usualWeather = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.homeUsualWeather, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final s in info.weather) WeatherChip(symbol: s)],
        ),
        if (info.weatherNote != null) ...[
          const SizedBox(height: 8),
          Text(info.weatherNote!.ar, style: theme.textTheme.bodyMedium),
        ],
      ],
    );

    final darRow = _InfoRow(
      icon: const Icon(Icons.donut_large, size: 20),
      title: l10n.homeDarDetails(info.dar.name.ar),
      onTap: () => onOpen(DialRing.durur, info),
    );

    final List<Widget> children;
    if (info.borrowsDurur) {
      // DESIGN 7.8: الموسم (موسم الجو المسمّى أو الموسم الكبير) أولاً، ثم
      // النجم، ثم الجو المعتاد، ثم قسم الدَّرّ المستعار.
      final lender = tables.region(info.dururRegionId)?.name.ar ?? '';
      final note = tables.regionTables[info.regionId]?.dururBorrow?.note.ar;
      children = [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              name(ws?.itemId ?? info.majorSeason.itemId),
              style: theme.textTheme.displaySmall,
            ),
            if (ws != null) seasonChip,
          ],
        ),
        starRow,
        // صف موسم الجو يُحذف إن كان هو المعروض في السطر الأول.
        if (ws == null) weatherSeasonRow,
        const SizedBox(height: 8),
        usualWeather,
        const Divider(height: 32),
        Text(
          l10n.homeDururBorrowed(lender),
          style: theme.textTheme.titleMedium,
        ),
        Text(info.dar.name.ar, style: theme.textTheme.headlineSmall),
        progress,
        if (note != null)
          Text(
            note,
            key: borrowNoteKey,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: originLinkKey,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: onOpenOrigin,
            child: Text(l10n.homeOriginLink),
          ),
        ),
        darRow,
      ];
    } else {
      children = [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(info.dar.name.ar, style: theme.textTheme.displaySmall),
            seasonChip,
          ],
        ),
        progress,
        starRow,
        weatherSeasonRow,
        const SizedBox(height: 8),
        usualWeather,
        darRow,
      ];
    }

    return Card(
      key: cardKey,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: colors.season(info.majorSeason.itemId)),
          Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// صف قابل للضغط 56dp: أيقونة ← العنوان والقيمة ← سهم (DESIGN 5.2).
/// ينكسر إلى أسطر مع تكبير الخط بدل القصّ.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: value == null
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.bodyMedium?.copyWith(
                            color: DururColors.of(context).inkSoft,
                          ),
                  ),
                  if (value != null)
                    Text(value!, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

/// شريط التقدم في الدَّرّ: مقطع لكل يوم بطوله الفعلي، يملأ من البداية
/// (اليمين في RTL)، واليوم الحالي بنقطة ذهبية (DESIGN 5.6).
class _DarProgress extends StatelessWidget {
  const _DarProgress({
    required this.info,
    required this.color,
    required this.label,
  });

  final DayInfo info;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    final total = info.dar.length;
    final day = info.dar.dayNumber;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: 2),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i <= day ? color : colors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: i == day
                          ? Center(
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: colors.goldDeco,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _StarIconPainter extends CustomPainter {
  const _StarIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      fourPointStar(size.center(Offset.zero), size.shortestSide * 0.45),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_StarIconPainter old) => old.color != color;
}
