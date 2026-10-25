import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/data_providers.dart';
import '../../app/failure_text.dart';
import '../../app/labels.dart';
import '../../app/router.dart';
import '../../domain/models/review.dart';
import '../../domain/models/shop.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/review_image.dart';
import '../../widgets/star_rating.dart';
import '../shops/shop_actions.dart';

/// السجل والمفضلة (F7، DESIGN §3.7).
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.historyTitle),
          bottom: TabBar(tabs: [Tab(text: l.tabMyReviews), Tab(text: l.tabFavorites)]),
        ),
        body: const TabBarView(children: [_ReviewsTab(), _FavoritesTab()]),
      ),
    );
  }
}

class _ReviewsTab extends ConsumerWidget {
  const _ReviewsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final history = ref.watch(historyProvider);
    final shops = {for (final s in ref.watch(shopsProvider).value ?? const <Shop>[]) s.id: s};
    return switch (history) {
      AsyncData(:final value) when value.items.isEmpty => Center(
          child: EmptyState(
            icon: Icons.local_cafe_outlined,
            title: l.homeEmpty,
            actionLabel: l.openCamera,
            onAction: () => context.push(Routes.capture),
          ),
        ),
      AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(historyProvider.future),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) ref.read(historyProvider.notifier).loadMore();
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 120),
              itemCount: value.items.length + (value.loadingMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i >= value.items.length) {
                  return const Center(child: Padding(
                    padding: EdgeInsetsDirectional.all(8),
                    child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  ));
                }
                final r = value.items[i];
                return ReviewTile(review: r, shop: shops[r.shopId]);
              },
            ),
          ),
        ),
      AsyncError(:final error) => ErrorState(
          message: failureText(l, error),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(historyProvider),
        ),
      _ => const _Skeletons(height: 96),
    };
  }
}

/// بطاقة تقييم أفقية ارتفاع 96 (DESIGN §3.7).
class ReviewTile extends StatelessWidget {
  const ReviewTile({super.key, required this.review, this.shop});

  final Review review;
  final Shop? shop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(Routes.reviewPath(review.id)),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(12),
          child: Row(
            children: [
              ReviewImage(review: review, width: 72, height: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coffeeTypeLabel(l, review.coffeeType), style: text.titleMedium),
                    Text(
                      shop?.name ?? l.noShop,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                    Text(
                      relativeDate(l, review.createdAt, DateTime.now()),
                      style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatScore(review.aiScore), style: text.titleLarge),
                  if (review.userRating == null)
                    Text(l.notRated, style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant))
                  else
                    StarRating(value: review.userRating, size: 12),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesProvider);
    return switch (favorites) {
      AsyncData(:final value) when value.isEmpty => Center(
          child: EmptyState(icon: Icons.favorite_border, title: l.favoritesEmpty),
        ),
      AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 120),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => FavoriteShopCard(shop: value[i]),
        ),
      AsyncError(:final error) => ErrorState(
          message: failureText(l, error),
          retryLabel: l.retry,
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
      _ => const _Skeletons(height: 88),
    };
  }
}

/// بطاقة مقهى مفضل: الاسم، المتوسطات، «فتح في خرائط جوجل»، وقلب للإزالة.
class FavoriteShopCard extends ConsumerWidget {
  const FavoriteShopCard({super.key, required this.shop, this.compact = false});

  final Shop shop;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium);
    final stats = Text(
      shopStatsLine(l, shop),
      key: Key('stats_${shop.id}'),
      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    );
    if (compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, stats]),
              ),
              IconButton(
                tooltip: l.openInGoogleMaps,
                onPressed: () => openShopInMaps(context, ref, shop),
                icon: const Icon(Icons.map_outlined),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            stats,
            Row(
              children: [
                Flexible(
                  child: TextButton.icon(
                    key: Key('maps_${shop.id}'),
                    onPressed: () => openShopInMaps(context, ref, shop),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(l.openInGoogleMaps, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l.removeFavorite,
                  onPressed: () => toggleFavorite(context, ref, shop),
                  icon: Icon(Icons.favorite, color: scheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Skeletons extends StatelessWidget {
  const _Skeletons({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsetsDirectional.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, _) => Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}
