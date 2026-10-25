import 'package:brewlens/backend/demo/demo_shops_repository.dart';
import 'package:brewlens/domain/models/coffee_type.dart';
import 'package:brewlens/domain/models/review.dart';
import 'package:brewlens/domain/models/shop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Review review(String shopId, {int? rating, required double score}) => Review(
      id: 'r$shopId$score$rating',
      coffeeType: CoffeeType.espresso,
      imagePath: 'x.jpg',
      aiScore: score,
      aiNotes: const ['a', 'b', 'c'],
      aiTip: 't',
      createdAt: DateTime.utc(2026),
      userRating: rating,
      shopId: shopId,
    );

void main() {
  late SharedPreferences prefs;
  var reviews = <Review>[];
  var tick = 0;

  DemoShopsRepository repo() => DemoShopsRepository(prefs, () => reviews,
      clock: () => DateTime.utc(2026).add(Duration(seconds: tick++)));

  setUp(() async {
    reviews = [];
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('demo starts with 3 sample Riyadh cafés with coordinates', () async {
    final shops = await repo().list();
    expect(shops, hasLength(3));
    for (final s in shops) {
      expect(s.hasLocation, isTrue);
      expect(s.latitude, inInclusiveRange(24.4, 25.0));
      expect(s.longitude, inInclusiveRange(46.4, 47.0));
    }
  });

  test('a new name creates a shop; same name (spaces/case) is not duplicated', () async {
    final r = repo();
    final a = await r.create(name: '  Blue   Cup ');
    expect(a.name, 'Blue Cup');
    expect(a.hasLocation, isFalse);
    final b = await r.create(name: 'blue cup');
    expect(b.id, a.id);
    expect(await r.list(), hasLength(4));
  });

  test('saving a location attaches it, and it can be updated', () async {
    final r = repo();
    final a = await r.create(name: 'Blue Cup', latitude: 24.1, longitude: 46.1);
    expect(a.latitude, 24.1);
    final b = await r.create(name: 'Blue Cup');
    expect(b.latitude, 24.1, reason: 'name only keeps the saved location');
    final c = await r.create(name: 'BLUE CUP', latitude: 24.2, longitude: 46.2);
    expect(c.id, a.id);
    expect(c.latitude, 24.2);
  });

  test('empty name is refused', () async {
    expect(() => repo().create(name: '   '), throwsA(anything));
  });

  test('shops persist after reopening', () async {
    await repo().create(name: 'Blue Cup');
    final names = (await repo().list()).map((s) => s.name);
    expect(names, contains('Blue Cup'));
    expect(names.first, 'Blue Cup', reason: 'most recent first');
  });

  test('favorites add/remove without duplicates, with the shop average', () async {
    final r = repo();
    await r.setFavorite('demo-shop-1', favorite: true);
    await r.setFavorite('demo-shop-1', favorite: true);
    reviews = [
      review('demo-shop-1', rating: 4, score: 7.5),
      review('demo-shop-1', rating: 5, score: 8.0),
      review('demo-shop-1', score: 6.0),
      review('demo-shop-2', rating: 1, score: 2.0),
    ];
    final favs = await r.favorites();
    expect(favs, hasLength(1));
    final f = favs.single;
    expect(f.isFavorite, isTrue);
    expect(f.avgRating, 4.5);
    expect(f.avgScore, closeTo(7.1667, 0.001));
    expect(f.reviewCount, 3);
    await r.setFavorite('demo-shop-1', favorite: false);
    expect(await r.favorites(), isEmpty);
  });

  group('suggestShops', () {
    final shops = [
      for (final n in ['مقهى النخيل', 'Qahwa Lab', 'Qahwa House', 'Qahwa One', 'Qahwa Two', 'Qahwa Three', 'Qahwa Four'])
        Shop(id: n, name: n),
    ];

    test('under 2 characters lists all of the user cafés', () {
      expect(suggestShops(shops, ''), hasLength(shops.length));
      expect(suggestShops(shops, 'Q'), hasLength(shops.length));
    });

    test('2+ characters: up to 5 matches, case-insensitive, Arabic or English', () {
      expect(suggestShops(shops, 'qa'), hasLength(5));
      expect(suggestShops(shops, 'LAB').single.name, 'Qahwa Lab');
      expect(suggestShops(shops, 'النخ').single.name, 'مقهى النخيل');
      expect(suggestShops(shops, 'zz'), isEmpty);
    });
  });
}
