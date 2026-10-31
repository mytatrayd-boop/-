import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/scan.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../history/history_providers.dart';
import '../../history/presentation/scan_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scans = ref.watch(favoriteScansProvider);
    final filter = ref.watch(favoritesFilterProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final (type, label) in [
                    (null, l10n.historyFilterAll),
                    (ScanType.bean, l10n.historyFilterBean),
                    (ScanType.coffee, l10n.historyFilterCoffee),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: filter == type,
                      onSelected: (_) => ref.read(favoritesFilterProvider.notifier).set(type),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: scans.when(
              skipLoadingOnReload: true,
              loading: () => Semantics(
                label: l10n.favoritesLoading,
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => Container(
                    key: const ValueKey('favorites-skeleton'),
                    height: 96,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              error: (_, _) => _Message(
                icon: Icons.error_outline,
                text: l10n.favoritesErrorTitle,
                action: FilledButton(
                  onPressed: () => ref.invalidate(favoriteScansProvider),
                  child: Text(l10n.retry),
                ),
              ),
              data: (list) => list.isEmpty
                  ? _Message(icon: Icons.star_border, text: l10n.favoritesEmptyTitle)
                  : ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => ScanCard(
                        key: ValueKey(list[i].id),
                        scan: list[i],
                        onTap: () => context.go('${AppRoutes.favorites}/${list[i].id}'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
