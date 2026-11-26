import '../models/video_ref.dart';

/// المفضلة: قائمة محلية داخل التطبيق (D5)، لا تُرسل إلى يوتيوب. الأحدث أولاً،
/// والمقطع مرة واحدة.
abstract interface class FavoritesRepository {
  Stream<List<VideoRef>> watchAll();
  Future<List<VideoRef>> list();
  Stream<bool> watchContains(String videoId);
  Future<bool> contains(String videoId);

  /// إضافة مقطع موجود تحدّث بياناته ولا تكرّره.
  Future<void> add(VideoRef ref);
  Future<void> remove(String videoId);
}
