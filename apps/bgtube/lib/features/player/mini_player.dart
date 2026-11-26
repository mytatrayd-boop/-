import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/playback_queue_model.dart';
import '../../l10n/gen/app_localizations.dart';
import '../queue/queue_sheet.dart';
import '../queue/queue_ui.dart';
import 'player_screen.dart';
import 'text_direction.dart';

/// يفتح المشغّل الكامل فوق كل شيء (صفحته كما هي).
Future<void> openFullPlayer(BuildContext context) => Navigator.of(context, rootNavigator: true)
    .push(MaterialPageRoute<void>(builder: (_) => const PlayerScreen()));

/// المشغّل المصغّر (DESIGN §3): شريط 64 فوق الشريط السفلي بسطح مرتفع وخط تقدم
/// 2dp، العنوان وتحته القناة و« · n متبقية» (يفتح الطابور)، تشغيل/إيقاف والتالي.
/// النقر على الشريط يفتح المشغّل الكامل. يظهر عند وجود تشغيل أو طابور.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(playbackControllerProvider);
    final queue = ref.watch(playbackQueueProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.nowPlaying,
        controller.failure,
        controller.resolving,
        controller.playing,
        queue.queueState,
      ]),
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final now = controller.nowPlaying.value;
        final QueueSnapshot s = queue.queueState.value;
        final failure = controller.failure.value;
        final resolving = controller.resolving.value;
        final current = s.current?.ref;
        if (now == null && current == null && failure == null && !resolving) return const SizedBox.shrink();

        final title = now?.title ?? (current == null ? '' : videoTitle(l, current));
        final author = now?.author ?? current?.author;
        final remaining = s.remainingCount;
        final total = now?.duration ?? current?.duration;

        final Widget mainButton;
        if (failure != null) {
          mainButton = IconButton(
            key: const Key('miniRetry'),
            tooltip: l.retry,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: controller.retry,
            icon: const Icon(Icons.refresh, color: AppColors.error),
          );
        } else if (resolving) {
          mainButton = const SizedBox(
            width: 48,
            height: 48,
            child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        } else {
          final playing = controller.playing.value;
          mainButton = IconButton(
            key: const Key('miniPlayPause'),
            tooltip: playing ? l.pause : l.play,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: playing ? controller.pause : controller.play,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
          );
        }

        final secondaryStyle = theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);
        return Material(
          key: const Key('miniPlayer'),
          color: AppColors.surfaceHigh,
          child: InkWell(
            onTap: () => openFullPlayer(context),
            child: Semantics(
              button: true,
              label: l.openPlayer,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // التقدم ثابت LTR كشريط المشغّل الكامل (DESIGN: RTL).
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: StreamBuilder<Duration>(
                      stream: controller.positionStream,
                      builder: (context, snap) {
                        final ms = total?.inMilliseconds ?? 0;
                        final pos = snap.data?.inMilliseconds ?? 0;
                        return LinearProgressIndicator(
                          minHeight: 2,
                          value: ms > 0 ? (pos / ms).clamp(0.0, 1.0) : 0,
                          backgroundColor: AppColors.divider,
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: 62,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: current?.thumbUrl == null
                                ? const ColoredBox(
                                    color: AppColors.surface,
                                    child: Icon(Icons.music_note, color: AppColors.textSecondary, size: 20),
                                  )
                                : Image.network(current!.thumbUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surface)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  key: const Key('miniTitle'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: textDirectionFor(title),
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              if (failure != null)
                                Text(l.miniPlaybackFailed,
                                    maxLines: 1, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error))
                              else
                                Row(
                                  children: [
                                    if (author != null)
                                      Flexible(
                                        child: Text(author,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textDirection: textDirectionFor(author),
                                            style: secondaryStyle),
                                      ),
                                    if (remaining > 0)
                                      InkWell(
                                        key: const Key('miniRemaining'),
                                        onTap: () => showQueueSheet(context),
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(minHeight: 24),
                                          child: Center(
                                            widthFactor: 1,
                                            child: Text(' · ${l.queueRemaining(remaining)}', style: secondaryStyle),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        mainButton,
                        IconButton(
                          key: const Key('miniNext'),
                          tooltip: l.next,
                          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                          onPressed: s.next == null ? null : queue.skipToNext,
                          icon: const Icon(Icons.skip_next),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
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
