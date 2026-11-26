import 'package:drift/drift.dart';

import '../../domain/models/local_playlist.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/local_playlist_repository.dart';
import 'app_database.dart';

/// القوائم المحلية في drift. محلية فقط ولا تُرسل إلى يوتيوب (D27).
class DriftLocalPlaylistRepository implements LocalPlaylistRepository {
  DriftLocalPlaylistRepository(this._db, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  final AppDatabase _db;
  final DateTime Function() _now;

  static String _validName(String name) {
    final n = name.trim();
    if (n.isEmpty || n.length > LocalPlaylistRepository.maxNameLength) {
      throw ArgumentError.value(name, 'name');
    }
    return n;
  }

  Selectable<LocalPlaylist> _summaries() {
    final count = _db.localPlaylistItems.ord.count();
    final total = _db.localPlaylistItems.durationMs.sum();
    final q = _db.select(_db.localPlaylists).join([
      leftOuterJoin(_db.localPlaylistItems, _db.localPlaylistItems.playlistId.equalsExp(_db.localPlaylists.id)),
    ])
      ..addColumns([count, total])
      ..groupBy([_db.localPlaylists.id])
      ..orderBy([OrderingTerm.desc(_db.localPlaylists.updatedAt), OrderingTerm.desc(_db.localPlaylists.id)]);
    return q.map((row) {
      final p = row.readTable(_db.localPlaylists);
      return LocalPlaylist(
        id: p.id,
        name: p.name,
        itemCount: row.read(count) ?? 0,
        totalDuration: Duration(milliseconds: row.read(total) ?? 0),
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      );
    });
  }

  @override
  Stream<List<LocalPlaylist>> watchAll() => _summaries().watch();

  @override
  Future<List<LocalPlaylist>> list() => _summaries().get();

  @override
  Future<int> create(String name, List<VideoRef> refs) {
    final n = _validName(name);
    return _db.transaction(() async {
      final now = _now();
      final id = await _db.into(_db.localPlaylists).insert(
            LocalPlaylistsCompanion.insert(name: n, createdAt: now, updatedAt: now),
          );
      await _insertItems(id, refs);
      return id;
    });
  }

  @override
  Future<void> rename(int id, String name) async {
    final n = _validName(name);
    await (_db.update(_db.localPlaylists)..where((t) => t.id.equals(id)))
        .write(LocalPlaylistsCompanion(name: Value(n), updatedAt: Value(_now())));
  }

  @override
  Future<void> delete(int id) => (_db.delete(_db.localPlaylists)..where((t) => t.id.equals(id))).go();

  SimpleSelectStatement<$LocalPlaylistItemsTable, LocalPlaylistItemRow> _itemsQuery(int id) =>
      _db.select(_db.localPlaylistItems)
        ..where((t) => t.playlistId.equals(id))
        ..orderBy([(t) => OrderingTerm.asc(t.ord)]);

  static VideoRef _toRef(LocalPlaylistItemRow r) => VideoRef(
        videoId: r.videoId,
        title: r.title,
        author: r.author,
        duration: r.durationMs == null ? null : Duration(milliseconds: r.durationMs!),
        thumbUrl: r.thumbUrl,
      );

  @override
  Future<List<VideoRef>> items(int id) async => (await _itemsQuery(id).get()).map(_toRef).toList();

  @override
  Stream<List<VideoRef>> watchItems(int id) => _itemsQuery(id).watch().map((rows) => rows.map(_toRef).toList());

  @override
  Future<void> setItems(int id, List<VideoRef> refs) => _db.transaction(() async {
        await (_db.delete(_db.localPlaylistItems)..where((t) => t.playlistId.equals(id))).go();
        await _insertItems(id, refs);
        await (_db.update(_db.localPlaylists)..where((t) => t.id.equals(id)))
            .write(LocalPlaylistsCompanion(updatedAt: Value(_now())));
      });

  Future<void> _insertItems(int id, List<VideoRef> refs) => _db.batch((b) {
        b.insertAll(_db.localPlaylistItems, [
          for (var i = 0; i < refs.length; i++)
            LocalPlaylistItemsCompanion.insert(
              playlistId: id,
              ord: i,
              videoId: refs[i].videoId,
              title: Value(refs[i].title),
              author: Value(refs[i].author),
              durationMs: Value(refs[i].duration?.inMilliseconds),
              thumbUrl: Value(refs[i].thumbUrl),
            ),
        ]);
      });
}
