import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/scan.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../history_providers.dart';
import 'scan_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scans = ref.watch(historyScansProvider);
    final filter = ref.watch(historyFilterProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
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
                      onSelected: (_) => ref.read(historyFilterProvider.notifier).set(type),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: scans.when(
              skipLoadingOnReload: true,
              loading: () => const _LoadingList(),
              error: (_, _) => _ErrorView(onRetry: () => ref.invalidate(historyScansProvider)),
              data: (list) => list.isEmpty
                  ? const _EmptyView()
                  : ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => ScanCard(
                        key: ValueKey(list[i].id),
                        scan: list[i],
                        onTap: () => context.go('${AppRoutes.history}/${list[i].id}'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.coffee_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l10n.historyEmptyTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go(AppRoutes.scan),
              child: Text(l10n.historyEmptyAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(l10n.historyErrorTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: AppLocalizations.of(context).historyLoading,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 16),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          key: const ValueKey('history-skeleton'),
          height: 96,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
