import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../library/generated_cover.dart';
import 'listening_player.dart';
import 'listening_providers.dart';
import 'player_sheets.dart';

/// يحيط بكل الشاشات (من `MaterialApp.builder`): يُظهر المشغّل المصغّر أسفلها ما
/// دامت هناك جلسة استماع (DESIGN §6.2، §10.1)، ويعرض «انتهى الكتاب»، ويفتح
/// المشغّل الكامل عند الضغط على الإشعار.
class ListeningHost extends ConsumerStatefulWidget {
  const ListeningHost({
    super.key,
    required this.navigatorKey,
    required this.router,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<ListeningHost> createState() => _ListeningHostState();
}

class _ListeningHostState extends ConsumerState<ListeningHost> {
  StreamSubscription<ListeningEvent>? _events;
  bool _fullOpen = false;

  @override
  void initState() {
    super.initState();
    _events = ref.read(listeningPlayerProvider).events.listen(_onEvent);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _onEvent(ListeningEvent event) {
    if (!mounted) return;
    switch (event) {
      case ListeningEvent.bookFinished:
        final l10n = AppLocalizations.of(context);
        final screenReader = MediaQuery.accessibleNavigationOf(context);
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.audioBookFinished),
              duration: Duration(seconds: screenReader ? 8 : 4),
            ),
          );
      case ListeningEvent.openPlayer:
        _openFull();
      case ListeningEvent.engineError:
        // يظهر في المشغّل نفسه مع «إعادة المحاولة».
        break;
    }
  }

  Future<void> _openFull() async {
    final navContext = widget.navigatorKey.currentContext;
    if (_fullOpen || navContext == null) return;
    if (!ref.read(listeningStateProvider).active) return;
    _fullOpen = true;
    try {
      await showFullPlayer(navContext, onGoToText: _goToText);
    } finally {
      _fullOpen = false;
    }
  }

  /// «اذهب إلى النص»: إن كان القارئ مفتوحاً على الكتاب نفسه يعود لتتبّع
  /// الفقرة المقروءة، وإلا يُفتح القارئ عليها.
  void _goToText(ListeningState s) {
    final bookId = s.bookId;
    final id = s.paragraphId;
    if (bookId == null || id == null) return;
    final path = widget.router.routerDelegate.currentConfiguration.uri.path;
    if (path == '/read/$bookId') {
      ref.read(followListeningRequestProvider.notifier).request();
    } else {
      widget.router.push(
        Uri(path: '/read/$bookId', queryParameters: {'p': id}).toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(listeningStateProvider);
    // يختفي مع لوحة المفاتيح حتى لا يزاحم حقول الكتابة.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final show = s.active && !keyboard;
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: show,
            child: widget.child,
          ),
        ),
        if (show) MiniPlayer(state: s, onOpen: _openFull),
      ],
    );
  }
}

/// المشغّل المصغّر (DESIGN §10.1): خط تقدّم الباب، الغلاف، الباب والكتاب،
/// تشغيل/إيقاف مؤقت، و✕ «إيقاف الاستماع». خارج الـ Navigator فلا تلميحات
/// (Tooltip)؛ التسميات لقارئ الشاشة عبر semanticLabel.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.state, required this.onOpen});

  final ListeningState state;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final player = ref.read(listeningPlayerProvider);
    final book = state.book!;
    final chapter = state.chapter;
    final preparing = state.status == ListeningStatus.preparing;
    final error = state.status == ListeningStatus.error;

    final Widget playButton;
    if (preparing) {
      playButton = SizedBox.square(
        dimension: 48,
        child: Semantics(
          label: l10n.audioPreparing,
          liveRegion: true,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    } else if (error) {
      playButton = IconButton(
        icon: Icon(Icons.refresh, semanticLabel: l10n.retry),
        onPressed: player.play,
      );
    } else {
      playButton = IconButton(
        icon: Icon(
          state.playing ? Icons.pause : Icons.play_arrow,
          semanticLabel: state.playing ? l10n.audioPause : l10n.audioPlay,
        ),
        onPressed: player.togglePlay,
      );
    }

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: LinearProgressIndicator(
                value: state.chapterProgress,
                minHeight: 2,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 62),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onVerticalDragEnd: (d) {
                        if ((d.primaryVelocity ?? 0) < -200) onOpen();
                      },
                      child: InkWell(
                        onTap: onOpen,
                        child: Semantics(
                          button: true,
                          hint: l10n.audioOpenPlayer,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              12,
                              8,
                              8,
                              8,
                            ),
                            child: Row(
                              children: [
                                GeneratedCover(
                                  bookId: book.id,
                                  title: book.title.ar,
                                  width: 30,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        error
                                            ? l10n.audioEngineError
                                            : chapter?.title ?? book.title.ar,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              color: error
                                                  ? theme.colorScheme.error
                                                  : null,
                                            ),
                                      ),
                                      Text(
                                        book.title.ar,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  playButton,
                  IconButton(
                    icon: Icon(Icons.close, semanticLabel: l10n.audioStop),
                    onPressed: player.stop,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
