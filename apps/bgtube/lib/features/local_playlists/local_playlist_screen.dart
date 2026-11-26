import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/local_playlist_repository.dart';
import '../../domain/ports/playback_queue.dart';
import '../../l10n/gen/app_localizations.dart';
import '../player/text_direction.dart';
import '../queue/queue_ui.dart';
import 'add_to_playlist_sheet.dart';

/// مقاطع قائمة محلية بنفس صفوف الطابور: مقبض ترتيب، وحذف بالسحب مع «تراجع»،
/// و«تشغيل الكل» و«أضف القائمة كلها» في الأسفل (DESIGN 4ب).
class LocalPlaylistScreen extends ConsumerStatefulWidget {
  const LocalPlaylistScreen({super.key, required this.playlistId, required this.initialName});
  final int playlistId;
  final String initialName;

  @override
  ConsumerState<LocalPlaylistScreen> createState() => _LocalPlaylistScreenState();
}

class _LocalPlaylistScreenState extends ConsumerState<LocalPlaylistScreen> {
  late Stream<List<VideoRef>> _stream;

  /// آخر ما عُرض، لتطبيق الترتيب والحذف فوراً قبل وصول التحديث من التخزين.
  List<VideoRef>? _items;

  LocalPlaylistRepository get _repo => ref.read(localPlaylistRepositoryProvider);
  PlaybackQueue get _queue => ref.read(playbackQueueProvider);

  @override
  void initState() {
    super.initState();
    _stream = _repo.watchItems(widget.playlistId);
  }

  Future<void> _write(List<VideoRef> items) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _items = items);
    try {
      await _repo.setItems(widget.playlistId, items);
    } catch (_) {
      showUndoSnack(messenger, l, l.saveFailed);
    }
  }

  void _remove(List<VideoRef> items, int index) {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final before = items;
    _write([...items]..removeAt(index));
    showUndoSnack(messenger, l, l.removedFromPlaylist, onUndo: () => _write(before));
  }

  void _menu(VideoRef r) {
    final l = AppLocalizations.of(context);
    showActionSheet(context, [
      SheetAction(
        key: const Key('videoMenuPlayNext'),
        icon: Icons.queue_play_next,
        label: l.actionPlayNext,
        onTap: () => enqueueWithFeedback(context, _queue, [r], QueuePlacement.playNext),
      ),
      SheetAction(
        key: const Key('videoMenuAddToEnd'),
        icon: Icons.playlist_add,
        label: l.actionAddToEnd,
        onTap: () => enqueueWithFeedback(context, _queue, [r], QueuePlacement.addToEnd),
      ),
      SheetAction(
        key: const Key('videoMenuAddToPlaylist'),
        icon: Icons.library_add,
        label: l.actionAddToLocalPlaylist,
        onTap: () => showAddToPlaylistSheet(context, _repo, r),
      ),
    ], title: videoTitle(l, r));
  }

  Future<void> _addAll(List<VideoRef> items) async {
    final placement = await showPlacementSheet(context, includePlayNow: false, title: AppLocalizations.of(context).addWholeList);
    if (placement == null || !mounted) return;
    await enqueueWithFeedback(context, _queue, items, placement);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<VideoRef>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasData) _items = snap.data;
        final items = _items;
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.initialName,
                maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: textDirectionFor(widget.initialName)),
          ),
          body: SafeArea(
            child: snap.hasError
                ? Center(child: Text(l.playlistsLoadError))
                : items == null
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.all(24),
                              child: Text(l.playlistEmpty, textAlign: TextAlign.center),
                            ),
                          )
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: items.length,
                            onReorderItem: (oldIndex, newIndex) {
                              final list = [...items];
                              list.insert(newIndex, list.removeAt(oldIndex));
                              _write(list);
                            },
                            itemBuilder: (context, i) {
                              final r = items[i];
                              return Dismissible(
                                // المفتاح يعتمد على الموضع والمعرّف (التكرار ممكن).
                                key: ValueKey('${r.videoId}#$i#${items.length}'),
                                background: dismissBackground(context, fromStart: true),
                                secondaryBackground: dismissBackground(context, fromStart: false),
                                onDismissed: (_) => _remove(items, i),
                                child: VideoRow(
                                  video: r,
                                  onTap: () => enqueueWithFeedback(context, _queue, [r], QueuePlacement.playNow),
                                  onLongPress: () => _menu(r),
                                  trailing: DragHandle(index: i),
                                ),
                              );
                            },
                          ),
          ),
          bottomNavigationBar: items == null || items.isEmpty
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        FilledButton.icon(
                          key: const Key('playAll'),
                          onPressed: () => enqueueWithFeedback(context, _queue, items, QueuePlacement.playNow),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(l.playAll),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const Key('addWholeList'),
                          tooltip: l.addWholeList,
                          color: AppColors.primary,
                          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                          onPressed: () => _addAll(items),
                          icon: const Icon(Icons.playlist_add),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
