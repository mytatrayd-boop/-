import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/scan.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../history_providers.dart';
import 'delete_scan.dart';
import 'scan_formatting.dart';
import 'scan_image.dart';
import 'toggle_favorite.dart';

class ScanDetailScreen extends ConsumerWidget {
  const ScanDetailScreen({super.key, required this.id, this.fallbackRoute = AppRoutes.history});

  final int id;

  /// وجهة الرجوع إن لم يوجد ما يُسحب من المكدس.
  final String fallbackRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scan = ref.watch(scanDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanDetailTitle),
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go(fallbackRoute),
        ),
        actions: [
          if (scan.value != null)
            IconButton(
              tooltip: scan.value!.isFavorite ? l10n.favoriteRemove : l10n.favoriteAdd,
              icon: Icon(scan.value!.isFavorite ? Icons.star : Icons.star_border),
              onPressed: () => toggleFavorite(context, ref, id, scan.value!.isFavorite),
            ),
          if (scan.value != null)
            IconButton(
              tooltip: l10n.scanDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final deleted = await confirmAndDeleteScan(context, ref, id);
                if (deleted && context.mounted) context.go(fallbackRoute);
              },
            ),
        ],
      ),
      body: scan.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.historyErrorTitle)),
        data: (s) => s == null
            ? Center(child: Text(l10n.scanNotFound))
            : _Body(scan: s),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.scan});
  final Scan scan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsetsDirectional.only(top: 8),
          child: Row(children: [
            Text('$label: ', style: theme.textTheme.bodySmall),
            Expanded(child: Text(value)),
          ]),
        );
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(aspectRatio: 4 / 3, child: ScanImage(path: scan.imagePath)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(l10n.scoreOutOf(scan.score),
              style: theme.textTheme.displayLarge?.copyWith(color: theme.colorScheme.primary)),
        ),
        const SizedBox(height: 16),
        Text(l10n.scanNotesTitle, style: theme.textTheme.titleMedium),
        for (final n in scan.notes)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(n)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsetsDirectional.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(l10n.scanDisclaimer, style: theme.textTheme.bodySmall),
        ),
        const SizedBox(height: 8),
        row(l10n.scanDate, formatScanDate(locale, scan.createdAt)),
        row(l10n.scanTypeField, scanTypeLabel(l10n, scan.type)),
        if (scan.roasterName != null) row(l10n.scanRoaster, scan.roasterName!),
        if (scan.price != null) row(l10n.scanPrice, scan.price!.toString()),
      ],
    );
  }
}
