import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/book_actions.dart';
import '../library/library_controller.dart';
import '../library/library_text.dart';

/// «إدارة الكتب المحمّلة» (DESIGN §13.1، ARCHITECTURE §18.6): المساحة الكلية،
/// وكل كتاب بحجمه وزر «حذف» مع حوار التأكيد في §7.2.
class DownloadedBooksScreen extends ConsumerWidget {
  const DownloadedBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(libraryControllerProvider);
    final items = state.installedItems;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageBooks)),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          itemCount: items.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 12),
                child: Semantics(
                  header: true,
                  child: Text(
                    items.isEmpty
                        ? l10n.noDownloadedBooks
                        : l10n.booksUsage(
                            l10n.size(context, state.installedBytes),
                          ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              );
            }
            final item = items[index - 1];
            final size = l10n.size(context, item.installed!.bytes);
            return Card(
              margin: const EdgeInsetsDirectional.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: MergeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title.ar,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: bookFont,
                                fontSize: 18,
                                height: 1.6,
                              ),
                            ),
                            Text(
                              size,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.deleteBookSemantics(item.title.ar),
                      color: theme.colorScheme.error,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: state.tasks.containsKey(item.id)
                          ? null
                          : () => confirmAndDelete(context, ref, item),
                    ),
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
