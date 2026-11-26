import 'package:drift/drift.dart';

import '../../domain/models/library_entries.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/favorites_repository.dart';
import '../../domain/ports/play_history.dart';
import 'app_database.dart';

Duration? _dur(int? ms) => ms == null ? null : Duration(milliseconds: ms);

/// المفضلة في drift (محلية، D5/D30). لا تُمسح عند تسجيل الخروج.
class DriftFavoritesRepository implements FavoritesRepository {
  DriftFavoritesRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  static VideoRef _toRef(FavoriteRow r) => VideoRef(
        videoId: r.videoId,
        title: r.title,
        author: r.author,
        duration: _dur(r.durationMs),
        thumbUrl: r.thumbUrl,
      );

  SimpleSelectStatement<$FavoritesTable, FavoriteRow> get _all => _db.select(_db.favorites)
    ..orderBy([(t) => OrderingTerm.desc(t.addedAt), (t) => OrderingTerm.desc(t.rowId)]);

  @override
  Stream<List<VideoRef>> watchAll() => _all.watch().map((rows) => rows.map(_toRef).toList());

  @override
  Future<List<VideoRef>> list() async => (await _all.get()).map(_toRef).toList();

  SimpleSelectStatement<$FavoritesTable, FavoriteRow> _one(String id) =>
      _db.select(_db.favorites)..where((t) => t.videoId.equals(id));

  @override
  Stream<bool> watchContains(String videoId) => _one(videoId).watch().map((rows) => rows.isNotEmpty);

  @override
  Future<bool> contains(String videoId) async => (await _one(videoId).getSingleOrNull()) != null;

  @override
  Future<void> add(VideoRef ref) => _db.transaction(() async {
        final old = await _one(ref.videoId).getSingleOrNull();
        // لا يُستبدل عنوان معروف بفراغ (مقطع ملصق قبل إثرائه).
        await _db.into(_db.favorites).insertOnConflictUpdate(FavoritesCompanion.insert(
              videoId: ref.videoId,
              title: Value(ref.title ?? old?.title),
              author: Value(ref.author ?? old?.author),
              durationMs: Value(ref.duration?.inMilliseconds ?? old?.durationMs),
              thumbUrl: Value(ref.thumbUrl ?? old?.thumbUrl),
              addedAt: old?.addedAt ?? _now(),
            ));
      });

  @override
  Future<void> remove(String videoId) => (_db.delete(_db.favorites)..where((t) => t.videoId.equals(videoId))).go();
}

/// سجل التشغيل في drift (محلي، D5/D30): صف لكل مقطع، وتشغيله من جديد ينقله
/// للأعلى، وما زاد عن [HistoryRepository.maxEntries] يُحذف الأقدم منه.
class DriftHistoryRepository implements HistoryRepository {
  DriftHistoryRepository(this._db, {DateTime Function()? now, this.maxEntries = HistoryRepository.maxEntries})
      : _now = now ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;
  final int maxEntries;

  static HistoryEntry _toEntry(HistoryRow r) => HistoryEntry(
        id: r.id,
        playedAt: r.playedAt,
        ref: VideoRef(
          videoId: r.videoId,
          title: r.title,
          author: r.author,
          duration: _dur(r.durationMs),
          thumbUrl: r.thumbUrl,
        ),
      );

  // المعرّف يزيد مع كل تسجيل، فهو ترتيب «الأحدث أولاً» حتى لو تساوى الوقت.
  SimpleSelectStatement<$HistoryTable, HistoryRow> get _all =>
      _db.select(_db.history)..orderBy([(t) => OrderingTerm.desc(t.id)]);

  @override
  Stream<List<HistoryEntry>> watchAll() => _all.watch().map((rows) => rows.map(_toEntry).toList());

  @override
  Future<List<HistoryEntry>> list() async => (await _all.get()).map(_toEntry).toList();

  @override
  Future<void> record(VideoRef ref) => _db.transaction(() async {
        final old =
            await (_db.select(_db.history)..where((t) => t.videoId.equals(ref.videoId))).getSingleOrNull();
        if (old != null) await (_db.delete(_db.history)..where((t) => t.id.equals(old.id))).go();
        await _db.into(_db.history).insert(HistoryCompanion.insert(
              videoId: ref.videoId,
              title: Value(ref.title ?? old?.title),
              author: Value(ref.author ?? old?.author),
              durationMs: Value(ref.duration?.inMilliseconds ?? old?.durationMs),
              thumbUrl: Value(ref.thumbUrl ?? old?.thumbUrl),
              playedAt: _now(),
            ));
        // الحد: يبقى الأحدث فقط.
        await _db.customUpdate(
          'DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY id DESC LIMIT ?)',
          variables: [Variable.withInt(maxEntries)],
          updates: {_db.history},
          updateKind: UpdateKind.delete,
        );
      });

  @override
  Future<void> remove(int id) => (_db.delete(_db.history)..where((t) => t.id.equals(id))).go();

  @override
  Future<void> clear() => _db.delete(_db.history).go();
}
