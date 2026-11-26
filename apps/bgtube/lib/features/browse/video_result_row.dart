import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/models/youtube_content.dart';
import '../../domain/ports/playback_queue.dart';
import '../../l10n/gen/app_localizations.dart';
import '../local_playlists/add_to_playlist_sheet.dart';
import '../player/format_duration.dart';
import '../player/text_direction.dart';
import '../queue/queue_ui.dart';

/// قائمة ⋮ لمقطع من الواجهة: «شغّل التالي» ثم «أضف للنهاية» ثم «أضف إلى قائمة
/// محلية…» (DESIGN: قائمة إجراءات المقطع). كلها عبر المنفذ [PlaybackQueue].
Future<void> showVideoActions(BuildContext context, WidgetRef ref, VideoRef video) {
  final l = AppLocalizations.of(context);
  final queue = ref.read(playbackQueueProvider);
  return showActionSheet(
    context,
    [
      SheetAction(
        key: const Key('videoAction_playNext'),
        icon: Icons.queue_play_next,
        label: l.actionPlayNext,
        onTap: () => enqueueWithFeedback(context, queue, [video], QueuePlacement.playNext),
      ),
      SheetAction(
        key: const Key('videoAction_addToEnd'),
        icon: Icons.playlist_add,
        label: l.actionAddToEnd,
        onTap: () => enqueueWithFeedback(context, queue, [video], QueuePlacement.addToEnd),
      ),
      SheetAction(
        key: const Key('videoAction_addToLocal'),
        icon: Icons.library_add_outlined,
        label: l.actionAddToLocalPlaylist,
        onTap: () => showAddToPlaylistSheet(context, ref.read(localPlaylistRepositoryProvider), video),
      ),
    ],
    title: videoTitle(l, video),
  );
}

/// بطاقة فيديو (صف): صورة 16:9 بعرض 120 على الجهة الأولى، العنوان (سطران) والقناة
/// والمدة، و⋮ في النهاية. الضغط = تشغيل الآن، والضغط المطوّل = قائمة ⋮.
class VideoResultRow extends ConsumerWidget {
  const VideoResultRow({super.key, required this.video});

  final VideoRef video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final title = videoTitle(l, video);
    final secondary = [
      if (video.author != null) video.author!,
      if (video.duration != null) formatDuration(video.duration!, locale),
    ].join(' · ');
    return InkWell(
      key: Key('video_${video.videoId}'),
      onTap: () => enqueueWithFeedback(
          context, ref.read(playbackQueueProvider), [video], QueuePlacement.playNow),
      onLongPress: () => showVideoActions(context, ref, video),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 16, top: 8, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(width: 120, height: 67.5, child: _NetImage(url: video.thumbUrl, icon: Icons.music_note)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: textDirectionFor(title),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (secondary.isNotEmpty)
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: textDirectionFor(secondary),
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            IconButton(
              key: Key('videoMore_${video.videoId}'),
              tooltip: l.moreActions,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: () => showVideoActions(context, ref, video),
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة قناة: صورة دائرية 56 + الاسم.
class ChannelResultRow extends StatelessWidget {
  const ChannelResultRow({super.key, required this.channel, required this.onTap});

  final ChannelSummary channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InkWell(
      key: Key('channel_${channel.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipOval(child: SizedBox(width: 56, height: 56, child: _NetImage(url: channel.thumbUrl, icon: Icons.person))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(channel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: textDirectionFor(channel.title),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(l.channelKind, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  const _NetImage({required this.url, required this.icon});
  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: AppColors.surface,
      child: Center(child: Icon(icon, color: AppColors.textSecondary, size: 20)),
    );
    final u = url;
    if (u == null) return placeholder;
    return Image.network(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
  }
}
