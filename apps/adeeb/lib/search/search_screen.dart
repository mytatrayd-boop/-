import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../storage/book_repository.dart';
import '../storage/search_repository.dart';
import '../text/search_query.dart';
import 'highlighted_text.dart';
import 'search_providers.dart';

/// مسار شاشة البحث؛ [bookId] يختار نطاق كتاب واحد.
String searchLocation({String? bookId}) => Uri(
  path: '/search',
  queryParameters: bookId == null ? null : {'book': bookId},
).toString();

/// مسار القارئ على فقرة نتيجة مع كلمات البحث لتظليلها.
String searchResultLocation(SearchHit hit, String query) => Uri(
  path: '/read/${hit.bookId}',
  queryParameters: {'p': hit.paragraphId, 'q': query},
).toString();

/// شاشة البحث المحلي (DESIGN §11): كل الكتب المحمّلة أو كتاب واحد، دون إنترنت.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialBookId});

  /// عند الدخول من كتاب يُختار نطاقه تلقائياً.
  final String? initialBookId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

/// التأخير بعد التوقف عن الكتابة (DESIGN §11.1).
const searchDebounce = Duration(milliseconds: 300);
const searchPageSize = 50;

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  int _generation = 0;

  late String? _scope = widget.initialBookId;

  /// آخر استعلام نُفِّذ ونتيجته.
  SearchQuery? _query;
  String? _scopeOfResults;
  List<SearchHit> _hits = const [];
  List<BookHitCount> _counts = const [];
  bool _loading = false;
  bool _failed = false;
  final _collapsed = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  /// النطاق الفعلي: كتاب محمّل، وإلا كل الكتب.
  String? _effectiveScope(List<InstalledBook>? books) {
    final scope = _scope;
    if (scope == null || books == null) return scope;
    return books.any((b) => b.id == scope) ? scope : null;
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final q = SearchQuery.parse(text);
    if (!q.isSearchable) {
      _generation++;
      setState(_clearResults);
      return;
    }
    setState(() {});
    _debounce = Timer(searchDebounce, _search);
  }

  void _clearResults() {
    _query = null;
    _hits = const [];
    _counts = const [];
    _loading = false;
    _failed = false;
    _collapsed.clear();
  }

  void _submit() {
    _debounce?.cancel();
    _search();
  }

  void _useSuggestion(String word) {
    _field.text = word;
    _field.selection = TextSelection.collapsed(offset: word.length);
    _submit();
  }

  void _setScope(String? bookId) {
    setState(() => _scope = bookId);
    _debounce?.cancel();
    if (SearchQuery.parse(_field.text).isSearchable) _search();
  }

  Future<void> _search({bool more = false}) async {
    final q = more ? _query! : SearchQuery.parse(_field.text);
    if (!q.isSearchable) return;
    final generation = ++_generation;
    final scope = more
        ? _scopeOfResults
        : _effectiveScope(ref.read(searchableBooksProvider).value);
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await ref
          .read(searchRepositoryProvider)
          .search(
            q,
            bookId: scope,
            offset: more ? _hits.length : 0,
            limit: searchPageSize,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _query = q;
        _scopeOfResults = scope;
        if (more) {
          _hits = [..._hits, ...page.hits];
        } else {
          _hits = page.hits;
          _counts = page.counts;
          _collapsed.clear();
        }
      });
      if (!more) _announce(q);
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  /// يُعلَن عدد النتائج لقارئ الشاشة عند اكتمال البحث (DESIGN §11.4).
  void _announce(SearchQuery q) {
    final l10n = AppLocalizations.of(context);
    final message = _counts.isEmpty
        ? l10n.searchNoResults(q.raw.trim())
        : _summary(l10n);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
  }

  String _summary(AppLocalizations l10n) {
    final lang = Localizations.localeOf(context).languageCode;
    final total = _counts.fold(0, (n, c) => n + c.count);
    return l10n.searchSummary(
      l10n.searchResultCount(total, formatInt(total, lang)),
      l10n.searchBookCount(_counts.length, formatInt(_counts.length, lang)),
    );
  }

  /// اتجاه الحقل حسب أول حرف (الاستعلام عربي غالباً حتى في الإنجليزية).
  TextDirection? _fieldDirection() {
    for (final c in _field.text.runes) {
      if (c >= 0x0600 && c <= 0x06FF) return TextDirection.rtl;
      if ((c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A)) {
        return TextDirection.ltr;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final booksAsync = ref.watch(searchableBooksProvider);
    final books = booksAsync.value;
    final scope = _effectiveScope(books);
    final text = _field.text;
    final query = SearchQuery.parse(text);

    final Widget field = TextField(
      controller: _field,
      autofocus: widget.initialBookId == null,
      textInputAction: TextInputAction.search,
      textDirection: _fieldDirection(),
      onChanged: _onChanged,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: l10n.searchHint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.clearSearch,
                icon: const Icon(Icons.close),
                onPressed: () {
                  _field.clear();
                  _onChanged('');
                },
              ),
        border: const OutlineInputBorder(),
      ),
    );

    final header = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          SizedBox(
            height: 4,
            child: _loading
                ? Semantics(
                    label: l10n.loading,
                    child: const LinearProgressIndicator(minHeight: 2),
                  )
                : null,
          ),
          if (books != null && books.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.searchAllBooks),
                  selected: scope == null,
                  onSelected: (_) => _setScope(null),
                ),
                for (final b in books)
                  ChoiceChip(
                    label: Text(b.title.ar, textDirection: TextDirection.rtl),
                    selected: scope == b.id,
                    onSelected: (_) => _setScope(b.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l10n.searchHelper,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    final List<Widget> content;
    if (books != null && books.isEmpty) {
      content = [
        _Message(
          text: l10n.searchNoBooks,
          action: l10n.goToLibrary,
          onAction: () => context.go('/'),
        ),
      ];
    } else if (booksAsync.hasError || _failed) {
      content = [
        _Message(
          text: l10n.searchError,
          isError: true,
          action: l10n.retry,
          onAction: booksAsync.hasError
              ? () => ref.invalidate(searchableBooksProvider)
              : _submit,
        ),
      ];
    } else if (text.trim().isEmpty || query.isEmpty) {
      content = [_Suggestions(onTap: _useSuggestion)];
    } else if (!query.isSearchable) {
      content = [_Message(text: l10n.searchMinChars)];
    } else if (_query == null) {
      content = const [];
    } else if (_counts.isEmpty) {
      content = [
        _Message(
          text: l10n.searchNoResults(_query!.displayText),
          detail: l10n.searchNoResultsHint,
          action: _scopeOfResults == null ? null : l10n.searchEverywhere,
          onAction: () => _setScope(null),
        ),
      ];
    } else {
      content = _results(l10n);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: header),
            SliverList.list(children: content),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  List<Widget> _results(AppLocalizations l10n) {
    final lang = Localizations.localeOf(context).languageCode;
    final q = _query!;
    final countOf = {for (final c in _counts) c.bookId: c};
    final total = _counts.fold(0, (n, c) => n + c.count);
    final out = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
        child: Semantics(
          header: true,
          child: Text(
            _summary(l10n),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    ];
    String? group;
    for (final hit in _hits) {
      if (hit.bookId != group) {
        group = hit.bookId;
        final c = countOf[hit.bookId];
        final bookId = hit.bookId;
        final collapsed = _collapsed.contains(bookId);
        out.add(
          _GroupHeader(
            key: ValueKey('search-group-$bookId'),
            title: hit.bookTitle,
            count: l10n.searchResultCount(
              c?.count ?? 0,
              formatInt(c?.count ?? 0, lang),
            ),
            collapsed: collapsed,
            onToggle: () => setState(() {
              if (!_collapsed.remove(bookId)) _collapsed.add(bookId);
            }),
          ),
        );
      }
      if (_collapsed.contains(hit.bookId)) continue;
      out.add(
        _ResultCard(
          hit: hit,
          onTap: () => context.push(searchResultLocation(hit, q.raw)),
        ),
      );
    }
    if (_hits.length < total) {
      out.add(
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: Center(
            child: OutlinedButton(
              onPressed: _loading ? null : () => _search(more: true),
              child: Text(l10n.searchShowMore),
            ),
          ),
        ),
      );
    }
    return out;
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    super.key,
    required this.title,
    required this.count,
    required this.collapsed,
    required this.onToggle,
  });

  final String title;
  final String count;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      expanded: !collapsed,
      button: true,
      label: l10n.searchGroupHeader(title, count),
      hint: collapsed ? l10n.expand : l10n.collapse,
      excludeSemantics: true,
      onTap: onToggle,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: bookFont,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(count, style: theme.textTheme.labelMedium),
                const SizedBox(width: 8),
                Icon(collapsed ? Icons.expand_more : Icons.expand_less),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final snippet = hit.snippet;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
      // البطاقة عنصر واحد لقارئ الشاشة؛ التظليل لا يُقرأ (DESIGN §11.4).
      child: Semantics(
        button: true,
        label: l10n.searchResultSemantics(
          hit.chapterTitle,
          hit.bookTitle,
          snippet.text,
          hit.matchedWords.join('، '),
        ),
        excludeSemantics: true,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hit.chapterTitle,
                    textDirection: TextDirection.rtl,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: highlightedSpans(
                        snippet.text,
                        snippet.spans,
                        context.extraColors.searchHighlight,
                      ),
                    ),
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: bookFont,
                      fontSize: 16,
                      height: 1.8,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// قبل الكتابة: كلمات مقترحة قابلة للنقر (DESIGN §11.3).
class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.searchSuggestionsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final word in l10n.searchSuggestionWords.split('|'))
                ActionChip(
                  label: Text(word, textDirection: TextDirection.rtl),
                  onPressed: () => onTap(word),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    this.detail,
    this.action,
    this.onAction,
    this.isError = false,
  });

  final String text;
  final String? detail;
  final String? action;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isError)
            Icon(Icons.error_outline, color: theme.colorScheme.error),
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isError ? theme.colorScheme.error : null,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton(onPressed: onAction, child: Text(action!)),
            ),
          ],
        ],
      ),
    );
  }
}
