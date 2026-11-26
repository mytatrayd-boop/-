import '../playback_queue_model.dart';

/// تخزين الطابور (لقطة كاملة). ينفّذه drift في طبقة data.
abstract interface class QueueRepository {
  /// null إن لم يُحفظ طابور.
  Future<QueueSnapshot?> load();
  Future<void> save(QueueSnapshot snapshot);
}
