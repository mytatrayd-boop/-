import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../reader/continue_reading_card.dart';
import '../reader/favorites_tab.dart';
import '../search/search_screen.dart';
import 'book_card.dart';
import 'library_controller.dart';

/// شاشة المكتبة (DESIGN §7): تبويبا «الكتب» (مع «تابع القراءة») و«المفضلة».
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(libraryControllerProvider);
    final controller = ref.read(libraryControllerProvider.notifier);
    ref.listen(libraryControllerProvider, (previous, next) {
      for (final message in progressAnnouncements(context, previous, next)) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          message,
          Directionality.of(context),
        );
      }
    });

    final Widget body = switch (state.status) {
      CatalogStatus.loading => const _SkeletonList(),
      CatalogStatus.offlineEmpty => _MessageView(
        icon: Icons.shelves,
        title: l10n.offlineFirstRunTitle,
        body: l10n.offlineFirstRunBody,
        action: l10n.retry,
        onAction: controller.refresh,
      ),
      CatalogStatus.errorEmpty => _MessageView(
        icon: Icons.error_outline,
        title: null,
        body: state.notice == CatalogNotice.updateApp
            ? l10n.updateAppBanner
            : l10n.catalogError,
        action: l10n.retry,
        onAction: controller.refresh,
      ),
      CatalogStatus.ready => RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          children: [
            if (_bannerText(l10n, state.notice) case final text?) ...[
              _Banner(
                text: text,
                offline: state.notice == CatalogNotice.offline,
              ),
              const SizedBox(height: 12),
            ],
            const ContinueReadingCard(),
            if (state.items.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 48),
                child: Text(
                  l10n.emptyLibrary,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            for (final item in state.items) ...[
              BookCard(
                key: ValueKey(item.id),
                item: item,
                task: state.tasks[item.id],
                offline: state.isOffline,
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    };

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.libraryTitle),
          // الدخول إلى البحث في كل الكتب حتى يُبنى الشريط السفلي (DESIGN §6.1).
          actions: [
            IconButton(
              tooltip: l10n.searchTitle,
              icon: const Icon(Icons.search),
              onPressed: () => context.push(searchLocation()),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(height: 48, text: l10n.booksTab),
              Tab(height: 48, text: l10n.favoritesTab),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(children: [body, const FavoritesTab()]),
        ),
      ),
    );
  }

  static String? _bannerText(AppLocalizations l10n, CatalogNotice notice) =>
      switch (notice) {
        CatalogNotice.none => null,
        CatalogNotice.offline => l10n.offlineBanner,
        CatalogNotice.stale => l10n.staleCatalogBanner,
        CatalogNotice.updateApp => l10n.updateAppBanner,
        CatalogNotice.error => l10n.catalogError,
      };
}

/// تقدّم التحميل يُعلَن لقارئ الشاشة عند ٢٥ و٥٠ و٧٥ و١٠٠٪ فقط (DESIGN §7.5).
List<String> progressAnnouncements(
  BuildContext context,
  LibraryState? previous,
  LibraryState next,
) {
  final l10n = AppLocalizations.of(context);
  final lang = Localizations.localeOf(context).languageCode;
  int bucket(BookTask? t) =>
      t is DownloadingTask ? percentOf(t.fraction) ~/ 25 : 0;
  final messages = <String>[];
  next.tasks.forEach((id, task) {
    final now = bucket(task);
    if (now > 0 && now > bucket(previous?.tasks[id])) {
      final title = next.item(id)?.title.ar ?? id;
      messages.add(l10n.downloadAnnouncement(title, formatInt(now * 25, lang)));
    }
  });
  return messages;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.offline});
  final String text;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final extra = context.extraColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(12),
        decoration: BoxDecoration(
          color: extra.warningContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              offline ? Icons.cloud_off : Icons.info_outline,
              color: extra.onWarning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: extra.onWarning)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String? title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 72,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (title != null) ...[
              Semantics(
                header: true,
                child: Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

/// خمس بطاقات هيكلية أثناء جلب الفهرس (DESIGN §4.5)، بلا حركة.
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final block = context.extraColors.surfaceAlt;
    Widget bar(double widthFactor) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: 14,
        margin: const EdgeInsetsDirectional.only(bottom: 10),
        decoration: BoxDecoration(
          color: block,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
    return Semantics(
      label: l10n.loading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          itemCount: 5,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => Card(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(12),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 96,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [bar(0.7), bar(0.5), bar(0.3)],
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
