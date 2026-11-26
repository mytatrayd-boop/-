import 'package:drift/drift.dart';

import '../../domain/models/video_ref.dart';
import '../../domain/playback_queue_model.dart';
import '../../domain/ports/queue_repository.dart';
import 'app_database.dart';

/// يحفظ الطابور لقطة كاملة داخل transaction واحدة (حذف ثم batch insert)، فلا
/// تتلف أرقام `ord` (D27).
class DriftQueueRepository implements QueueRepository {
  DriftQueueRepository(this._db);
  final AppDatabase _db;

  @override
  Future<QueueSnapshot?> load() async {
    final rows = await (_db.select(_db.queueEntries)..orderBy([(t) => OrderingTerm.asc(t.ord)])).get();
    final state = await (_db.select(_db.queueState)..where((t) => t.id.equals(0))).getSingleOrNull();
    if (rows.isEmpty && state == null) return null;
    final entries = [
      for (final r in rows)
        QueueEntry(
          key: r.key,
          failed: r.failed,
          ref: VideoRef(
            videoId: r.videoId,
            title: r.title,
            author: r.author,
            duration: r.durationMs == null ? null : Duration(milliseconds: r.durationMs!),
            thumbUrl: r.thumbUrl,
          ),
        ),
    ];
    final current = state?.currentKey;
    final valid = current != null && entries.any((e) => e.key == current);
    return QueueSnapshot(
      entries: entries,
      currentKey: valid ? current : (entries.isEmpty ? null : entries.first.key),
    );
  }

  @override
  Future<void> save(QueueSnapshot s) => _db.transaction(() async {
        await _db.delete(_db.queueEntries).go();
        await _db.batch((b) {
          b.insertAll(_db.queueEntries, [
            for (var i = 0; i < s.entries.length; i++)
              QueueEntriesCompanion.insert(
                key: Value(s.entries[i].key),
                ord: i,
                videoId: s.entries[i].ref.videoId,
                title: Value(s.entries[i].ref.title),
                author: Value(s.entries[i].ref.author),
                durationMs: Value(s.entries[i].ref.duration?.inMilliseconds),
                thumbUrl: Value(s.entries[i].ref.thumbUrl),
                failed: Value(s.entries[i].failed),
              ),
          ]);
        });
        await _db.into(_db.queueState).insertOnConflictUpdate(QueueStateCompanion.insert(
              id: const Value(0),
              currentKey: Value(s.currentKey),
              updatedAt: DateTime.now(),
            ));
      });
}
