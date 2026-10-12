import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/book_actions.dart';
import '../library/library_controller.dart';
import '../storage/reading_repository.dart';
import 'reader_providers.dart';

/// مسار القارئ على فقرة محددة.
String readerParagraphPath(String bookId, String paragraphId) =>
    Uri(path: '/read/$bookId', queryParameters: {'p': paragraphId}).toString();

/// تبويب المفضلة في المكتبة (DESIGN §7.3): الأحدث أولاً، والنقر يفتح الفقرة،
/// والسحب أو «إزالة» يزيلها مع «تراجع».
class FavoritesTab extends ConsumerStatefulWidget {
  const FavoritesTab({super.key});

  @override
  ConsumerState<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<FavoritesTab> {
  /// عناصر سُحبت ولم تُحدَّث القائمة بعد (Dismissible يشترط اختفاءها فوراً).
  final _hidden = <String>{};

  /// يتغير مفتاح Dismissible بعد فشل الإزالة، فيعود العنصر بحجمه الكامل بدل
  /// حالته المطوية.
  final _restored = <String, int>{};

  Future<void> _remove(FavoriteItem item) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final screenReader = MediaQuery.accessibleNavigationOf(context);
    final actions = ref.read(readingActionsProvider);
    void showError() => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.saveFailed),
          duration: Duration(seconds: screenReader ? 8 : 4),
        ),
      );
    setState(() => _hidden.add(item.paragraphId));
    try {
      await actions.removeFavorite(item.paragraphId);
    } on Exception {
      // لم تُحذف: يعود العنصر إلى القائمة مع رسالة.
      if (mounted) {
        setState(() {
          _hidden.remove(item.paragraphId);
          _restored.update(item.paragraphId, (n) => n + 1, ifAbsent: () => 1);
        });
      }
      showError();
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.removedFromFavorites),
          duration: Duration(seconds: screenReader ? 8 : 4),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              try {
                await actions.addFavorite(
                  item.bookId,
                  item.paragraphId,
                  createdAt: item.createdAt,
                );
              } on Exception {
                showError();
                return;
              }
              if (mounted) setState(() => _hidden.remove(item.paragraphId));
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final favorites = ref.watch(favoritesProvider);
    final library = ref.watch(libraryControllerProvider);

    return switch (favorites) {
      AsyncData(:final value) => () {
        final present = {for (final f in value) f.paragraphId};
        _hidden.removeWhere((id) => !present.contains(id));
        final items = value
            .where((f) => !_hidden.contains(f.paragraphId))
            .toList();
        if (items.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.bookmark_border,
                      size: 72,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.favoritesEmptyTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.favoritesEmptyHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final item = items[i];
            final libraryItem = library.item(item.bookId);
            return Dismissible(
              key: ValueKey((
                item.paragraphId,
                _restored[item.paragraphId] ?? 0,
              )),
              onDismissed: (_) => _remove(item),
              child: _FavoriteCard(
                item: item,
                bookTitle:
                    item.bookTitle ??
                    libraryItem?.title.ar ??
                    l10n.unavailableBook,
                canDownload:
                    !library.isOffline &&
                    libraryItem?.entry != null &&
                    library.tasks[item.bookId] == null,
                onRemove: () => _remove(item),
              ),
            );
          },
        );
      }(),
      AsyncError() => Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(32),
          child: Text(l10n.favoritesError, textAlign: TextAlign.center),
        ),
      ),
      _ => Center(
        child: Semantics(
          label: l10n.loading,
          child: const CircularProgressIndicator(),
        ),
      ),
    };
  }
}

class _FavoriteCard extends ConsumerWidget {
  const _FavoriteCard({
    required this.item,
    required this.bookTitle,
    required this.canDownload,
    required this.onRemove,
  });

  final FavoriteItem item;
  final String bookTitle;
  final bool canDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final source = item.chapterTitle == null
        ? bookTitle
        : l10n.breadcrumb(bookTitle, item.chapterTitle!);
    final installed = item.bookInstalled;
    final text = item.text;
    // الكتاب محمّل لكن الفقرة لم تعد فيه (معرّف بلا تحويل) ≠ كتاب غير محمّل.
    final status = installed
        ? l10n.paragraphMissing
        : l10n.bookNotInstalledShort;

    final summary = Semantics(
      button: true,
      label: l10n.passageSemantics(source, text ?? status),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(source, style: muted),
          const SizedBox(height: 4),
          if (text != null)
            Text(
              text.replaceAll('\t', ' ').replaceAll('\n', ' '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontFamily: bookFont,
                fontSize: 18,
                height: 1.8,
              ),
            )
          else
            Text(status, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            context.push(readerParagraphPath(item.bookId, item.paragraphId)),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  if (!installed)
                    OutlinedButton.icon(
                      onPressed: canDownload
                          ? () => startDownload(context, ref, item.bookId)
                          : null,
                      icon: const Icon(Icons.download),
                      label: Text(l10n.download),
                    ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.bookmark_remove_outlined),
                    label: Text(l10n.remove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
