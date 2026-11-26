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
import '../channel/channel_screen.dart';
import '../login/auth_status_provider.dart';
import '../login/login_screen.dart';
import 'link_intake.dart';

/// الرئيسية/البحث (DESIGN §1، D29). المسجّل يرى «أحدث فيديوهات اشتراكاتك»،
/// وغير المسجّل دعوة للدخول. حقل البحث (يقبل رابطاً أيضاً) وزر اللصق في الأسفل.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _text = TextEditingController();
  String? _query;
  PagedLoader<SearchResult>? _search;
  PagedLoader<VideoRef>? _feed;

  @override
  void dispose() {
    _text.dispose();
    _search?.dispose();
    _feed?.dispose();
    super.dispose();
  }

  /// الرئيسية تُجلب مرة عند ظهورها مسجّلاً، ثم بالسحب للتحديث فقط.
  PagedLoader<VideoRef>? _feedFor(AuthStatus status) {
    if (status != AuthStatus.signedIn) {
      final old = _feed;
      _feed = null;
      if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      return null;
    }
    return _feed ??= PagedLoader<VideoRef>(
      (_, refresh) => ref.read(youTubeApiProvider).subscriptionFeed(refresh: refresh),
    )..load();
  }

  void _submit(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    if (looksLikeLink(t)) {
      submitLink(context, ref, t);
      return;
    }
    FocusScope.of(context).unfocus();
    final api = ref.read(youTubeApiProvider);
    _search?.dispose();
    setState(() {
      _query = t;
      // البحث من وعاء مستقل (100 طلب يومياً): عند الإدخال فقط، بلا سحب للتحديث.
      _search = PagedLoader<SearchResult>((token, _) => api.search(t, pageToken: token))..load();
    });
  }

  void _closeSearch() {
    _search?.dispose();
    _text.clear();
    setState(() {
      _search = null;
      _query = null;
    });
  }

  void _paste() => pasteLink(context, ref);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // الخروج يغلق البحث المعروض (نتائج الحساب السابق)، خارج البناء.
    ref.listen<AuthStatus>(authStatusProvider, (prev, next) {
      if (next == AuthStatus.signedOut && _search != null) _closeSearch();
    });
    final status = ref.watch(authStatusProvider);
    final feed = _feedFor(status);
    final search = _search;
    final query = _query;

    final Widget content;
    if (search != null && query != null) {
      content = PagedListView<SearchResult>(
        key: ValueKey('search_$query'),
        loader: search,
        onPaste: _paste,
        // كل صفحة بحث طلب من وعاء الـ100: بزر صريح لا بالتمرير.
        autoLoadMore: false,
        header: _SearchHeader(query: query, onClose: _closeSearch),
        empty: EmptyListView(icon: Icons.search_off, message: l.searchNoResults(query)),
        itemBuilder: (context, r) => switch (r) {
          VideoResult(:final video) => VideoResultRow(video: video),
          ChannelResult(:final channel) => ChannelResultRow(
              channel: channel,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => ChannelScreen(channel: channel))),
            ),
        },
      );
    } else if (feed != null) {
      content = PagedListView<VideoRef>(
        key: const Key('feed'),
        loader: feed,
        onPaste: _paste,
        onRefresh: () => feed.load(refresh: true),
        header: _SectionTitle(l.feedTitle),
        empty: EmptyListView(icon: Icons.subscriptions_outlined, message: l.feedEmpty),
        itemBuilder: (context, v) => VideoResultRow(video: v),
      );
    } else {
      content = EmptyListView(
        key: const Key('guestHome'),
        icon: Icons.search,
        message: status == AuthStatus.expired ? l.sessionExpired : '${l.homeStartHint}\n${l.guestSignInPrompt}',
        action: FilledButton(
          key: const Key('homeSignIn'),
          onPressed: () => openLoginScreen(context),
          child: Text(l.signIn),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle), backgroundColor: AppColors.background),
      body: Column(
        children: [
          Expanded(child: content),
          // الثلث السفلي: بمتناول الإبهام فوق المشغّل المصغّر والشريط السفلي.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('searchField'),
                    controller: _text,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l.searchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: _submit,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const Key('pasteButton'),
                  tooltip: l.pasteAndPlay,
                  constraints: const BoxConstraints.tightFor(width: 48, height: 48),
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(text, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.query, required this.onClose});
  final String query;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = l.searchResultsFor(query);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            key: const Key('closeSearch'),
            tooltip: l.closeSearch,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
