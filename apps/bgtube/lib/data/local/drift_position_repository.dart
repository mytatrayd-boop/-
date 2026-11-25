import '../../domain/models/playback_position.dart';
import '../../domain/ports/position_repository.dart';
import 'app_database.dart';

class DriftPositionRepository implements PositionRepository {
  DriftPositionRepository(this._db);
  final AppDatabase _db;

  @override
  Future<PlaybackPosition?> get(String videoId) async {
    final row = await (_db.select(
      _db.positions,
    )..where((t) => t.videoId.equals(videoId))).getSingleOrNull();
    if (row == null) return null;
    return PlaybackPosition(
      videoId: row.videoId,
      position: Duration(milliseconds: row.positionMs),
      duration: Duration(milliseconds: row.durationMs),
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> save(PlaybackPosition p) => _db
      .into(_db.positions)
      .insertOnConflictUpdate(
        PositionsCompanion.insert(
          videoId: p.videoId,
          positionMs: p.position.inMilliseconds,
          durationMs: p.duration.inMilliseconds,
          updatedAt: p.updatedAt,
        ),
      );

  @override
  Future<void> delete(String videoId) =>
      (_db.delete(_db.positions)..where((t) => t.videoId.equals(videoId))).go();
}
