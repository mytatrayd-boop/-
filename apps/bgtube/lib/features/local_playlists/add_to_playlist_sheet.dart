import 'package:material_ui/material_ui.dart';

import '../../domain/models/local_playlist.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/local_playlist_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../player/text_direction.dart';
import '../queue/queue_ui.dart';
import 'playlist_dialogs.dart';

/// «أضف إلى قائمة محلية…»: ورقة بأسماء القوائم وصف «+ قائمة جديدة» (DESIGN 4ب).
Future<void> showAddToPlaylistSheet(BuildContext context, LocalPlaylistRepository repo, VideoRef video) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  List<LocalPlaylist> lists;
  try {
    lists = await repo.list();
  } catch (_) {
    showUndoSnack(messenger, l, l.playlistsLoadError);
    return;
  }
  if (!context.mounted) return;
  LocalPlaylist? chosen;
  var createNew = false;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const Key('addToPlaylist_new'),
              minTileHeight: 56,
              leading: const Icon(Icons.add),
              title: Text(l.newPlaylist),
              onTap: () {
                createNew = true;
                Navigator.of(sheet).pop();
              },
            ),
            for (final p in lists)
              ListTile(
                key: Key('addToPlaylist_${p.id}'),
                minTileHeight: 56,
                leading: const Icon(Icons.queue_music),
                title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: textDirectionFor(p.name)),
                onTap: () {
                  chosen = p;
                  Navigator.of(sheet).pop();
                },
              ),
          ],
        ),
      ),
    ),
  );
  try {
    if (createNew) {
      if (!context.mounted) return;
      final name = await showPlaylistNameDialog(context, title: l.newPlaylist);
      if (name == null) return;
      final id = await repo.create(name, [video]);
      showUndoSnack(messenger, l, l.addedToPlaylist(name), onUndo: () => repo.delete(id));
      return;
    }
    final p = chosen;
    if (p == null) return;
    final items = await repo.items(p.id);
    if (items.any((r) => r.videoId == video.videoId)) {
      showUndoSnack(messenger, l, l.alreadyInPlaylist(p.name));
      return;
    }
    await repo.setItems(p.id, [...items, video]);
    showUndoSnack(messenger, l, l.addedToPlaylist(p.name), onUndo: () => repo.setItems(p.id, items));
  } catch (_) {
    showUndoSnack(messenger, l, l.saveFailed);
  }
}
