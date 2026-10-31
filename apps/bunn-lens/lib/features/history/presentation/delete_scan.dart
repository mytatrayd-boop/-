import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../l10n/gen/app_localizations.dart';

/// يطلب تأكيد المستخدم ثم يحذف. يعيد true إن حُذف فعلاً.
Future<bool> confirmAndDeleteScan(BuildContext context, WidgetRef ref, int id) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteScanTitle),
      content: Text(l10n.deleteScanBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.scanDelete, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  try {
    final ok = await ref.read(scanRepositoryProvider).delete(id);
    if (ok) messenger.showSnackBar(SnackBar(content: Text(l10n.scanDeleted)));
    return ok;
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.scanDeleteFailed)));
    return false;
  }
}
