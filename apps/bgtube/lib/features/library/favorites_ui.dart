import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/favorites_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../queue/queue_ui.dart';

/// يبدّل المفضلة مع رسالة قصيرة و«تراجع» (محلية، D5). فشل التخزين: «تعذّر الحفظ».
Future<void> toggleFavorite(
  ScaffoldMessengerState messenger,
  AppLocalizations l,
  FavoritesRepository repo,
  VideoRef ref, {
  required bool isFavorite,
}) async {
  try {
    if (isFavorite) {
      await repo.remove(ref.videoId);
      showUndoSnack(messenger, l, l.removedFromFavorites, onUndo: () => repo.add(ref));
    } else {
      await repo.add(ref);
      showUndoSnack(messenger, l, l.addedToFavorites, onUndo: () => repo.remove(ref.videoId));
    }
  } catch (_) {
    showUndoSnack(messenger, l, l.saveFailed);
  }
}

/// نجمة المفضلة في المشغّل الكامل: ممتلئة إن كان المقطع فيها، والتبديل فوري.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.video});
  final VideoRef video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final repo = ref.watch(favoritesRepositoryProvider);
    return StreamBuilder<bool>(
      // المفتاح بالمعرّف: مقطع جديد = اشتراك جديد.
      key: ValueKey(video.videoId),
      stream: repo.watchContains(video.videoId),
      builder: (context, snap) {
        final fav = snap.data ?? false;
        return IconButton(
          key: const Key('favoriteButton'),
          tooltip: fav ? l.removeFromFavorites : l.addToFavorites,
          iconSize: 28,
          constraints: const BoxConstraints.tightFor(width: 56, height: 56),
          color: fav ? AppColors.primary : null,
          onPressed: snap.hasData
              ? () => toggleFavorite(ScaffoldMessenger.of(context), l, repo, video, isFavorite: fav)
              : null,
          icon: Icon(fav ? Icons.star : Icons.star_border),
        );
      },
    );
  }
}
