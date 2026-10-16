/// تبويب «الكتب» للمكتبة الكبيرة (ARCHITECTURE §18.5، DESIGN §7): بحث
/// بالعنوان والمؤلف، وشرائح التصنيف والعصر، والترتيب، وقائمة كسولة تجلب
/// صفحات من 50 كتاباً من SQLite عند الاقتراب من آخرها.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../reader/continue_reading_card.dart';
import '../storage/catalog_store.dart';
import 'book_card.dart';
import 'catalog.dart';
import 'library_controller.dart';
import 'library_providers.dart';

/// حجم الصفحة (§18.5).
const catalogPageSize = 50;

/// استعلام المكتبة الحالي؛ يبقى عند التنقل بين التبويبات والشاشات.
final catalogQueryProvider =
    NotifierProvider<CatalogQueryNotifier, CatalogQuery>(
      CatalogQueryNotifier.new,
    );

class CatalogQueryNotifier extends Notifier<CatalogQuery> {
  @override
  CatalogQuery build() => const CatalogQuery();

  void set(CatalogQuery query) => state = query;
}

class CatalogTab extends ConsumerStatefulWidget {
  const CatalogTab({super.key, required this.banner});

  /// لافتة الحالة (دون إنترنت، قديمة…) أعلى القائمة، إن وُجدت.
  final Widget? banner;

  @override
  ConsumerState<CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends ConsumerState<CatalogTab> {
  final _ids = <String>[];
  var _hasMore = true;
  var _loading = false;
  var _generation = 0;
  late final TextEditingController _text;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(catalogQueryProvider).text);
    ref.listenManual(catalogQueryProvider, (_, _) => _reload());
    ref.listenManual(
      libraryControllerProvider.select((s) => s.catalogRevision),
      (_, _) => _reload(keep: true),
    );
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// [keep]: الفهرس أو المحمّل تغيّر والاستعلام نفسه، فيُعاد جلب المعروض
  /// كله دفعة واحدة دون إفراغ القائمة (لا تقفز إلى أعلاها).
  void _reload({bool keep = false}) {
    _generation++;
    _loading = false;
    _hasMore = true;
    final count = keep && _ids.length > catalogPageSize
        ? _ids.length
        : catalogPageSize;
    if (!keep) {
      _ids.clear();
      if (mounted) setState(() {});
    }
    _fetch(offset: 0, limit: count, replace: true);
  }

  void _loadMore() => _fetch(offset: _ids.length, limit: catalogPageSize);

  Future<void> _fetch({
    required int offset,
    required int limit,
    bool replace = false,
  }) async {
    if (_loading || (!replace && !_hasMore)) return;
    _loading = true;
    final generation = _generation;
    List<String> page;
    try {
      page = await ref
          .read(catalogStoreProvider)
          .query(ref.read(catalogQueryProvider), offset: offset, limit: limit);
    } on Exception {
      page = const [];
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      if (replace) _ids.clear();
      _ids.addAll(page);
      _hasMore = page.length == limit;
    });
  }

  void _setQuery(CatalogQuery query) =>
      ref.read(catalogQueryProvider.notifier).set(query);

  void _onText(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final q = ref.read(catalogQueryProvider);
      if (q.text != value) _setQuery(q.copyWith(text: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(libraryControllerProvider);
    final query = ref.watch(catalogQueryProvider);
    final controller = ref.read(libraryControllerProvider.notifier);

    // بلا فهرس محفوظ (أول تشغيل دون إنترنت مع كتب محمّلة): تُعرض المحمّلة.
    final unfiltered = query == const CatalogQuery();
    final ids = _ids.isEmpty && !_hasMore && unfiltered
        ? [for (final i in state.items) i.id]
        : _ids;

    Widget chips({
      required String label,
      required List<String> values,
      required String? selected,
      required String Function(String) name,
      required void Function(String?) onSelected,
    }) => Semantics(
      container: true,
      label: label,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final v in [null, ...values])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(v == null ? l10n.catalogFilterAll : name(v)),
                  selected: selected == v,
                  onSelected: (_) => onSelected(v),
                ),
              ),
          ],
        ),
      ),
    );

    String sortName(CatalogSort s) => switch (s) {
      CatalogSort.death => l10n.catalogSortDeath,
      CatalogSort.title => l10n.catalogSortTitle,
      CatalogSort.size => l10n.catalogSortSize,
    };

    final header = <Widget>[
      if (widget.banner case final banner?) ...[
        banner,
        const SizedBox(height: 12),
      ],
      const ContinueReadingCard(),
      // البحث والترتيب في صف واحد حتى تبقى البطاقات قريبة من أعلى الشاشة.
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _text,
              onChanged: _onText,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.catalogSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.text.isEmpty && _text.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.clearSearch,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _debounce?.cancel();
                          _text.clear();
                          _setQuery(query.copyWith(text: ''));
                        },
                      ),
              ),
            ),
          ),
          PopupMenuButton<CatalogSort>(
            tooltip: l10n.catalogSortValue(sortName(query.sort)),
            icon: const Icon(Icons.sort),
            initialValue: query.sort,
            onSelected: (s) => _setQuery(query.copyWith(sort: s)),
            itemBuilder: (_) => [
              for (final s in CatalogSort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == query.sort,
                  child: Text(sortName(s)),
                ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 8),
      chips(
        label: l10n.catalogCategoryLabel,
        values: catalogCategories,
        selected: query.category,
        name: l10n.catalogCategory,
        onSelected: (v) => _setQuery(query.copyWith(category: () => v)),
      ),
      chips(
        label: l10n.catalogEraLabel,
        values: catalogEras,
        selected: query.era,
        name: l10n.catalogEra,
        onSelected: (v) => _setQuery(query.copyWith(era: () => v)),
      ),
      const SizedBox(height: 8),
    ];

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            sliver: SliverList.list(children: header),
          ),
          if (ids.isEmpty && !_hasMore)
            SliverPadding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 16,
                vertical: 48,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  unfiltered ? l10n.emptyLibrary : l10n.catalogNoMatches,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: ids.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= ids.length - 10 && _hasMore && !_loading) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _loadMore(),
                  );
                }
                if (index >= ids.length) {
                  return Padding(
                    padding: const EdgeInsetsDirectional.all(16),
                    child: Center(
                      child: Semantics(
                        label: l10n.loading,
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                final item = state.item(ids[index]);
                if (item == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 12),
                  child: BookCard(
                    key: ValueKey(item.id),
                    item: item,
                    task: state.tasks[item.id],
                    offline: state.isOffline,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// تبويب «المحمّلة»: الكتب على الجهاز (قليلة عادةً)، بلا صفحات.
class DownloadedTab extends ConsumerWidget {
  const DownloadedTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(libraryControllerProvider);
    final items = state.installedItems;
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(32),
          child: Text(
            l10n.noDownloadedBooks,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: 12),
        child: BookCard(
          key: ValueKey(items[index].id),
          item: items[index],
          task: state.tasks[items[index].id],
          offline: state.isOffline,
        ),
      ),
    );
  }
}
