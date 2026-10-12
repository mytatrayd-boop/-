import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/book_actions.dart';
import '../library/library_controller.dart';
import '../library/library_text.dart';
import '../search/highlighted_text.dart';
import '../search/search_screen.dart';
import '../storage/reading_repository.dart';
import '../text/search_query.dart';
import 'chapter_tile.dart';
import 'display_settings_sheet.dart';
import 'passage_share.dart';
import 'reader_book.dart';
import 'reader_providers.dart';
import 'reader_settings.dart';

/// القارئ (DESIGN §9): تمرير عمودي متصل، نص أميري RTL، حفظ الموضع تلقائياً.
///
/// يُفتح على [paragraphId] (من المفضلة أو البحث أو الاقتباس)، أو على أول باب
/// [chapterId]، أو على آخر موضع محفوظ، أو على أول الكتاب. [searchQuery] (من
/// نتيجة بحث) تُظلَّل كلماته في الفقرة المفتوحة حتى مغادرة القارئ (DESIGN §9.4).
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    this.paragraphId,
    this.chapterId,
    this.searchQuery,
  });

  final String bookId;
  final String? paragraphId;
  final String? chapterId;
  final String? searchQuery;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

enum _OpenNotice { none, resumed, notFound }

enum _ParagraphAction { favorite, copy, share }

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scroll = ScrollController(keepScrollOffset: false);
  final _centerKey = GlobalKey(debugLabel: 'reader-center');
  final _viewportKey = GlobalKey(debugLabel: 'reader-viewport');

  /// المدخلات المبنية حالياً (المرئية وما في ذاكرة التمرير) ومواقعها.
  final _built = <int, BuildContext>{};

  late final ReadingActions _actions = ref.read(readingActionsProvider);
  late final AppLifecycleListener _lifecycle;

  ReaderBook? _book;

  /// المدخل الموضوع أعلى منطقة القراءة عند الفتح أو القفز.
  int? _anchor;

  /// الفقرة الحالية (أعلى ما يظهر) وبابها.
  int _paragraph = 0;
  int _chapter = 0;

  /// آخر معرّف حُفظ فعلاً، والمعرّف الذي تجري كتابته الآن. لا يُعتبر المعرّف
  /// محفوظاً إلا بعد نجاح الكتابة، فيُعاد الحفظ عند الإخفاء أو الخروج.
  String? _savedId;
  String? _savingId;

  bool _barsVisible = true;
  Timer? _hideTimer;

  /// الفقرة المفتوحة من رابط: تُظلَّل ثانيتين (DESIGN §9.4).
  String? _flashId;
  Timer? _flashTimer;

  /// الفقرة المختارة بالضغط المطوّل أثناء عرض ورقتها.
  String? _selectedId;

  /// كلمات البحث والفقرة التي تُظلَّل فيها.
  late final SearchQuery? _search = _parseSearch(widget.searchQuery);

  static SearchQuery? _parseSearch(String? raw) {
    final q = raw == null ? null : SearchQuery.parse(raw);
    return q == null || q.isEmpty ? null : q;
  }
  String? _searchId;

  int _openGeneration = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: _savePosition,
      onPause: _savePosition,
    );
    ref.listenManual(readerBookProvider(widget.bookId), (previous, next) {
      if (next case AsyncData(:final value?)) _open(value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _savePosition();
    _lifecycle.dispose();
    _hideTimer?.cancel();
    _flashTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  late final ReadingRepository _repo = ref.read(readingRepositoryProvider);

  /// يحدد موضع الفتح ثم يعرض الكتاب. عند إعادة تحميل الكتاب (تحديثه) يبقى
  /// على الفقرة الحالية.
  Future<void> _open(ReaderBook book) async {
    final generation = ++_openGeneration;
    final previous = _book;
    var notice = _OpenNotice.none;
    String? flash;
    var searchId = _searchId;
    int entry = 0;

    int? paragraphIndex(String id) => book.paragraphIndexOf(id);

    Future<int?> resolve(String id) async {
      final direct = paragraphIndex(id);
      if (direct != null) return direct;
      final redirected = await _repo.resolveParagraph(id);
      return paragraphIndex(redirected);
    }

    if (previous != null && previous.paragraphs.isNotEmpty) {
      final current = previous
          .paragraphs[_paragraph.clamp(0, previous.paragraphs.length - 1)]
          .id;
      final index = await resolve(current);
      entry = index == null ? 0 : book.entryOfParagraph(index);
    } else if (widget.paragraphId case final id?) {
      final index = await resolve(id);
      if (index != null) {
        entry = book.entryOfParagraph(index);
        flash = book.paragraphs[index].id;
        if (_search != null) searchId = flash;
      } else {
        notice = _OpenNotice.notFound;
        final chapterId = ReaderBook.chapterIdOfParagraphId(id);
        final chapter = chapterId == null
            ? null
            : book.chapterIndexOf(chapterId);
        entry = chapter == null ? 0 : book.entryOfChapter(chapter);
      }
    } else if (widget.chapterId case final id?) {
      final chapter = book.chapterIndexOf(id);
      entry = chapter == null ? 0 : book.entryOfChapter(chapter);
    } else {
      final saved = await _repo.position(widget.bookId);
      final index = saved == null ? null : await resolve(saved.paragraphId);
      if (index != null && index > 0) {
        entry = book.entryOfParagraph(index);
        notice = _OpenNotice.resumed;
      }
    }
    if (!mounted || generation != _openGeneration) return;
    _setFlash(flash);
    setState(() {
      _searchId = searchId;
      _book = book;
      _anchor = entry.clamp(0, book.entryCount == 0 ? 0 : book.entryCount - 1);
      _setCurrentFromEntry(_anchor!);
    });
    _savePosition();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    switch (notice) {
      case _OpenNotice.resumed:
        _showSnack(
          AppLocalizations.of(context).resumedHere,
          actionLabel: AppLocalizations.of(context).fromStart,
          onAction: () => _jumpToEntry(0),
        );
      case _OpenNotice.notFound:
        _showSnack(AppLocalizations.of(context).paragraphNotFound);
      case _OpenNotice.none:
        break;
    }
  }

  void _setCurrentFromEntry(int entry) {
    final book = _book;
    if (book == null || book.entryCount == 0) return;
    _chapter = book.chapterOfEntry(entry);
    _paragraph = book.paragraphAtOrAfterEntry(entry) ?? 0;
  }

  void _savePosition() {
    final book = _book;
    if (book == null || book.paragraphs.isEmpty) return;
    final id =
        book.paragraphs[_paragraph.clamp(0, book.paragraphs.length - 1)].id;
    if (id == _savedId || id == _savingId) return;
    _savingId = id;
    unawaited(
      _actions
          .savePosition(book.id, id)
          .then<void>((_) => _savedId = id, onError: (Object _) {})
          .whenComplete(() {
            if (_savingId == id) _savingId = null;
          }),
    );
  }

  void _setFlash(String? id) {
    _flashTimer?.cancel();
    _flashId = id;
    if (id == null) return;
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduceMotion) return;
    _flashTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  void _jumpToEntry(int entry) {
    final book = _book;
    if (book == null) return;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() {
      _anchor = entry.clamp(0, book.entryCount - 1);
      _setCurrentFromEntry(_anchor!);
    });
    _savePosition();
  }

  void _showSnack(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final screenReader = MediaQuery.accessibleNavigationOf(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          // ٤ ثوانٍ على الأقل، وتُضاعف مع قارئ الشاشة (DESIGN §16.7).
          duration: Duration(seconds: screenReader ? 8 : 4),
          action: actionLabel == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  onPressed: onAction ?? () {},
                ),
        ),
      );
  }

  double _topInset(BuildContext context) =>
      MediaQuery.paddingOf(context).top + kToolbarHeight;

  /// يحدّث الفقرة والباب الحاليين من المدخلات المبنية: أول مدخل يتجاوز
  /// أسفلُه حدَّ الشريط العلوي.
  void _updateCurrent() {
    final book = _book;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (book == null || viewport == null || !viewport.attached) return;
    final line = _topInset(context) + 1;
    int? best;
    _built.forEach((entry, ctx) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) return;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top + box.size.height > line && (best == null || entry < best!)) {
        best = entry;
      }
    });
    if (best == null) return;
    final chapter = book.chapterOfEntry(best!);
    final paragraph = book.paragraphAtOrAfterEntry(best!) ?? 0;
    if (chapter != _chapter || paragraph != _paragraph) {
      setState(() {
        _chapter = chapter;
        _paragraph = paragraph;
      });
    }
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _barsVisible = false);
      });
    } else if (n is ScrollUpdateNotification) {
      _scheduleUpdate();
    } else if (n is ScrollEndNotification) {
      _scheduleUpdate(save: true);
    }
    return false;
  }

  bool _updateScheduled = false;
  bool _saveAfterUpdate = false;

  /// المواقع تُقرأ بعد التخطيط: الإشعار يصل قبل أن تُرتَّب الفقرات الجديدة.
  void _scheduleUpdate({bool save = false}) {
    _saveAfterUpdate |= save;
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        _updateScheduled = false;
        if (!mounted) return;
        _updateCurrent();
        if (_saveAfterUpdate) {
          _saveAfterUpdate = false;
          _savePosition();
        }
      })
      ..ensureVisualUpdate();
  }

  void _toggleBars() {
    _hideTimer?.cancel();
    setState(() => _barsVisible = !_barsVisible);
  }

  /// يغيّر حالة المفضلة؛ الفشل (مثلاً القاعدة مشغولة) يظهر برسالة عابرة.
  Future<void> _toggleFavorite(ReaderParagraph p, bool isFavorite) async {
    final l10n = AppLocalizations.of(context);
    final createdAt = ref
        .read(favoritesProvider)
        .value
        ?.where((f) => f.paragraphId == p.id)
        .firstOrNull
        ?.createdAt;
    try {
      if (isFavorite) {
        await _actions.removeFavorite(p.id);
      } else {
        await _actions.addFavorite(widget.bookId, p.id);
      }
    } on Exception {
      if (mounted) _showSnack(l10n.saveFailed);
      return;
    }
    if (!mounted) return;
    _showSnack(
      isFavorite ? l10n.removedFromFavorites : l10n.addedToFavorites,
      actionLabel: l10n.undo,
      onAction: () => _undoFavorite(p, isFavorite, createdAt),
    );
  }

  /// «تراجع»: يعيد الفقرة المزالة بتاريخها الأصلي، أو يزيل المضافة.
  Future<void> _undoFavorite(
    ReaderParagraph p,
    bool wasFavorite,
    int? createdAt,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (wasFavorite) {
        await _actions.addFavorite(widget.bookId, p.id, createdAt: createdAt);
      } else {
        await _actions.removeFavorite(p.id);
      }
    } on Exception {
      if (mounted) _showSnack(l10n.saveFailed);
    }
  }

  Future<void> _copy(ReaderParagraph p) async {
    final book = _book;
    if (book == null) return;
    final l10n = AppLocalizations.of(context);
    await copyPassage(passageWithSource(l10n, book, p));
    if (mounted) _showSnack(l10n.textCopied);
  }

  Future<void> _share(ReaderParagraph p) async {
    final book = _book;
    if (book == null) return;
    final text = passageWithSource(AppLocalizations.of(context), book, p);
    await ref.read(shareTextProvider)(text, book.title.ar);
  }

  Future<void> _openParagraphSheet(ReaderParagraph p, bool isFavorite) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _selectedId = p.id);
    final action = await showModalBottomSheet<_ParagraphAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        Widget tile(IconData icon, String label, _ParagraphAction value) =>
            ListTile(
              minTileHeight: 48,
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.of(sheetContext).pop(value),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(
                isFavorite ? Icons.bookmark : Icons.bookmark_border,
                isFavorite ? l10n.removeFromFavorites : l10n.addToFavorites,
                _ParagraphAction.favorite,
              ),
              tile(Icons.copy, l10n.copy, _ParagraphAction.copy),
              tile(Icons.share, l10n.share, _ParagraphAction.share),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    setState(() => _selectedId = null);
    switch (action) {
      case _ParagraphAction.favorite:
        await _toggleFavorite(p, isFavorite);
      case _ParagraphAction.copy:
        await _copy(p);
      case _ParagraphAction.share:
        await _share(p);
      case null:
        break;
    }
  }

  Future<void> _openContents() async {
    final book = _book;
    if (book == null) return;
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, controller) => ListView.builder(
          controller: controller,
          itemCount: book.chapters.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.contents,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              );
            }
            final c = book.chapters[i - 1];
            return ChapterTile(
              number: i,
              total: book.chapters.length,
              title: c.title,
              level: c.level,
              current: i - 1 == _chapter,
              onTap: () => Navigator.of(sheetContext).pop(i - 1),
            );
          },
        ),
      ),
    );
    if (chosen != null && mounted) _jumpToEntry(book.entryOfChapter(chosen));
  }

  Future<void> _openDisplaySettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const DisplaySettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bookAsync = ref.watch(readerBookProvider(widget.bookId));
    final settings = ref.watch(readerSettingsProvider).value;
    final pageTheme = (settings ?? const ReaderSettings()).effectiveTheme(
      Theme.of(context).brightness,
    );
    final palette = ReaderPalette.of(pageTheme);
    final book = _book;

    // كتاب بلا أبواب لا يجتاز المدقق؛ يُعامل كملف تالف إن ظهر.
    if (bookAsync is AsyncError || (book != null && book.entryCount == 0)) {
      return _StatusScaffold(
        palette: palette,
        child: _ReaderMessage(
          message: l10n.bookOpenError,
          bookId: widget.bookId,
          redownload: true,
        ),
      );
    }
    if (bookAsync case AsyncData(value: null)) {
      return _StatusScaffold(
        palette: palette,
        child: _ReaderMessage(
          message: l10n.bookNotInstalledReader,
          bookId: widget.bookId,
          redownload: false,
        ),
      );
    }
    if (book == null || _anchor == null || settings == null) {
      return _StatusScaffold(palette: palette, child: const _ReaderSkeleton());
    }

    final screenReader = MediaQuery.accessibleNavigationOf(context);
    final showBars = _barsVisible || screenReader;
    final fontSize = readerFontSize(
      settings.level,
      MediaQuery.textScalerOf(context),
    );
    final favorites = ref.watch(favoriteIdsProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final anchor = _anchor!;
    final topInset = _topInset(context);
    final chapter = book.chapters.isEmpty ? null : book.chapters[_chapter];

    Widget entry(int index) {
      final child = switch (book.entryAt(index)) {
        HeadingEntry(:final chapterIndex) => _ChapterHeading(
          title: book.chapters[chapterIndex].title,
          fontSize: fontSize,
          palette: palette,
        ),
        ParagraphEntry(:final paragraphIndex) => () {
          final p = book.paragraphs[paragraphIndex];
          final isFavorite = favorites.contains(p.id);
          return _Paragraph(
            paragraph: p,
            fontSize: fontSize,
            palette: palette,
            highlighted: p.id == _selectedId || p.id == _flashId,
            searchQuery: p.id == _searchId ? _search : null,
            animate: !reduceMotion,
            favoriteLabel: isFavorite
                ? l10n.removeFromFavorites
                : l10n.addToFavorites,
            favoriteValue: isFavorite ? l10n.inFavorites : null,
            onToggleFavorite: () => _toggleFavorite(p, isFavorite),
            copyLabel: l10n.copy,
            onCopy: () => _copy(p),
            onLongPress: () => _openParagraphSheet(p, isFavorite),
          );
        }(),
      };
      return _TrackedEntry(
        key: ValueKey(index),
        index: index,
        registry: _built,
        child: child,
      );
    }

    final scrollView = LayoutBuilder(
      builder: (context, constraints) =>
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              key: _viewportKey,
              controller: _scroll,
              center: _centerKey,
              anchor: (topInset / constraints.maxHeight).clamp(0.0, 0.5),
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => entry(anchor - 1 - i),
                    childCount: anchor,
                  ),
                ),
                SliverList(
                  key: _centerKey,
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => entry(anchor + i),
                    childCount: book.entryCount - anchor,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 160 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
    );

    final lang = Localizations.localeOf(context).languageCode;
    final fraction = book.progressAt(_paragraph);
    final progressText = l10n.readerProgress(
      formatInt(_chapter + 1, lang),
      formatInt(book.chapters.length, lang),
      formatInt(percentOf(fraction), lang),
    );

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: screenReader ? null : _toggleBars,
              child: scrollView,
            ),
          ),
          if (showBars) ...[
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: _TopBar(
                palette: palette,
                title: chapter == null
                    ? book.title.ar
                    : l10n.breadcrumb(book.title.ar, chapter.title),
                onContents: _openContents,
                onSearch: () =>
                    context.push(searchLocation(bookId: widget.bookId)),
                onDisplay: _openDisplaySettings,
              ),
            ),
            PositionedDirectional(
              bottom: 0,
              start: 0,
              end: 0,
              child: _BottomBar(
                palette: palette,
                fraction: fraction,
                text: progressText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// يسجّل سياق المدخل ما دام مبنياً، لحساب الفقرة الظاهرة أعلى الشاشة.
class _TrackedEntry extends StatefulWidget {
  const _TrackedEntry({
    super.key,
    required this.index,
    required this.registry,
    required this.child,
  });

  final int index;
  final Map<int, BuildContext> registry;
  final Widget child;

  @override
  State<_TrackedEntry> createState() => _TrackedEntryState();
}

class _TrackedEntryState extends State<_TrackedEntry> {
  @override
  void initState() {
    super.initState();
    widget.registry[widget.index] = context;
  }

  @override
  void didUpdateWidget(_TrackedEntry old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index || old.registry != widget.registry) {
      if (old.registry[old.index] == context) old.registry.remove(old.index);
      widget.registry[widget.index] = context;
    }
  }

  @override
  void dispose() {
    if (widget.registry[widget.index] == context) {
      widget.registry.remove(widget.index);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ChapterHeading extends StatelessWidget {
  const _ChapterHeading({
    required this.title,
    required this.fontSize,
    required this.palette,
  });

  final String title;
  final double fontSize;
  final ReaderPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 8),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: bookFont,
                fontSize: math.min(fontSize * 1.3, maxReaderFontSize),
                height: 1.8,
                color: palette.rubric,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // فاصل زخرفي ذهبي صغير (لا يحمل معلومة).
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 1,
                  color: AdeebColors.goldOrnament,
                ),
                const Padding(
                  padding: EdgeInsetsDirectional.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.star_border,
                    size: 14,
                    color: AdeebColors.goldOrnament,
                  ),
                ),
                Container(
                  width: 40,
                  height: 1,
                  color: AdeebColors.goldOrnament,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({
    required this.paragraph,
    required this.fontSize,
    required this.palette,
    required this.highlighted,
    required this.searchQuery,
    required this.animate,
    required this.favoriteLabel,
    required this.favoriteValue,
    required this.onToggleFavorite,
    required this.copyLabel,
    required this.onCopy,
    required this.onLongPress,
  });

  final ReaderParagraph paragraph;
  final double fontSize;
  final ReaderPalette palette;
  final bool highlighted;

  /// كلمات البحث المظلّلة في هذه الفقرة (null = بلا تظليل).
  final SearchQuery? searchQuery;
  final bool animate;
  final String favoriteLabel;
  final String? favoriteValue;
  final VoidCallback onToggleFavorite;
  final String copyLabel;
  final VoidCallback onCopy;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: bookFont,
      fontSize: fontSize,
      height: 2.0,
      color: palette.text,
    );
    final query = searchQuery;
    Text text(String s) => query == null
        ? Text(
            s,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.start,
            textScaler: TextScaler.noScaling,
            style: style,
          )
        : Text.rich(
            TextSpan(
              children: highlightedSpans(
                s,
                findMatches(s, query),
                palette.searchHighlight,
              ),
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.start,
            textScaler: TextScaler.noScaling,
            style: style,
          );

    final Widget content;
    if (paragraph.isVerse) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in paragraph.text.split('\n'))
            Wrap(
              textDirection: TextDirection.rtl,
              alignment: WrapAlignment.center,
              spacing: 32,
              children: [for (final half in line.split('\t')) text(half)],
            ),
        ],
      );
    } else {
      content = text(paragraph.text);
    }

    // كل فقرة عنصر واحد لقارئ الشاشة، والمفضلة إجراء مخصص (DESIGN §9.6).
    return MergeSemantics(
      child: Semantics(
        value: favoriteValue,
        customSemanticsActions: {
          CustomSemanticsAction(label: favoriteLabel): onToggleFavorite,
          CustomSemanticsAction(label: copyLabel): onCopy,
        },
        child: GestureDetector(
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: animate
                ? const Duration(milliseconds: 250)
                : Duration.zero,
            color: highlighted
                ? palette.selected
                : palette.background.withValues(alpha: 0),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.palette,
    required this.title,
    required this.onContents,
    required this.onSearch,
    required this.onDisplay,
  });

  final ReaderPalette palette;
  final String title;
  final VoidCallback onContents;
  final VoidCallback onSearch;
  final VoidCallback onDisplay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: palette.bars,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: IconTheme.merge(
            data: IconThemeData(color: palette.text),
            child: Row(
              children: [
                BackButton(color: palette.text),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: palette.text),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.contents,
                  icon: const Icon(Icons.toc),
                  onPressed: onContents,
                ),
                IconButton(
                  tooltip: l10n.searchInBook,
                  icon: const Icon(Icons.search),
                  onPressed: onSearch,
                ),
                IconButton(
                  tooltip: l10n.displaySettings,
                  icon: const Icon(Icons.text_fields),
                  onPressed: onDisplay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.palette,
    required this.fraction,
    required this.text,
  });

  final ReaderPalette palette;
  final double fraction;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.bars,
      elevation: 1,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: fraction,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: palette.background,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: palette.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({required this.palette, required this.child});
  final ReaderPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: palette.background,
    appBar: AppBar(
      backgroundColor: palette.bars,
      foregroundColor: palette.text,
    ),
    body: SafeArea(child: child),
  );
}

