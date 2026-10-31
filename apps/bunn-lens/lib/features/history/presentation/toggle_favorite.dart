import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../l10n/gen/app_localizations.dart';

/// يبدّل المفضلة فوراً مع اهتزاز خفيف ورسالة «تراجع».
Future<void> toggleFavorite(BuildContext context, WidgetRef ref, int id, bool current) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(scanRepositoryProvider);
  final next = !current;
  HapticFeedback.lightImpact();
  try {
    if (!await repo.setFavorite(id, next)) throw StateError('scan $id not found');
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.favoriteFailed)));
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(next ? l10n.favoriteAdded : l10n.favoriteRemoved),
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () => repo.setFavorite(id, current),
      ),
    ));
}
