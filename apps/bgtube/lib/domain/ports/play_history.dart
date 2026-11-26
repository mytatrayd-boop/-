import '../models/library_entries.dart';
import '../models/video_ref.dart';

/// ما يحتاجه معالج الصوت من السجل: تسجيل مقطع بدأ تشغيله فقط (لا قراءة ولا
/// حساب ولا واجهة). الفشل لا يكسر التشغيل.
abstract interface class PlayHistoryRecorder {
  Future<void> record(VideoRef ref);
}

/// سجل التشغيل داخل التطبيق (محلي، D5/D30): الأحدث أولاً، والمقطع نفسه صف واحد
/// (تشغيله من جديد ينقله للأعلى)، وبحد [maxEntries].
abstract interface class HistoryRepository implements PlayHistoryRecorder {
  static const maxEntries = 500;

  Stream<List<HistoryEntry>> watchAll();
  Future<List<HistoryEntry>> list();
  Future<void> remove(int id);
  Future<void> clear();
}
