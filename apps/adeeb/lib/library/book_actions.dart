import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import 'library_controller.dart';
import 'library_text.dart';

void _snack(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
}

/// تحميل أو تحديث، مع رسالة «حُدّث الكتاب» بعد التحديث (DESIGN §7.2).
Future<void> startDownload(BuildContext context, WidgetRef ref, String bookId) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await ref.read(libraryControllerProvider.notifier).download(bookId);
  if (outcome == DownloadOutcome.updated) _snack(messenger, l10n.bookUpdated);
}

/// حوار التأكيد ثم الحذف (DESIGN §7.2). يعيد true إن حُذف الكتاب.
Future<bool> confirmAndDelete(BuildContext context, WidgetRef ref, LibraryItem item) async {
  final l10n = AppLocalizations.of(context);
  final freed = item.installed?.bytes ?? item.displaySize;
  // النصوص تُحسب قبل الحوار: قد تُغلق الصفحة المستدعية أثناء حركة إغلاقه.
  final body = l10n.deleteDialogBody(item.title.ar, l10n.size(context, freed));
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.deleteDialogTitle),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final ok = await ref.read(libraryControllerProvider.notifier).delete(item.id);
  _snack(messenger, ok ? l10n.bookDeleted : l10n.deleteFailed);
  return ok;
}
