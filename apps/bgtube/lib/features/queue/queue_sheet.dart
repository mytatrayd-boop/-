import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/playback_queue_model.dart';
import '../../domain/ports/playback_controller.dart';
import '../../domain/ports/playback_queue.dart';
import '../../l10n/gen/app_localizations.dart';
import '../local_playlists/add_to_playlist_sheet.dart';
import '../local_playlists/local_playlist_screen.dart';
import '../local_playlists/playlist_dialogs.dart';
import 'queue_ui.dart';

/// شاشة الطابور (DESIGN 4أ): ورقة سفلية بملء الشاشة تقريباً؛ تُسحب للأسفل أو
/// بالرجوع للإغلاق.
Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const FractionallySizedBox(heightFactor: 0.94, child: QueueView()),
  );
}

/// ارتفاع صف تقريبي للتمرير إلى الحالي عند الفتح.
const _rowExtent = 64.0;

class QueueView extends ConsumerStatefulWidget {
  const QueueView({super.key});

  @override
  ConsumerState<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends ConsumerState<QueueView> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final i = ref.read(playbackQueueProvider).queueState.value.currentIndex;
    // الحالي أول الظاهر دائماً.
    _scroll = ScrollController(initialScrollOffset: i <= 0 ? 0 : i * _rowExtent);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(playbackQueueProvider);
    final controller = ref.watch(playbackControllerProvider);
    // رسائل الطابور تظهر داخل الورقة لا تحتها.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ValueListenableBuilder<QueueSnapshot>(
          valueListenable: queue.queueState,
          builder: (context, s, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(snapshot: s, queue: queue),
              Expanded(
                child: s.isEmpty ? const _EmptyQueue() : _QueueList(snapshot: s, queue: queue, controller: controller, scroll: _scroll),
              ),
              if (!s.isEmpty) _BottomActions(snapshot: s, queue: queue),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _saveAsPlaylist(BuildContext context, WidgetRef ref, QueueSnapshot s) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final locale = Localizations.localeOf(context).languageCode;
  final repo = ref.read(localPlaylistRepositoryProvider);
  final name = await showPlaylistNameDialog(
    context,
    title: l.queueSaveAsLocalPlaylist,
    initial: l.queueDefaultPlaylistName(DateFormat.MMMMd(locale).format(DateTime.now())),
  );
  if (name == null) return;
  try {
    // نسخة لا تحمل علامات الفشل (D27).
    final id = await repo.create(name, [for (final e in s.entries) e.ref]);
    showUndoSnack(messenger, l, l.playlistSaved(name),
        actionLabel: l.open,
        onUndo: () => navigator.push(MaterialPageRoute<void>(
              builder: (_) => LocalPlaylistScreen(playlistId: id, initialName: name),
            )));
  } catch (_) {
    showUndoSnack(messenger, l, l.saveFailed);
  }
}

Future<void> _clear(BuildContext context, PlaybackQueue queue) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final ok = await confirmDestructive(context,
      title: l.queueClearConfirmTitle, body: l.queueClearConfirmBody, action: l.queueClearAction);
  if (!ok) return;
  final removed = clearedEntries(queue.queueState.value);
  await queue.clearUpcoming();
  showUndoSnack(messenger, l, l.queueCleared, onUndo: () => queue.restoreEntries(removed));
}

