import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/day_info.dart';
import '../../domain/tables.dart';
import '../../formatting/date_labels.dart';
import 'dial/dial_model.dart';

/// ورقة سفلية لعنصر من الدائرة أو بطاقة اليوم (DESIGN 8.6).
///
/// **عنصر نائب حتى الميزة 7:** تعرض النوع والاسم وتواريخ الفترة في جدول
/// المنطقة فقط. التعريف والمثل والمصدر و«أبلغ عن خطأ» وصفحة الدَّرّ بمسارها
/// (D26) تأتي مع الميزة 7.
Future<void> showItemSheet(
  BuildContext context, {
  required DialRing ring,
  required DayInfo day,
  required Tables tables,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ItemSheet(ring: ring, day: day, tables: tables),
  );
}

class ItemSheet extends StatelessWidget {
  const ItemSheet({
    super.key,
    required this.ring,
    required this.day,
    required this.tables,
  });

  static const sheetKey = Key('itemSheet');

  final DialRing ring;
  final DayInfo day;
  final Tables tables;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String item(String id) => tables.items[id]?.name.ar ?? id;

    final (
      String type,
      String name,
      ActivePeriod period,
      String regionId,
    ) = switch (ring) {
      DialRing.stars => (
        l10n.detailTypeStar,
        item(day.star.itemId),
        day.star,
        day.regionId,
      ),
      DialRing.seasons || DialRing.months => (
        l10n.detailTypeSeason,
        item(day.majorSeason.itemId),
        day.majorSeason,
        day.regionId,
      ),
      DialRing.weather when day.weatherSeason != null => (
        l10n.detailTypeWeatherSeason,
        item(day.weatherSeason!.itemId),
        day.weatherSeason!,
        day.regionId,
      ),
      _ => (l10n.detailTypeDar, day.dar.name.ar, day.dar, day.dururRegionId),
    };
    final region = tables.region(regionId)?.name.ar ?? regionId;

    return SafeArea(
      child: Padding(
        key: sheetKey,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(type, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(name, style: theme.textTheme.displaySmall),
            const SizedBox(height: 12),
            Text(
              l10n.detailRange(
                gregorianDateLabel(l10n, period.start),
                gregorianDateLabel(l10n, period.end),
                region,
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
