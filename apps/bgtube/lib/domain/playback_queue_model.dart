import 'models/video_ref.dart';

/// عنصر في الطابور. [key] فريد لكل عنصر (لا لكل فيديو)، فيمكن أن يتكرر الفيديو
/// نفسه. نتتبّع الحالي بمفتاحه لا بفهرسه، فلا ينكسر عند الترتيب أو الحذف (D27).
class QueueEntry {
  const QueueEntry({required this.key, required this.ref, this.failed = false});

  final int key;
  final VideoRef ref;

  /// فشل تشغيله نهائياً فتُخطّي (يُزال عند النجاح أو القفز إليه أو إعادة المحاولة).
  final bool failed;

  QueueEntry copyWith({int? key, VideoRef? ref, bool? failed}) =>
      QueueEntry(key: key ?? this.key, ref: ref ?? this.ref, failed: failed ?? this.failed);

  @override
  bool operator ==(Object other) =>
      other is QueueEntry && other.key == key && other.ref == ref && other.failed == failed;

  @override
  int get hashCode => Object.hash(key, ref, failed);

  @override
  String toString() => 'QueueEntry($key, ${ref.videoId}${failed ? ', failed' : ''})';
}

/// لقطة غير قابلة للتغيير من الطابور. القاعدة: طابور غير فارغ له حالي دائماً.
class QueueSnapshot {
  QueueSnapshot({required List<QueueEntry> entries, this.currentKey})
      : entries = List.unmodifiable(entries);

  static final empty = QueueSnapshot(entries: const []);

  final List<QueueEntry> entries;
  final int? currentKey;

  bool get isEmpty => entries.isEmpty;

  int indexOfKey(int key) => entries.indexWhere((e) => e.key == key);

  /// فهرس الحالي أو -1.
  int get currentIndex => currentKey == null ? -1 : indexOfKey(currentKey!);

  QueueEntry? get current {
    final i = currentIndex;
    return i < 0 ? null : entries[i];
  }

  QueueEntry? entryByKey(int key) {
    final i = indexOfKey(key);
    return i < 0 ? null : entries[i];
  }

  /// العنصر بعد الحالي (null في آخر الطابور).
  QueueEntry? get next {
    final i = currentIndex;
    return i < 0 || i + 1 >= entries.length ? null : entries[i + 1];
  }

  /// العنصر قبل الحالي (null في أوله).
  QueueEntry? get previous {
    final i = currentIndex;
    return i <= 0 ? null : entries[i - 1];
  }

  /// ما بعد الحالي.
  List<QueueEntry> get upcoming {
    final i = currentIndex;
    return i < 0 ? const [] : entries.sublist(i + 1);
  }

  int get remainingCount => upcoming.length;

  QueueSnapshot _with(List<QueueEntry> entries, int? currentKey) {
    // القاعدة: طابور غير فارغ له حالي؛ وإن غاب الحالي يصبح الأول.
    if (entries.isEmpty) return QueueSnapshot(entries: const []);
    final keep = currentKey != null && entries.any((e) => e.key == currentKey);
    return QueueSnapshot(entries: entries, currentKey: keep ? currentKey : entries.first.key);
  }

