import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models/local_playlist.dart';
import '../../domain/ports/local_playlist_repository.dart';
import '../../domain/ports/playback_queue.dart';
import '../../l10n/gen/app_localizations.dart';
import '../player/text_direction.dart';
import '../queue/queue_ui.dart';
import 'local_playlist_screen.dart';
import 'playlist_dialogs.dart';

/// «قوائمي المحلية» (DESIGN 4ب): أول شريحة في المكتبة (الميزة 5). محتوى بلا
/// Scaffold؛ تفتح القائمة داخل متصفّح وجهة المكتبة.
class LocalPlaylistsView extends ConsumerStatefulWidget {
  const LocalPlaylistsView({super.key});

  @override
  ConsumerState<LocalPlaylistsView> createState() => _LocalPlaylistsViewState();
}

class _LocalPlaylistsViewState extends ConsumerState<LocalPlaylistsView> {
  late Stream<List<LocalPlaylist>> _stream;

  LocalPlaylistRepository get _repo => ref.read(localPlaylistRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _stream = _repo.watchAll();
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showPlaylistNameDialog(context, title: l.newPlaylist);
    if (name == null) return;
    try {
      await _repo.create(name, const []);
    } catch (_) {
      showUndoSnack(messenger, l, l.saveFailed);
    }
  }

  Future<void> _enqueue(LocalPlaylist p, QueuePlacement placement) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final items = await _repo.items(p.id);
      if (!mounted) return;
      if (items.isEmpty) {
        showUndoSnack(messenger, l, l.playlistEmpty);
        return;
      }
      await enqueueWithFeedback(context, ref.read(playbackQueueProvider), items, placement);
    } catch (_) {
      showUndoSnack(messenger, l, l.playlistsLoadError);
    }
  }

  Future<void> _rename(LocalPlaylist p) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showPlaylistNameDialog(context, title: l.rename, initial: p.name);
    if (name == null || name == p.name) return;
    try {
      await _repo.rename(p.id, name);
    } catch (_) {
      showUndoSnack(messenger, l, l.saveFailed);
    }
  }

  Future<void> _delete(LocalPlaylist p) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(context,
        title: l.deletePlaylistTitle(p.name), body: l.deletePlaylistBody, action: l.delete);
    if (!ok) return;
    try {
      await _repo.delete(p.id);
    } catch (_) {
      showUndoSnack(messenger, l, l.saveFailed);
    }
  }

  void _menu(LocalPlaylist p) {
    final l = AppLocalizations.of(context);
    showActionSheet(context, [
      SheetAction(
          key: const Key('playlistMenuPlay'), icon: Icons.play_arrow, label: l.play, onTap: () => _enqueue(p, QueuePlacement.playNow)),
      SheetAction(
          key: const Key('playlistMenuPlayNext'),
          icon: Icons.queue_play_next,
          label: l.actionPlayNext,
          onTap: () => _enqueue(p, QueuePlacement.playNext)),
      SheetAction(
          key: const Key('playlistMenuAddToEnd'),
          icon: Icons.playlist_add,
          label: l.actionAddToEnd,
          onTap: () => _enqueue(p, QueuePlacement.addToEnd)),
      SheetAction(key: const Key('playlistMenuRename'), icon: Icons.edit, label: l.rename, onTap: () => _rename(p)),
      SheetAction(
          key: const Key('playlistMenuDelete'),
          icon: Icons.delete_outline,
          label: l.delete,
          color: AppColors.error,
          onTap: () => _delete(p)),
    ], title: p.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<LocalPlaylist>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(onRetry: () => setState(() => _stream = _repo.watchAll()));
        }
        final lists = snap.data;
        if (lists == null) return const Center(child: CircularProgressIndicator());
        if (lists.isEmpty) return _Empty(onCreate: _create);
        return ListView(
          children: [
            ListTile(
              key: const Key('newPlaylistRow'),
              minTileHeight: 56,
              leading: const Icon(Icons.add),
              title: Text(l.newPlaylist),
              onTap: _create,
            ),
            for (final p in lists)
              _PlaylistRow(
                playlist: p,
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => LocalPlaylistScreen(playlistId: p.id, initialName: p.name),
                )),
                onMenu: () => _menu(p),
              ),
          ],
        );
      },
    );
  }
}

class _PlaylistRow extends StatelessWidget {
  const _PlaylistRow({required this.playlist, required this.onTap, required this.onMenu});
  final LocalPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InkWell(
      key: Key('playlistRow_${playlist.id}'),
      onTap: onTap,
      onLongPress: onMenu,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.queue_music, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: textDirectionFor(playlist.name),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(itemsSummary(context, playlist.itemCount, playlist.totalDuration),
                            style: theme.textTheme.bodySmall),
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(l.onDevice, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('playlistMenu_${playlist.id}'),
                tooltip: l.moreActions,
                icon: const Icon(Icons.more_vert),
                onPressed: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.queue_music, size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(l.playlistsEmpty, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('emptyNewPlaylist'),
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l.newPlaylist),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Card(
        color: AppColors.surface,
        margin: const EdgeInsetsDirectional.all(16),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error),
              const SizedBox(height: 8),
              Text(l.playlistsLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: Text(l.retry)),
            ],
          ),
        ),
      ),
    );
  }
}
