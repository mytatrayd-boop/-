import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/app_failure.dart';
import '../../domain/models/review.dart';
import '../../domain/repositories/reviews_repository.dart';

/// تقييمات وضع العرض: السجلات JSON في shared_preferences، والصور ملفات في
/// مجلد التطبيق. imagePath نسبي ({id}.jpg) لأن مسار المجلد قد يتغير بين
/// التحديثات على iOS.
class DemoReviewsRepository implements ReviewsRepository {
  DemoReviewsRepository(this._prefs, this._imagesDir, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const key = 'demo_reviews';

  final SharedPreferences _prefs;
  final Future<Directory> Function() _imagesDir;
  final DateTime Function() _clock;

  /// كل التقييمات، الأحدث أولاً.
  List<Review> all() {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> _write(List<Review> reviews) async {
    final ok = await _prefs.setString(
      key,
      jsonEncode(reviews.map((r) => r.toJson()).toList()),
    );
    if (!ok) throw const AppFailure(FailureCode.saveFailed);
  }

  Future<File> _file(String imagePath) async =>
      File('${(await _imagesDir()).path}${Platform.pathSeparator}$imagePath');

  @override
  Future<Review> save(Review draft, Uint8List imageBytes) async {
    final now = _clock();
    final id = 'r${now.microsecondsSinceEpoch}';
    final review = Review(
      id: id,
      coffeeType: draft.coffeeType,
      imagePath: '$id.jpg',
      aiScore: draft.aiScore,
      aiNotes: draft.aiNotes,
      aiTip: draft.aiTip,
      createdAt: now,
      userRating: draft.userRating,
      userNotes: draft.userNotes,
      shopId: draft.shopId,
    );
    try {
      final file = await _file(review.imagePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(imageBytes, flush: true);
    } on FileSystemException {
      throw const AppFailure(FailureCode.saveFailed);
    }
    await _write([review, ...all()]);
    return review;
  }

  @override
  Future<List<Review>> list({int offset = 0, int limit = 20}) async =>
      all().skip(offset).take(limit).toList();

  @override
  Future<Review> get(String id) async {
    for (final r in all()) {
      if (r.id == id) return r;
    }
    throw const AppFailure(FailureCode.saveFailed);
  }

  @override
  Future<Review> update(Review review) async {
    final reviews = all();
    final i = reviews.indexWhere((r) => r.id == review.id);
    if (i < 0) throw const AppFailure(FailureCode.saveFailed);
    reviews[i] = review;
    await _write(reviews);
    return review;
  }

  @override
  Future<void> delete(String id) async {
    final reviews = all();
    final target = reviews.where((r) => r.id == id).firstOrNull;
    if (target == null) return;
    try {
      final file = await _file(target.imagePath);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      throw const AppFailure(FailureCode.saveFailed);
    }
    await _write(reviews..removeWhere((r) => r.id == id));
  }

  @override
  Future<Uint8List> imageBytes(Review review) async {
    final file = await _file(review.imagePath);
    return file.readAsBytes();
  }
}
