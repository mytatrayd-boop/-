import 'package:flutter/foundation.dart';

import '../models/video_ref.dart';
import '../playback_queue_model.dart';

/// أين يوضع ما يُضاف إلى الطابور.
enum QueuePlacement { playNow, playNext, addToEnd }

/// نتيجة الإضافة: مفاتيح العناصر المضافة (لـ«تراجع») وهل قُصّ ما زاد عن الحد.
class EnqueueResult {
  const EnqueueResult(this.keys, {this.truncated = false});
  final List<int> keys;
  final bool truncated;
  int get count => keys.length;
}

/// المنفذ الوحيد للطابور (D27). كل الشاشات تضيف عبر [enqueue] فقط.
/// ينفّذه معالج الصوت.
abstract interface class PlaybackQueue {
  /// الحد الأقصى لعناصر الطابور؛ ما زاد يُقصّ.
  static const maxLength = 500;

  ValueListenable<QueueSnapshot> get queueState;

  /// إن كان الطابور فارغاً فأي خيار يبدأ التشغيل فوراً.
  Future<EnqueueResult> enqueue(List<VideoRef> refs, QueuePlacement placement);

  Future<void> skipToNext();

  /// بعد ٣ ث يعيد المقطع من بدايته، وقبلها يرجع للسابق.
  Future<void> skipToPrevious();
  Future<void> jumpTo(int key);
  Future<void> removeEntry(int key);
  Future<void> moveEntry(int key, int toIndex);

  /// يمسح كل شيء عدا الحالي (يبقى يعمل).
  Future<void> clearUpcoming();

  /// للتراجع عن إضافة: يزيل هذه المفاتيح.
  Future<void> removeEntries(List<int> keys);

  /// للتراجع عن حذف أو مسح: يعيد العناصر إلى فهارسها.
  Future<void> restoreEntries(List<IndexedEntry> removed);

  /// مقطع فشل نهائياً فتُخطّي إلى التالي (لرسالة قصيرة في الواجهة).
  Stream<VideoRef> get skippedFailures;
}
