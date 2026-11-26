import '../models/local_playlist.dart';
import '../models/video_ref.dart';

/// القوائم المحلية (D27). مستقلة عن الطابور: التشغيل والإضافة يقرآن العناصر ثم
/// يمرّان بـ`PlaybackQueue.enqueue`.
abstract interface class LocalPlaylistRepository {
  /// الاسم بين ١ و١٠٠ حرف بعد القص؛ غير ذلك يرمي [ArgumentError].
  static const maxNameLength = 100;

  Stream<List<LocalPlaylist>> watchAll();
  Future<List<LocalPlaylist>> list();
  Future<int> create(String name, List<VideoRef> refs);
  Future<void> rename(int id, String name);
  Future<void> delete(int id);
  Future<List<VideoRef>> items(int id);
  Stream<List<VideoRef>> watchItems(int id);

  /// يستبدل عناصر القائمة بالترتيب المعطى (ترتيب أو حذف أو تراجع).
  Future<void> setItems(int id, List<VideoRef> refs);
}
