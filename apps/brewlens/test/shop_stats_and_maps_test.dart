import 'package:brewlens/app/labels.dart';
import 'package:brewlens/domain/models/coffee_type.dart';
import 'package:brewlens/domain/models/review.dart';
import 'package:brewlens/domain/models/shop.dart';
import 'package:brewlens/l10n/app_localizations.dart';
import 'package:brewlens/services/maps_launcher.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Review r(String? shopId, double score, [int? rating]) => Review(
      id: '$shopId$score$rating',
      coffeeType: CoffeeType.v60,
      imagePath: 'x.jpg',
      aiScore: score,
      aiNotes: const ['a', 'b', 'c'],
      aiTip: 't',
      createdAt: DateTime.utc(2026),
      userRating: rating,
      shopId: shopId,
    );

void main() {
  group('computeShopStats', () {
    test('averages only that shop; stars only from rated reviews', () {
      final stats = computeShopStats(
        [r('a', 8, 4), r('a', 6), r('a', 7, 2), r('b', 1, 1), r(null, 10, 5)],
        'a',
      );
      expect(stats.count, 3);
      expect(stats.avgScore, 7);
      expect(stats.avgRating, 3);
    });

    test('no star ratings -> avgRating null', () {
      final stats = computeShopStats([r('a', 8)], 'a');
      expect(stats.avgRating, isNull);
      expect(stats.avgScore, 8);
    });

    test('no reviews -> empty stats', () {
      final stats = computeShopStats([r('b', 8, 3)], 'a');
      expect(stats.count, 0);
      expect(stats.avgScore, isNull);
      expect(stats.avgRating, isNull);
    });
  });

  group('shopStatsLine', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('with stars', () {
      const shop = Shop(id: 'a', name: 'x', avgRating: 4.25, avgScore: 7.8, reviewCount: 6);
      expect(shopStatsLine(ar, shop), '★ 4.3 · مظهر 7.8 · 6 تقييمات');
      expect(shopStatsLine(en, shop), '★ 4.3 · Look 7.8 · 6 reviews');
    });

    test('dash when no star ratings', () {
      const shop = Shop(id: 'a', name: 'x');
      expect(shopStatsLine(ar, shop), '— · لا تقييمات');
    });
  });

  group('googleMapsUri', () {
    test('uses coordinates when saved', () {
      const shop = Shop(id: 'a', name: 'مقهى', latitude: 24.7136, longitude: 46.6753);
      expect(
        googleMapsUri(shop).toString(),
        'https://www.google.com/maps/search/?api=1&query=24.7136,46.6753',
      );
    });

    test('falls back to the encoded name', () {
      const shop = Shop(id: 'a', name: ' مقهى النخيل & Co ');
      final uri = googleMapsUri(shop);
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/search/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['query'], 'مقهى النخيل & Co');
      expect(uri.toString(), isNot(contains(' ')));
      expect(uri.toString(), contains('%26'));
    });

    test('no API key in the link (D14)', () {
      final uri = googleMapsUri(const Shop(id: 'a', name: 'x', latitude: 1, longitude: 2));
      expect(uri.queryParameters.keys, unorderedEquals(['api', 'query']));
    });
  });

  group('labels', () {
    final ar = lookupAppLocalizations(const Locale('ar'));

    test('score description bands', () {
      expect(scoreLabel(ar, 4), 'يحتاج عناية');
      expect(scoreLabel(ar, 4.5), 'جيد');
      expect(scoreLabel(ar, 6.5), 'جيد');
      expect(scoreLabel(ar, 7), 'ممتاز');
      expect(scoreLabel(ar, 8.5), 'ممتاز');
      expect(scoreLabel(ar, 9), 'استثنائي');
    });

    test('formatScore keeps latin digits', () {
      expect(formatScore(7.5), '7.5');
      expect(formatScore(8), '8');
      expect(formatScore(7.16), '7.2');
    });

    test('relative date', () {
      final now = DateTime(2026, 10, 25, 10);
      expect(relativeDate(ar, DateTime(2026, 10, 25, 1), now), 'اليوم');
      expect(relativeDate(ar, DateTime(2026, 10, 24, 23), now), 'أمس');
      expect(relativeDate(ar, DateTime(2026, 10, 22), now), 'قبل 3 أيام');
      expect(relativeDate(ar, DateTime(2026, 8, 1), now), '2026/08/01');
    });
  });
}
