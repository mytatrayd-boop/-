import 'coffee_type.dart';

/// تقييم محفوظ. لا موقع عليه (D20)؛ الموقع على المقهى فقط.
class Review {
  const Review({
    required this.id,
    required this.coffeeType,
    required this.imagePath,
    required this.aiScore,
    required this.aiNotes,
    required this.aiTip,
    required this.createdAt,
    this.userRating,
    this.userNotes,
    this.shopId,
  });

  final String id;
  final CoffeeType coffeeType;
  final String imagePath;
  final double aiScore;
  final List<String> aiNotes;
  final String aiTip;
  final int? userRating;
  final String? userNotes;
  final String? shopId;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) {
    final ai = json['ai_notes'] as Map<String, dynamic>;
    return Review(
      id: json['id'] as String,
      coffeeType: CoffeeType.fromWire(json['coffee_type'] as String),
      imagePath: json['image_path'] as String,
      aiScore: (json['ai_score'] as num).toDouble(),
      aiNotes: List<String>.unmodifiable((ai['notes'] as List).cast<String>()),
      aiTip: ai['tip'] as String,
      userRating: (json['user_rating'] as num?)?.toInt(),
      userNotes: json['user_notes'] as String?,
      shopId: json['shop_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'coffee_type': coffeeType.wire,
        'image_path': imagePath,
        'ai_score': aiScore,
        'ai_notes': {'notes': aiNotes, 'tip': aiTip},
        'user_rating': userRating,
        'user_notes': userNotes,
        'shop_id': shopId,
        'created_at': createdAt.toUtc().toIso8601String(),
      };
}
