import 'package:flutter/material.dart';
import '../../../app/score_label.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/scan.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../cafes/presentation/cafe_actions.dart';
import 'delete_scan.dart';
import 'scan_formatting.dart';
import 'scan_image.dart';
import 'toggle_favorite.dart';

class ScanCard extends ConsumerWidget {
  const ScanCard({super.key, required this.scan, required this.onTap});

  final Scan scan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = scanTypeLabel(l10n, scan.type);
    final roaster = scan.roasterName;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: l10n.scanCardLabel(type, scoreLabelFor(l10n, scan.score)),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ScanImage(path: scan.imagePath, size: 72),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(roaster ?? type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium),
                      if (roaster != null) Text(type, style: theme.textTheme.bodySmall),
                      if (scan.cafe != null)
                        InkWell(
                          onTap: scan.cafe!.hasLocation
                              ? () => openCafeInMaps(context, ref, scan.cafe!)
                              : null,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.place_outlined,
                                size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(scan.cafe!.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall),
                            ),
                          ]),
                        ),
                      Text(
                        formatScanDate(Localizations.localeOf(context).toString(), scan.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(scoreLabelFor(l10n, scan.score),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
                IconButton(
                  tooltip: scan.isFavorite ? l10n.favoriteRemove : l10n.favoriteAdd,
                  icon: Icon(scan.isFavorite ? Icons.star : Icons.star_border,
                      color: scan.isFavorite ? theme.colorScheme.primary : null),
                  onPressed: () => toggleFavorite(context, ref, scan.id, scan.isFavorite),
                ),
                PopupMenuButton<String>(
                  tooltip: l10n.scanMenu,
                  onSelected: (_) => confirmAndDeleteScan(context, ref, scan.id),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'delete', child: Text(l10n.scanDelete)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
