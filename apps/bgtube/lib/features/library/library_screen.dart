import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/models/library_entries.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/models/youtube_content.dart';
import '../../domain/ports/auth_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../browse/paged_list_view.dart';
import '../browse/paged_loader.dart';
import '../browse/video_result_row.dart';
import '../channel/channel_screen.dart';
import '../local_playlists/local_playlists_screen.dart';
import '../local_playlists/playlist_dialogs.dart';
import '../login/auth_status_provider.dart';
import '../login/login_screen.dart';
import '../queue/queue_ui.dart';
import 'whole_list.dart';
import 'youtube_playlist_screen.dart';

/// أقسام المكتبة بترتيب الشرائح (DESIGN §2).
enum LibrarySection { local, playlists, likes, subscriptions, favorites, history }

/// أقسام الحساب (تحتاج دخولاً وتُمسح عند الخروج).
bool _isAccount(LibrarySection s) =>
    s == LibrarySection.playlists || s == LibrarySection.likes || s == LibrarySection.subscriptions;

/// المكتبة (الميزة 5): شرائح قابلة للتمرير وتحتها محتوى القسم. أقسام الحساب
/// تُجلب عند أول فتح فقط ثم بالسحب للتحديث (لا تحديث تلقائي، D9)، وتُغلق عند
/// تغيّر الحساب. المفضلة والسجل محليان ويعملان دون دخول (D5/D30).
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibrarySection _section = LibrarySection.local;

  PagedLoader<PlaylistSummary>? _playlists;
  PagedLoader<VideoRef>? _likes;
  PagedLoader<ChannelSummary>? _subscriptions;

  void _dropLoaders() {
    _playlists?.dispose();
    _likes?.dispose();
    _subscriptions?.dispose();
    _playlists = null;
    _likes = null;
    _subscriptions = null;
  }

  @override
  void dispose() {
    _dropLoaders();
    super.dispose();
  }

  PagedLoader<PlaylistSummary> get _playlistsLoader => _playlists ??= PagedLoader<PlaylistSummary>(
        (token, refresh) => ref.read(youTubeApiProvider).myPlaylists(pageToken: token, refresh: refresh),
      )..load();

  PagedLoader<VideoRef> get _likesLoader => _likes ??= PagedLoader<VideoRef>(
        (token, refresh) => ref.read(youTubeApiProvider).likedVideos(pageToken: token, refresh: refresh),
      )..load();

  PagedLoader<ChannelSummary> get _subscriptionsLoader => _subscriptions ??= PagedLoader<ChannelSummary>(
        (token, refresh) => ref.read(youTubeApiProvider).mySubscriptions(pageToken: token, refresh: refresh),
      )..load();

  String _label(AppLocalizations l, LibrarySection s) => switch (s) {
        LibrarySection.local => l.localPlaylists,
        LibrarySection.playlists => l.libraryYouTubePlaylists,
        LibrarySection.likes => l.libraryLikes,
        LibrarySection.subscriptions => l.librarySubscriptions,
        LibrarySection.favorites => l.libraryFavorites,
        LibrarySection.history => l.libraryHistory,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // تغيّر الحساب (خروج أو دخول بحساب آخر): لا يبقى شيء من الحساب السابق ظاهراً.
    ref.listen<AuthStatus>(authStatusProvider, (prev, next) {
      if (prev != next) setState(_dropLoaders);
    });
    final status = ref.watch(authStatusProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navLibrary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: SizedBox(
            height: 56,
            child: SingleChildScrollView(
              key: const Key('libraryChips'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  for (final s in LibrarySection.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        key: Key('libraryChip_${s.name}'),
                        label: Text(_label(l, s)),
                        selected: _section == s,
                        shape: const StadiumBorder(),
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _section = s),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isAccount(_section) && status != AuthStatus.signedIn
          ? _SignInCard(expired: status == AuthStatus.expired)
          : switch (_section) {
              LibrarySection.local => const LocalPlaylistsView(),
              LibrarySection.playlists => _PlaylistsSection(loader: _playlistsLoader),
              LibrarySection.likes => _LikesSection(loader: _likesLoader),
              LibrarySection.subscriptions => _SubscriptionsSection(loader: _subscriptionsLoader),
              LibrarySection.favorites => const _FavoritesSection(),
              LibrarySection.history => const _HistorySection(),
            },
    );
  }
}

/// أقسام الحساب لغير المسجّل: «سجّل الدخول لعرض حسابك» وزر الدخول.
class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.expired});
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyListView(
      key: const Key('librarySignIn'),
      icon: Icons.account_circle_outlined,
      message: expired ? l.sessionExpired : l.errorNotSignedIn,
      action: FilledButton(
        key: const Key('librarySignInButton'),
        onPressed: () => openLoginScreen(context),
        child: Text(l.signIn),
      ),
    );
  }
}

class _PlaylistsSection extends StatelessWidget {
  const _PlaylistsSection({required this.loader});
  final PagedLoader<PlaylistSummary> loader;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PagedListView<PlaylistSummary>(
      key: const Key('libraryPlaylists'),
      loader: loader,
      onRefresh: () => loader.load(refresh: true),
      signedOutMessage: l.errorNotSignedIn,
      empty: EmptyListView(icon: Icons.playlist_play, message: l.libraryEmpty),
      itemBuilder: (context, p) => YouTubePlaylistRow(
        playlist: p,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => YouTubePlaylistScreen(playlist: p),
        )),
      ),
    );
  }
}

