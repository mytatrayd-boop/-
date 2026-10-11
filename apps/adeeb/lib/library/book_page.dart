import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'book_actions.dart';
import 'generated_cover.dart';
import 'library_controller.dart';
import 'library_providers.dart';
import 'library_text.dart';

/// صفحة الكتاب (DESIGN §8): الرأس، والتحميل، وأبواب الكتاب المحمّل.
/// أزرار «ابدأ القراءة» و«استمع» و«ابحث» تأتي مع الميزات 3 و4 و5.
class BookPage extends ConsumerWidget {
  const BookPage({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(libraryControllerProvider);
    final item = state.item(bookId);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: state.status == CatalogStatus.loading
              ? Semantics(label: l10n.loading, child: const CircularProgressIndicator())
              : Text(l10n.bookNotFound),
        ),
      );
    }

    final task = state.tasks[bookId];
    final status = item.status;
    final installed = status != BookStatus.notInstalled;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (installed && task == null)
            PopupMenuButton<void>(
              tooltip: l10n.moreOptions,
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () async {
                    final deleted = await confirmAndDelete(context, ref, item);
                    if (deleted && context.mounted) Navigator.of(context).maybePop();
                  },
                  child: Text(l10n.deleteFromDevice),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
              sliver: SliverToBoxAdapter(child: _Header(item: item)),
            ),
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _Actions(item: item, task: task, offline: state.isOffline),
              ),
            ),
            if (installed)
              _ChapterList(bookId: bookId)
            else
              SliverPadding(
                padding: const EdgeInsetsDirectional.all(16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    l10n.downloadToSeeChapters,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.item});
  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    return Column(
      children: [
        GeneratedCover(bookId: item.id, title: item.title.ar, width: 120),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            item.title.ar,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: bookFont, fontSize: 26, height: 1.6),
          ),
        ),
        if (isEnglish && item.title.en != null)
          Text([item.title.en!, ?item.author.en].join(' — '),
              textAlign: TextAlign.center, style: muted),
        Text(
          l10n.authorLine(context, item.author.ar, item.authorDeathHijri),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.sourceLine(item.sourceName, l10n.licenseName(item.license)),
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.item, required this.task, required this.offline});
  final LibraryItem item;
  final BookTask? task;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(libraryControllerProvider.notifier);
    final canDownload = !offline && item.entry != null;

    switch (task) {
      case DownloadingTask(:final fraction):
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: fraction),
                  const SizedBox(height: 4),
                  Text(l10n.percent(context, fraction), style: theme.textTheme.labelMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: () => controller.cancel(item.id), child: Text(l10n.cancel)),
          ],
        );
      case PreparingTask():
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 4),
            Text(l10n.preparing, style: theme.textTheme.labelMedium),
          ],
        );
      case FailedTask(:final failure):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    switch (failure) {
                      TaskFailure.network => l10n.downloadInterrupted,
                      TaskFailure.integrity => l10n.fileCorrupt,
                      TaskFailure.other => l10n.downloadFailed,
                    },
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => startDownload(context, ref, item.id),
              child: Text(failure == TaskFailure.integrity ? l10n.redownload : l10n.retry),
            ),
          ],
        );
      case null:
        break;
    }

    switch (item.status) {
      case BookStatus.notInstalled:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: canDownload ? () => startDownload(context, ref, item.id) : null,
              icon: const Icon(Icons.download),
              label: Text(l10n.downloadBook(l10n.size(context, item.displaySize))),
            ),
            if (!canDownload) ...[
              const SizedBox(height: 4),
              Text(l10n.needsConnection, textAlign: TextAlign.center, style: theme.textTheme.labelMedium),
            ],
          ],
        );
      case BookStatus.updateAvailable:
        return Row(
          children: [
            Icon(Icons.update, color: theme.colorScheme.secondary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.updateAvailable)),
            OutlinedButton(
              onPressed: offline ? null : () => startDownload(context, ref, item.id),
              child: Text(l10n.update),
            ),
          ],
        );
      case BookStatus.installed:
        return Row(
          children: [
            Icon(Icons.check_circle, color: context.extraColors.success),
            const SizedBox(width: 8),
            Text(l10n.installed),
          ],
        );
    }
  }
}

class _ChapterList extends ConsumerWidget {
  const _ChapterList({required this.bookId});
  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final chapters = ref.watch(bookChaptersProvider(bookId));
    return switch (chapters) {
      AsyncData(:final value) when value.isNotEmpty => SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 24),
          sliver: SliverList.builder(
            itemCount: value.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                  child: Semantics(
                    header: true,
                    child: Text(l10n.chapters, style: theme.textTheme.titleMedium),
                  ),
                );
              }
              final c = value[i - 1];
              final number = l10n.number(context, i);
              return Semantics(
                header: true,
                label: l10n.chapterSemantics(number, l10n.number(context, value.length), c.title),
                excludeSemantics: true,
                child: ListTile(
                  contentPadding: EdgeInsetsDirectional.only(start: 16.0 + (c.level - 1) * 16, end: 16),
                  leading: Text(number, style: theme.textTheme.labelMedium),
                  title: Text(
                    c.title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: bookFont, fontSize: 18, height: 1.6),
                  ),
                ),
              );
            },
          ),
        ),
      AsyncError() => SliverPadding(
          padding: const EdgeInsetsDirectional.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.bookOpenError, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: ref.watch(libraryControllerProvider).isOffline
                      ? null
                      : () => startDownload(context, ref, bookId),
                  child: Text(l10n.redownload),
                ),
              ],
            ),
          ),
        ),
      AsyncData() => const SliverToBoxAdapter(child: SizedBox.shrink()),
      _ => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: Center(
              child: Semantics(label: l10n.loading, child: const CircularProgressIndicator()),
            ),
          ),
        ),
    };
  }
}
