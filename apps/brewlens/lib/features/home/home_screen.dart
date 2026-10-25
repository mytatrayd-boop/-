import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/data_providers.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../domain/models/review.dart';
import '../../domain/models/shop.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/review_image.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/usage_counter.dart';
import '../history/history_screen.dart';

/// الرئيسية (F7، DESIGN §3.4): البطل والعدّاد، آخر 5 تقييمات، والمفضلة.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.signOutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.signOut)),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final usage = ref.watch(usageProvider);
    final recent = ref.watch(recentReviewsProvider).value ?? const <Review>[];
    final favorites = ref.watch(favoritesProvider).value ?? const <Shop>[];
    final shops = {for (final s in ref.watch(shopsProvider).value ?? const <Shop>[]) s.id: s};
    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeWelcome),
        actions: [
          const AppLogo(size: 32),
          IconButton(
            tooltip: l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 120),
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeHeroTitle, style: text.titleLarge?.copyWith(color: scheme.onPrimary)),
                const SizedBox(height: 4),
                Text(l.homeHeroBody, style: text.bodyMedium?.copyWith(color: scheme.onPrimary)),
                const SizedBox(height: 12),
                // خطأ العدّاد: يُخفى فقط (DESIGN §3.4). عند 0 يفتح الاشتراك.
                switch (usage) {
                  AsyncData(:final value) => GestureDetector(
                      onTap: value.remaining <= 0 ? () => context.push(Routes.paywall) : null,
                      child: UsageCounter(usage: value, onHero: true),
                    ),
                  AsyncError() => const SizedBox.shrink(),
                  _ => Text('…', style: TextStyle(color: scheme.onPrimary)),
                },
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('hero_camera'),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.onPrimary,
                    foregroundColor: scheme.primary,
                  ),
                  onPressed: () => context.push(Routes.capture),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l.openCamera),
                ),
              ],
            ),
          ),
          if (recent.isEmpty && favorites.isEmpty) ...[
            const SizedBox(height: 48),
            Icon(Icons.local_cafe_outlined, size: 96, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l.homeEmpty, style: text.titleMedium, textAlign: TextAlign.center),
          ],
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(title: l.recentReviews, onSeeAll: () => context.go(Routes.history)),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _RecentCard(review: recent[i], shop: shops[recent[i].shopId]),
              ),
            ),
          ],
          if (favorites.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              title: l.favoriteShops,
              onSeeAll: () => context.go(Routes.historyFavorites),
            ),
            for (final shop in favorites.take(3))
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8),
                child: FavoriteShopCard(shop: shop, compact: true),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onSeeAll});

  final String title;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          TextButton(onPressed: onSeeAll, child: Text(AppLocalizations.of(context).seeAll)),
        ],
      );
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.review, this.shop});

  final Review review;
  final Shop? shop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.reviewPath(review.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ReviewImage(review: review, width: 140, height: 110, radius: 0),
                  PositionedDirectional(
                    top: 8,
                    start: 8,
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(formatScore(review.aiScore),
                          style: text.labelMedium?.copyWith(color: scheme.onPrimaryContainer)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 0),
                child: Text(shop?.name ?? l.noShop,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
              ),
              if (review.userRating != null)
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
                  child: StarRating(value: review.userRating, size: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
