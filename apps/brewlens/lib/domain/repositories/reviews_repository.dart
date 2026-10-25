import 'dart:typed_data';

import '../models/review.dart';

abstract interface class ReviewsRepository {
  /// يرفع الصورة ثم ينشئ السجل.
  Future<Review> save(Review draft, Uint8List imageBytes);

  /// صفحة من التقييمات، الأحدث أولاً.
  Future<List<Review>> list({int offset = 0, int limit = 20});

  Future<Review> update(Review review);

  /// يحذف السجل وصورته.
  Future<void> delete(String id);

  /// بايتات الصورة للعرض.
  Future<Uint8List> imageBytes(Review review);
}
