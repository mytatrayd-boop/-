import 'review.dart';

/// مقهى يملكه المستخدم (D19)، بإحداثيات اختيارية.
class Shop {
  const Shop({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.isFavorite = false,
    this.avgRating,
    this.avgScore,
    this.reviewCount = 0,
  });

  /// أقصى طول للاسم (ARCHITECTURE §7.1: 1–80).
  static const maxName = 80;

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final bool isFavorite;

  /// متوسطات تقييمات المستخدم نفسه لهذا المقهى (للعرض فقط).
  final double? avgRating;
  final double? avgScore;
  final int reviewCount;

  bool get hasLocation => latitude != null && longitude != null;

  Shop withStats(ShopStats stats, {required bool isFavorite}) => Shop(
        id: id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        isFavorite: isFavorite,
        avgRating: stats.avgRating,
        avgScore: stats.avgScore,
        reviewCount: stats.count,
      );

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isFavorite: json['is_favorite'] as bool? ?? false,
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        avgScore: (json['avg_score'] as num?)?.toDouble(),
        reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'is_favorite': isFavorite,
        'avg_rating': avgRating,
        'avg_score': avgScore,
        'review_count': reviewCount,
      };
}

/// متوسطات مقهى من تقييمات المستخدم نفسه فقط (SPEC F7 معيار 4).
class ShopStats {
  const ShopStats({this.avgRating, this.avgScore, this.count = 0});

  /// متوسط النجوم من التقييمات التي فيها نجوم فقط؛ null إن لم توجد.
  final double? avgRating;

  /// متوسط تقييم المظهر لكل تقييمات المقهى؛ null إن لم توجد.
  final double? avgScore;

  /// عدد تقييمات المقهى.
  final int count;
}

ShopStats computeShopStats(Iterable<Review> reviews, String shopId) {
  final mine = reviews.where((r) => r.shopId == shopId).toList();
  if (mine.isEmpty) return const ShopStats();
  final rated = mine.map((r) => r.userRating).whereType<int>().toList();
  final score = mine.fold<double>(0, (s, r) => s + r.aiScore) / mine.length;
  return ShopStats(
    avgRating: rated.isEmpty ? null : rated.reduce((a, b) => a + b) / rated.length,
    avgScore: score,
    count: mine.length,
  );
}

/// تطبيع الاسم للمقارنة: بلا مسافات زائدة وبلا حالة أحرف (SPEC F6 معيار 3).
String normalizeShopName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// اقتراحات المقاهي: أقل من حرفين = كل مقاهي المستخدم؛ حرفان فأكثر = حتى 5
/// مقاهٍ يحتوي اسمها النص (SPEC F6 معيار 1).
List<Shop> suggestShops(List<Shop> shops, String query) {
  final q = normalizeShopName(query);
  if (q.length < 2) return shops;
  return shops.where((s) => normalizeShopName(s.name).contains(q)).take(5).toList();
}