class _Header extends ConsumerWidget {
  const _Header({required this.snapshot, required this.queue});
  final QueueSnapshot snapshot;
  final PlaybackQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cur = snapshot.current;
    final remaining = [?cur?.ref, ...snapshot.upcoming.map((e) => e.ref)];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.queueTitle, style: theme.textTheme.titleLarge),
                if (!snapshot.isEmpty)
                  Text(itemsSummary(context, snapshot.entries.length, totalDuration(remaining)),
                      key: const Key('queueSummary'), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (!snapshot.isEmpty)
            IconButton(
              key: const Key('queueHeaderMenu'),
              tooltip: l.moreActions,
              icon: const Icon(Icons.more_vert),
              onPressed: () => showActionSheet(context, [
                SheetAction(
                  key: const Key('queueMenuSave'),
                  icon: Icons.playlist_add_check,
                  label: l.queueSaveAsLocalPlaylist,
                  onTap: () => _saveAsPlaylist(context, ref, queue.queueState.value),
                ),
                SheetAction(
                  key: const Key('queueMenuClear'),
                  icon: Icons.clear_all,
                  label: l.queueClear,
                  color: AppColors.error,
                  onTap: () => _clear(context, queue),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.snapshot, required this.queue});
  final QueueSnapshot snapshot;
  final PlaybackQueue queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              key: const Key('queueSave'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => _saveAsPlaylist(context, ref, snapshot),
              icon: const Icon(Icons.playlist_add_check),
              label: Text(l.queueSaveAsPlaylist),
            ),
            TextButton(
              key: const Key('queueClear'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size(48, 48)),
              onPressed: () => _clear(context, queue),
              child: Text(l.queueClear),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

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
            Text(l.queueEmpty, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _QueueList extends ConsumerWidget {
  const _QueueList({required this.snapshot, required this.queue, required this.controller, required this.scroll});
  final QueueSnapshot snapshot;
  final PlaybackQueue queue;
  final PlaybackController controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = snapshot.entries;
    final currentIndex = snapshot.currentIndex;
    return ReorderableListView.builder(
      scrollController: scroll,
      buildDefaultDragHandles: false,
      itemCount: entries.length,
      onReorderStart: (_) => HapticFeedback.selectionClick(),
      onReorderItem: (oldIndex, newIndex) {
        queue.moveEntry(entries[oldIndex].key, newIndex);
      },
      itemBuilder: (context, i) {
        final e = entries[i];
        if (i == currentIndex) {
          return _CurrentRow(
            key: ValueKey(e.key),
            entry: e,
            controller: controller,
            queue: queue,
            nothingAfter: i == entries.length - 1,
          );
        }
        return _EntryRow(
          key: ValueKey(e.key),
          entry: e,
          index: i,
          played: i < currentIndex,
          snapshot: snapshot,
          queue: queue,
        );
      },
    );
  }
}

/// الحالي: سطح مرتفع وحد على الجهة الأولى بالأساسي، ووسم «يعمل الآن» (لا يعتمد
/// على اللون وحده)، لا يُسحب ولا يُحذف بالسحب.
class _CurrentRow extends StatelessWidget {
  const _CurrentRow({
    super.key,
    required this.entry,
    required this.controller,
    required this.queue,
    required this.nothingAfter,
  });
  final QueueEntry entry;
  final PlaybackController controller;
  final PlaybackQueue queue;
  final bool nothingAfter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([controller.playing, controller.resolving]),
          builder: (context, _) {
            final Widget status = controller.resolving.value
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(controller.playing.value ? Icons.graphic_eq : Icons.pause,
                    size: 16, color: AppColors.primary);
            return VideoRow(
              key: const Key('queueCurrentRow'),
              video: entry.ref,
              highlighted: true,
              onTap: () => queue.jumpTo(entry.key),
              subtitle: Row(
                children: [
                  status,
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      [l.queueNowPlaying, ?entry.ref.author].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (nothingAfter)
          Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Text(l.queueNothingAfter,
                key: const Key('queueNothingAfter'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall),
          )
        else
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(l.next, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({
    super.key,
    required this.entry,
    required this.index,
    required this.played,
    required this.snapshot,
    required this.queue,
  });
  final QueueEntry entry;
  final int index;
  final bool played;
  final QueueSnapshot snapshot;
  final PlaybackQueue queue;

  void _remove(BuildContext context) {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final removed = IndexedEntry(index, entry);
    queue.removeEntry(entry.key);
    showUndoSnack(messenger, l, l.queueRemoved, onUndo: () => queue.restoreEntries([removed]));
  }

  void _moveNext() {
    final cur = snapshot.currentIndex;
    // الفهرس بعد الإزالة: إن كان قبل الحالي ينزاح الحالي خطوة.
    queue.moveEntry(entry.key, index < cur ? cur : cur + 1);
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    showActionSheet(context, [
      SheetAction(
        key: const Key('queueRowRemove'),
        icon: Icons.remove_circle_outline,
        label: l.queueRemove,
        onTap: () => _remove(context),
      ),
      SheetAction(key: const Key('queueRowMoveNext'), icon: Icons.queue_play_next, label: l.queueMoveNext, onTap: _moveNext),
      SheetAction(
        key: const Key('queueRowAddToPlaylist'),
        icon: Icons.playlist_add,
        label: l.actionAddToLocalPlaylist,
        onTap: () => showAddToPlaylistSheet(context, ref.read(localPlaylistRepositoryProvider), entry.ref),
      ),
    ], title: videoTitle(l, entry.ref));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = snapshot.entries.length - 1;
    return Dismissible(
      key: ValueKey('dismiss_${entry.key}'),
      background: dismissBackground(context, fromStart: true),
      secondaryBackground: dismissBackground(context, fromStart: false),
      onDismissed: (_) => _remove(context),
      child: Semantics(
        customSemanticsActions: {
          if (index > 0) CustomSemanticsAction(label: l.moveUp): () => queue.moveEntry(entry.key, index - 1),
          if (index < last) CustomSemanticsAction(label: l.moveDown): () => queue.moveEntry(entry.key, index + 1),
          CustomSemanticsAction(label: l.queueMoveNext): _moveNext,
        },
        child: VideoRow(
          video: entry.ref,
          dimmed: played || entry.failed,
          onTap: () => queue.jumpTo(entry.key),
          onLongPress: () => _showMenu(context, ref),
          subtitle: entry.failed
              ? Row(
                  key: Key('queueFailed_${entry.key}'),
                  children: [
                    const Icon(Icons.warning_amber, size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(l.queueFailedItem,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
                    ),
                  ],
                )
              : null,
          trailing: DragHandle(index: index),
        ),
      ),
    );
  }
}
