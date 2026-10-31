import 'package:flutter/material.dart';
import '../../../app/score_label.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../domain/cafe.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../cafes_providers.dart';
import 'cafe_actions.dart';

/// «مقاهيّ المحفوظة»: تُفتح من الإعدادات والمفضلة.
class CafesScreen extends ConsumerWidget {
  const CafesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cafes = ref.watch(cafeSummariesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cafesTitle)),
      body: cafes.when(
        skipLoadingOnReload: true,
        loading: () => Semantics(
          label: l10n.cafesLoading,
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.cafesErrorTitle),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: () => ref.invalidate(cafeSummariesProvider), child: Text(l10n.retry)),
          ]),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.place_outlined, size: 56),
                    const SizedBox(height: 12),
                    Text(l10n.cafesEmptyTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(l10n.cafesEmptyBody, textAlign: TextAlign.center),
                  ]),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _CafeTile(summary: list[i]),
              ),
      ),
    );
  }
}

class _CafeTile extends ConsumerWidget {
  const _CafeTile({required this.summary});
  final CafeSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cafe = summary.cafe;
    final sub = [
      l10n.cafeScanCount(summary.scanCount),
      if (summary.lastScore != null) l10n.cafeLastScore(scoreLabelFor(l10n, summary.lastScore!)),
      if (!cafe.hasLocation) l10n.cafeNoLocation,
    ].join(' • ');
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        onTap: cafe.hasLocation ? () => openCafeInMaps(context, ref, cafe) : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
          child: Row(children: [
            Icon(cafe.hasLocation ? Icons.place : Icons.place_outlined,
                color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                Text(sub, style: theme.textTheme.bodySmall),
              ]),
            ),
            if (cafe.hasLocation)
              IconButton(
                tooltip: l10n.cafeOpenInMaps,
                icon: const Icon(Icons.map_outlined),
                onPressed: () => openCafeInMaps(context, ref, cafe),
              ),
            PopupMenuButton<String>(
              tooltip: l10n.cafeMenu,
              onSelected: (v) =>
                  v == 'edit' ? renameCafe(context, ref, cafe) : confirmAndDeleteCafe(context, ref, cafe),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.cafeEdit)),
                PopupMenuItem(value: 'delete', child: Text(l10n.cafeDelete)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
