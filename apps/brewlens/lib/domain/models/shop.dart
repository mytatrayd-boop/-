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
  });

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
  final bool isFavorite;

  /// متوسطات تقييمات المستخدم نفسه لهذا المقهى (للعرض فقط).
  final double? avgRating;
  final double? avgScore;

  bool get hasLocation => latitude != null && longitude != null;

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        isFavorite: json['is_favorite'] as bool? ?? false,
        avgRating: (json['avg_rating'] as num?)?.toDouble(),
        avgScore: (json['avg_score'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'is_favorite': isFavorite,
        'avg_rating': avgRating,
        'avg_score': avgScore,
      };
}
