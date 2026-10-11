import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import 'book_actions.dart';
import 'generated_cover.dart';
import 'library_controller.dart';
import 'library_text.dart';

/// بطاقة كتاب في المكتبة بحالاتها (DESIGN §7.2).
class BookCard extends ConsumerWidget {
  const BookCard({super.key, required this.item, required this.task, required this.offline});

  final LibraryItem item;
  final BookTask? task;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isEnglish = Localizations.localeOf(context).languageCode == 'en';
    // عند تكبير الخط كثيراً تصبح البطاقة عمودية ولا يُقص العنوان (DESIGN §7.5).
    final vertical = MediaQuery.textScalerOf(context).scale(16) >= 24;
    final status = item.status;

    final statusText = _statusText(context, l10n, status);
    // النسبة لا تدخل في تسمية البطاقة؛ تُعلَن كل 25٪ فقط من شاشة المكتبة.
    final details = [
      ?l10n.deathSpoken(context, item.authorDeathHijri),
      l10n.sizeSpoken(context, item.displaySize),
      if (task is DownloadingTask) l10n.downloading else statusText.text,
    ].join(l10n.listSeparator);

    final info = Semantics(
      container: true,
      label: l10n.bookCardSemantics(item.title.ar, item.author.ar, details),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            item.title.ar,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: bookFont, fontSize: 20, height: 1.6),
          ),
          if (isEnglish && item.title.en != null)
            Text(
              [item.title.en!, ?item.author.en].join(' — '),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          Text(
            l10n.authorLine(context, item.author.ar, item.authorDeathHijri),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.size(context, item.displaySize),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );

    final downloading = task is DownloadingTask;
    final progress = switch (task) {
      DownloadingTask(:final fraction) =>
        ExcludeSemantics(child: LinearProgressIndicator(value: fraction)),
      PreparingTask() => const LinearProgressIndicator(),
      _ => null,
    };

    final statusRow = ExcludeSemantics(
      excluding: downloading,
      child: Row(
      children: [
        if (statusText.icon != null) ...[
          Icon(statusText.icon, size: 20, color: statusText.color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            statusText.text,
            style: theme.textTheme.labelMedium?.copyWith(color: statusText.color),
          ),
        ),
      ],
      ),
    );

    final button = _actionButton(context, ref, l10n, status);

    final body = vertical
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: GeneratedCover(bookId: item.id, title: item.title.ar, width: 96)),
              const SizedBox(height: 12),
              info,
              const SizedBox(height: 8),
              ?progress,
              statusRow,
              const SizedBox(height: 8),
              ?button,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GeneratedCover(bookId: item.id, title: item.title.ar, width: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 8),
                    if (progress != null) ...[progress, const SizedBox(height: 4)],
                    Row(
                      children: [
                        Expanded(child: statusRow),
                        const SizedBox(width: 8),
                        ?button,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/book/${item.id}'),
        onLongPress: status == BookStatus.notInstalled || task != null
            ? null
            : () => _showInstalledMenu(context, ref, l10n),
        child: Padding(padding: const EdgeInsetsDirectional.all(12), child: body),
      ),
    );
  }

  _StatusText _statusText(BuildContext context, AppLocalizations l10n, BookStatus status) {
    final colors = Theme.of(context).colorScheme;
    final extra = context.extraColors;
    final muted = colors.onSurfaceVariant;
    return switch (task) {
      DownloadingTask(:final fraction) => _StatusText(l10n.percent(context, fraction), muted),
      PreparingTask() => _StatusText(l10n.preparing, muted),
      FailedTask(failure: TaskFailure.network) =>
        _StatusText(l10n.downloadInterrupted, colors.error, Icons.error_outline),
      FailedTask(failure: TaskFailure.integrity) =>
        _StatusText(l10n.fileCorrupt, colors.error, Icons.error_outline),
      FailedTask() => _StatusText(l10n.downloadFailed, colors.error, Icons.error_outline),
      null => switch (status) {
          BookStatus.installed => _StatusText(l10n.installed, extra.success, Icons.check_circle),
          BookStatus.updateAvailable =>
            _StatusText(l10n.updateAvailable, colors.secondary, Icons.update),
          BookStatus.notInstalled when offline || item.entry == null =>
            _StatusText(l10n.needsConnection, muted, Icons.cloud_off),
          BookStatus.notInstalled => _StatusText(l10n.notInstalled, muted),
        },
    };
  }

  Widget? _actionButton(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, BookStatus status) {
    final controller = ref.read(libraryControllerProvider.notifier);
    switch (task) {
      case DownloadingTask():
        return TextButton(onPressed: () => controller.cancel(item.id), child: Text(l10n.cancel));
      case PreparingTask():
        return null;
      case FailedTask(:final failure):
        return OutlinedButton(
          onPressed: () => startDownload(context, ref, item.id),
          child: Text(failure == TaskFailure.integrity ? l10n.redownload : l10n.retry),
        );
      case null:
        break;
    }
    switch (status) {
      case BookStatus.installed:
        return FilledButton(
          onPressed: () => context.push('/book/${item.id}'),
          child: Text(l10n.open),
        );
      case BookStatus.updateAvailable:
        return OutlinedButton(
          onPressed: offline ? null : () => startDownload(context, ref, item.id),
          child: Text(l10n.update),
        );
      case BookStatus.notInstalled:
        final canDownload = !offline && item.entry != null;
        return OutlinedButton.icon(
          onPressed: canDownload ? () => startDownload(context, ref, item.id) : null,
          icon: const Icon(Icons.download),
          label: Text(l10n.download),
        );
    }
  }

  Future<void> _showInstalledMenu(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(l10n.open),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push('/book/${item.id}');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(sheetContext).colorScheme.error),
              title: Text(
                l10n.deleteFromDevice,
                style: TextStyle(color: Theme.of(sheetContext).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                confirmAndDelete(context, ref, item);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusText {
  const _StatusText(this.text, this.color, [this.icon]);
  final String text;
  final Color color;
  final IconData? icon;
}
