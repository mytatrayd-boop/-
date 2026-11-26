import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/models/youtube_content.dart';
import '../../domain/ports/auth_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../browse/paged_list_view.dart';
import '../browse/paged_loader.dart';
import '../browse/video_result_row.dart';
import '../login/auth_status_provider.dart';
import '../player/text_direction.dart';
import '../queue/queue_ui.dart';
import 'whole_list.dart';

/// مقاطع قائمة يوتيوب (`playlistItems`، وحدة لكل 50 من الوعاء العام، فالتحميل
/// عند بلوغ الآخر مسموح)، و«تشغيل الكل» و«أضف القائمة كلها» (D30).
class YouTubePlaylistScreen extends ConsumerStatefulWidget {
  const YouTubePlaylistScreen({super.key, required this.playlist});
  final PlaylistSummary playlist;

  @override
  ConsumerState<YouTubePlaylistScreen> createState() => _YouTubePlaylistScreenState();
}

class _YouTubePlaylistScreenState extends ConsumerState<YouTubePlaylistScreen> {
  late final PagedLoader<VideoRef> _loader;
  late final ListPageFetcher _fetch;

  @override
  void initState() {
    super.initState();
    final api = ref.read(youTubeApiProvider);
    final id = widget.playlist.id;
    _fetch = (token) => api.playlistVideos(id, pageToken: token);
    _loader = PagedLoader<VideoRef>((token, refresh) => api.playlistVideos(id, pageToken: token, refresh: refresh))
      ..load();
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = widget.playlist.title;
    // خروج أو انتهاء الجلسة أو حساب آخر: تُغلق القائمة فلا تبقى بيانات الحساب ظاهرة.
    ref.listen<AuthStatus>(authStatusProvider, (prev, next) {
      if (prev != next && mounted) Navigator.of(context).maybePop();
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: textDirectionFor(title)),
      ),
      body: PagedListView<VideoRef>(
        loader: _loader,
        onRefresh: () => _loader.load(refresh: true),
        signedOutMessage: l.errorNotSignedIn,
        empty: EmptyListView(icon: Icons.playlist_play, message: l.libraryEmpty),
        itemBuilder: (context, v) => VideoResultRow(video: v),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _loader,
        builder: (context, _) => _loader.items.isEmpty
            ? const SizedBox.shrink()
            : PlayAllBar(
                queue: ref.read(playbackQueueProvider),
                fetch: _fetch,
                total: widget.playlist.itemCount,
                cancelOn: ref.read(authServiceProvider).statusChanges,
              ),
      ),
    );
  }
}

/// صف قائمة يوتيوب: صورة 16:9 بعرض 88، الاسم، وعدد المقاطع، و⋮ «أضف القائمة كلها».
class YouTubePlaylistRow extends ConsumerWidget {
  const YouTubePlaylistRow({super.key, required this.playlist, required this.onTap});
  final PlaylistSummary playlist;
  final VoidCallback onTap;

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final placement = await showPlacementSheet(context, includePlayNow: false, title: playlist.title);
    if (placement == null || !context.mounted) return;
    final api = ref.read(youTubeApiProvider);
    await enqueueWholeList(
      context,
      ref.read(playbackQueueProvider),
      (token) => api.playlistVideos(playlist.id, pageToken: token),
      placement,
      total: playlist.itemCount,
      cancelOn: ref.read(authServiceProvider).statusChanges,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = playlist.itemCount;
    final thumb = playlist.thumbUrl;
    const placeholder = ColoredBox(
      color: AppColors.surface,
      child: Center(child: Icon(Icons.playlist_play, color: AppColors.textSecondary)),
    );
    return InkWell(
      key: Key('ytPlaylist_${playlist.id}'),
      onTap: onTap,
      onLongPress: () => _menu(context, ref),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 16, top: 6, bottom: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 88,
                  height: 49.5,
                  child: thumb == null
                      ? placeholder
                      : Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(playlist.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: textDirectionFor(playlist.title),
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (count != null) Text(l.itemsCount(count), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                key: Key('ytPlaylistMenu_${playlist.id}'),
                tooltip: l.addWholeList,
                constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                onPressed: () => _menu(context, ref),
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