/// هيكل مؤقت لستة أسطر أثناء فتح الكتاب (DESIGN §9.5).
class _ReaderSkeleton extends StatelessWidget {
  const _ReaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final block = context.extraColors.surfaceAlt;
    return Semantics(
      label: AppLocalizations.of(context).loading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in const [0.9, 1.0, 0.8, 0.95, 0.7, 0.85])
                FractionallySizedBox(
                  widthFactor: f,
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    height: 16,
                    margin: const EdgeInsetsDirectional.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// الكتاب غير محمّل أو تعذّر فتحه: الرسالة وزر التحميل (DESIGN §9.5).
class _ReaderMessage extends ConsumerWidget {
  const _ReaderMessage({
    required this.message,
    required this.bookId,
    required this.redownload,
  });

  final String message;
  final String bookId;
  final bool redownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(libraryControllerProvider);
    final item = state.item(bookId);
    final task = state.tasks[bookId];
    final canDownload =
        !state.isOffline && item?.entry != null && task is! DownloadingTask;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: redownload ? theme.colorScheme.error : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (task case DownloadingTask(:final fraction)) ...[
              LinearProgressIndicator(value: fraction),
              const SizedBox(height: 4),
              Text(
                l10n.percent(context, fraction),
                textAlign: TextAlign.center,
              ),
            ] else if (task is PreparingTask) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(l10n.preparing, textAlign: TextAlign.center),
            ] else ...[
              FilledButton(
                onPressed: canDownload
                    ? () => startDownload(context, ref, bookId)
                    : null,
                child: Text(
                  redownload
                      ? l10n.redownload
                      : item == null
                      ? l10n.download
                      : l10n.downloadWithSize(
                          l10n.size(context, item.displaySize),
                        ),
                ),
              ),
              if (!canDownload) ...[
                const SizedBox(height: 4),
                Text(l10n.needsConnection, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.cancel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
