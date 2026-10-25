import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_failure.dart';
import '../../domain/models/review.dart';
import '../../domain/models/shop.dart';
import '../../domain/repositories/shops_repository.dart';
import 'demo_samples.dart';

/// مقاهي وضع العرض محلياً، مع 3 مقاهٍ نموذجية في الرياض عند أول تشغيل.
/// المتوسطات تُحسب من تقييمات المستخدم نفسه.
class DemoShopsRepository implements ShopsRepository {
  DemoShopsRepository(this._prefs, this._reviews, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const shopsKey = 'demo_shops';
  static const favoritesKey = 'demo_favorites';

  final SharedPreferences _prefs;
  final List<Review> Function() _reviews;
  final DateTime Function() _clock;

  List<Shop> _raw() {
    final raw = _prefs.getString(shopsKey);
    if (raw == null) {
      return demoSeedShops.map((e) => Shop.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return (jsonDecode(raw) as List)
        .map((e) => Shop.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _write(List<Shop> shops) async {
    final ok = await _prefs.setString(
      shopsKey,
      jsonEncode(shops
          .map((s) => {
                'id': s.id,
                'name': s.name,
                'latitude': s.latitude,
                'longitude': s.longitude,
              })
          .toList()),
    );
    if (!ok) throw const AppFailure(FailureCode.saveFailed);
  }

  Set<String> _favorites() => (_prefs.getStringList(favoritesKey) ?? const []).toSet();

  @override
  Future<List<Shop>> list() async {
    final reviews = _reviews();
    final favorites = _favorites();
    return [
      for (final s in _raw())
        s.withStats(computeShopStats(reviews, s.id), isFavorite: favorites.contains(s.id)),
    ];
  }

  @override
  Future<Shop> create({required String name, double? latitude, double? longitude}) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty || clean.length > Shop.maxName) {
      throw const AppFailure(FailureCode.saveFailed);
    }
    final hasLocation = latitude != null && longitude != null;
    final shops = _raw();
    final i = shops.indexWhere((s) => normalizeShopName(s.name) == normalizeShopName(clean));
    final Shop shop;
    if (i >= 0) {
      final old = shops.removeAt(i);
      shop = Shop(
        id: old.id,
        name: old.name,
        latitude: hasLocation ? latitude : old.latitude,
        longitude: hasLocation ? longitude : old.longitude,
      );
    } else {
      shop = Shop(
        id: 's${_clock().microsecondsSinceEpoch}',
        name: clean,
        latitude: hasLocation ? latitude : null,
        longitude: hasLocation ? longitude : null,
      );
    }
    // آخر مقهى مستخدم يظهر أولاً في الاقتراحات.
    await _write([shop, ...shops]);
    return (await list()).firstWhere((s) => s.id == shop.id);
  }

  @override
  Future<void> setFavorite(String shopId, {required bool favorite}) async {
    final favorites = _favorites();
    favorite ? favorites.add(shopId) : favorites.remove(shopId);
    await _prefs.setStringList(favoritesKey, favorites.toList());
  }

  @override
  Future<List<Shop>> favorites() async =>
      (await list()).where((s) => s.isFavorite).toList();
}