  @override
  bool operator ==(Object other) {
    if (other is! QueueSnapshot || other.currentKey != currentKey) return false;
    if (other.entries.length != entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      if (other.entries[i] != entries[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(currentKey, Object.hashAll(entries));
}

/// عنصر أُزيل مع فهرسه الأصلي (للتراجع).
class IndexedEntry {
  const IndexedEntry(this.index, this.entry);
  final int index;
  final QueueEntry entry;
}

/// يدرج [added] بعد الحالي مباشرة بترتيبها (في البداية إن كان الطابور فارغاً).
/// إن كان الطابور فارغاً يصبح أول المُضاف هو الحالي.
QueueSnapshot insertNext(QueueSnapshot s, List<QueueEntry> added) {
  if (added.isEmpty) return s;
  final at = s.currentIndex + 1; // -1 + 1 = 0 للفارغ
  final list = [...s.entries]..insertAll(at, added);
  return s._with(list, s.currentKey ?? added.first.key);
}

/// يدرج [added] بعد العنصر [afterKey] بترتيبها (إكمال قائمة يوتيوب بعد ما أُضيف
/// منها، D30). إن لم يعد موجوداً تُضاف في الآخر.
QueueSnapshot insertAfter(QueueSnapshot s, int afterKey, List<QueueEntry> added) {
  if (added.isEmpty) return s;
  final i = s.indexOfKey(afterKey);
  if (i < 0) return append(s, added);
  final list = [...s.entries]..insertAll(i + 1, added);
  return s._with(list, s.currentKey ?? added.first.key);
}

/// يضيف [added] في آخر الطابور.
QueueSnapshot append(QueueSnapshot s, List<QueueEntry> added) {
  if (added.isEmpty) return s;
  return s._with([...s.entries, ...added], s.currentKey ?? added.first.key);
}

/// يحذف عنصراً. إن كان الحالي يصبح التالي حالياً، وإلا السابق (آخر الطابور).
QueueSnapshot remove(QueueSnapshot s, int key) {
  final i = s.indexOfKey(key);
  if (i < 0) return s;
  final list = [...s.entries]..removeAt(i);
  if (key != s.currentKey) return s._with(list, s.currentKey);
  if (list.isEmpty) return s._with(list, null);
  final newCurrent = i < list.length ? list[i] : list[i - 1];
  return s._with(list, newCurrent.key);
}

/// ينقل عنصراً إلى [toIndex] (فهرس في القائمة بعد الإزالة، يُقصّ إلى الحدود).
/// الحالي يبقى حالياً أينما انتقل.
QueueSnapshot move(QueueSnapshot s, int key, int toIndex) {
  final i = s.indexOfKey(key);
  if (i < 0) return s;
  final list = [...s.entries];
  final e = list.removeAt(i);
  list.insert(toIndex.clamp(0, list.length), e);
  return s._with(list, s.currentKey);
}

/// يمسح كل شيء عدا الحالي (D27: «مسح الطابور» يُبقي الحالي يعمل).
QueueSnapshot clearUpcoming(QueueSnapshot s) {
  final cur = s.current;
  return cur == null ? s._with(const [], null) : s._with([cur], cur.key);
}

/// العناصر التي سيحذفها [clearUpcoming] مع فهارسها (للتراجع).
List<IndexedEntry> clearedEntries(QueueSnapshot s) => [
      for (var i = 0; i < s.entries.length; i++)
        if (s.entries[i].key != s.currentKey) IndexedEntry(i, s.entries[i]),
    ];

/// يعيد عناصر محذوفة إلى فهارسها الأصلية (تصاعدياً، تُقصّ إلى الحدود).
/// المفتاح الموجود أصلاً يُتجاهل فلا يتكرر.
QueueSnapshot reinsert(QueueSnapshot s, List<IndexedEntry> removed) {
  final sorted = [...removed]..sort((a, b) => a.index.compareTo(b.index));
  final list = [...s.entries];
  for (final r in sorted) {
    if (list.any((e) => e.key == r.entry.key)) continue;
    list.insert(r.index.clamp(0, list.length), r.entry);
  }
  return s._with(list, s.currentKey);
}

/// يجعل [key] هو الحالي (إن وُجد).
QueueSnapshot setCurrent(QueueSnapshot s, int key) =>
    s.indexOfKey(key) < 0 ? s : s._with(s.entries, key);

/// يضبط علامة الفشل لعنصر.
QueueSnapshot markFailed(QueueSnapshot s, int key, bool failed) {
  final i = s.indexOfKey(key);
  if (i < 0 || s.entries[i].failed == failed) return s;
  final list = [...s.entries];
  list[i] = list[i].copyWith(failed: failed);
  return s._with(list, s.currentKey);
}

/// يستبدل مرجع عنصر (إثراء البيانات الوصفية).
QueueSnapshot updateRef(QueueSnapshot s, int key, VideoRef ref) {
  final i = s.indexOfKey(key);
  if (i < 0 || s.entries[i].ref == ref) return s;
  final list = [...s.entries];
  list[i] = list[i].copyWith(ref: ref);
  return s._with(list, s.currentKey);
}

/// ماذا يفعل «السابق».
enum PreviousAction { restart, goPrevious }

/// الحد الذي بعده يعيد «السابق» المقطع من بدايته.
const previousRestartThreshold = Duration(seconds: 3);

/// «السابق» بعد أول ٣ ثوانٍ يعيد المقطع من بدايته، وقبلها يرجع للسابق؛ وفي أول
/// الطابور يعيد من البداية دائماً.
PreviousAction previousAction(QueueSnapshot s, Duration position) {
  if (position > previousRestartThreshold || s.previous == null) return PreviousAction.restart;
  return PreviousAction.goPrevious;
}

/// يدمج بيانات وصفية جديدة في مرجع دون استبدال المعروف. عنوان يساوي المعرّف
/// (ما يعود عند فشل البيانات الوصفية، D26) لا يُعدّ عنواناً.
VideoRef enrichRef(VideoRef ref, {String? title, String? author, Duration? duration, String? thumbUrl}) {
  final realTitle = title != null && title.isNotEmpty && title != ref.videoId ? title : null;
  return VideoRef(
    videoId: ref.videoId,
    title: ref.title ?? realTitle,
    author: ref.author ?? author,
    duration: ref.duration ?? ((duration != null && duration > Duration.zero) ? duration : null),
    thumbUrl: ref.thumbUrl ?? thumbUrl,
  );
}