class _LikesSection extends ConsumerWidget {
  const _LikesSection({required this.loader});
  final PagedLoader<VideoRef> loader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final api = ref.read(youTubeApiProvider);
    return Column(
      children: [
        Expanded(
          child: PagedListView<VideoRef>(
            key: const Key('libraryLikes'),
            loader: loader,
            onRefresh: () => loader.load(refresh: true),
            signedOutMessage: l.errorNotSignedIn,
            empty: EmptyListView(icon: Icons.thumb_up_outlined, message: l.libraryEmpty),
            itemBuilder: (context, v) => VideoResultRow(video: v),
          ),
        ),
        ListenableBuilder(
          listenable: loader,
          builder: (context, _) => loader.items.isEmpty
              ? const SizedBox.shrink()
              : PlayAllBar(
                  queue: ref.read(playbackQueueProvider),
                  fetch: (token) => api.likedVideos(pageToken: token),
                  cancelOn: ref.read(authServiceProvider).statusChanges,
                ),
        ),
      ],
    );
  }
}

class _SubscriptionsSection extends StatelessWidget {
  const _SubscriptionsSection({required this.loader});
  final PagedLoader<ChannelSummary> loader;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PagedListView<ChannelSummary>(
      key: const Key('librarySubscriptions'),
      loader: loader,
      onRefresh: () => loader.load(refresh: true),
      signedOutMessage: l.errorNotSignedIn,
      empty: EmptyListView(icon: Icons.subscriptions_outlined, message: l.libraryEmpty),
      itemBuilder: (context, c) => ChannelResultRow(
        channel: c,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChannelScreen(channel: c),
        )),
      ),
    );
  }
}

/// قائمة مقاطع محلية (المفضلة أو السجل) مع «تشغيل الكل» في الأسفل.
class _LocalVideoList extends ConsumerWidget {
  const _LocalVideoList({
    super.key,
    required this.items,
    required this.empty,
    required this.rowBuilder,
    this.header,
  });

  final List<VideoRef> items;
  final Widget empty;
  final Widget Function(BuildContext, int) rowBuilder;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return empty;
    final h = header;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: items.length + (h == null ? 0 : 1),
            itemBuilder: (context, i) => h == null ? rowBuilder(context, i) : (i == 0 ? h : rowBuilder(context, i - 1)),
          ),
        ),
        PlayAllBar(queue: ref.read(playbackQueueProvider), fetch: localList(items)),
      ],
    );
  }
}

class _LocalError extends StatelessWidget {
  const _LocalError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyListView(
      icon: Icons.error_outline,
      message: l.libraryLocalLoadError,
      action: FilledButton(onPressed: onRetry, child: Text(l.retry)),
    );
  }
}

class _FavoritesSection extends ConsumerStatefulWidget {
  const _FavoritesSection();

  @override
  ConsumerState<_FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends ConsumerState<_FavoritesSection> {
  late Stream<List<VideoRef>> _stream = ref.read(favoritesRepositoryProvider).watchAll();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<VideoRef>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _LocalError(onRetry: () => setState(() => _stream = ref.read(favoritesRepositoryProvider).watchAll()));
        }
        final items = snap.data;
        if (items == null) return const SkeletonList();
        return _LocalVideoList(
          key: const Key('libraryFavorites'),
          items: items,
          empty: EmptyListView(icon: Icons.star_border, message: l.favoritesEmpty),
          rowBuilder: (context, i) => VideoResultRow(video: items[i]),
        );
      },
    );
  }
}

class _HistorySection extends ConsumerStatefulWidget {
  const _HistorySection();

  @override
  ConsumerState<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<_HistorySection> {
  late Stream<List<HistoryEntry>> _stream = ref.read(historyRepositoryProvider).watchAll();

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(context,
        title: l.clearHistoryConfirmTitle, body: l.clearHistoryConfirmBody, action: l.clearHistoryAction);
    if (!ok) return;
    try {
      await ref.read(historyRepositoryProvider).clear();
      showUndoSnack(messenger, l, l.historyCleared);
    } catch (_) {
      showUndoSnack(messenger, l, l.saveFailed);
    }
  }

  Future<void> _remove(HistoryEntry e) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(historyRepositoryProvider).remove(e.id);
      showUndoSnack(messenger, l, l.removedFromHistory);
    } catch (_) {
      showUndoSnack(messenger, l, l.saveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<HistoryEntry>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _LocalError(onRetry: () => setState(() => _stream = ref.read(historyRepositoryProvider).watchAll()));
        }
        final entries = snap.data;
        if (entries == null) return const SkeletonList();
        return _LocalVideoList(
          key: const Key('libraryHistory'),
          items: [for (final e in entries) e.ref],
          empty: EmptyListView(icon: Icons.history, message: l.historyEmpty),
          header: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: TextButton.icon(
                key: const Key('clearHistory'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error, minimumSize: const Size(48, 48)),
                onPressed: _clear,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(l.clearHistory),
              ),
            ),
          ),
          rowBuilder: (context, i) => VideoResultRow(
            key: Key('history_${entries[i].id}'),
            video: entries[i].ref,
            extraActions: [
              SheetAction(
                key: const Key('videoAction_removeFromHistory'),
                icon: Icons.delete_outline,
                label: l.removeFromHistory,
                color: AppColors.error,
                onTap: () => _remove(entries[i]),
              ),
            ],
          ),
        );
      },
    );
  }
}
