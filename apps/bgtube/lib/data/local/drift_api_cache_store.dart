import 'package:drift/drift.dart';

import '../../domain/ports/api_cache_store.dart';
import 'app_database.dart';

/// كاش ردود الواجهة في drift (جدول `api_cache`، D29).
class DriftApiCacheStore implements ApiCacheStore {
  DriftApiCacheStore(this._db);
  final AppDatabase _db;

  @override
  Future<CachedResponse?> read(String key) async {
    final row = await (_db.select(_db.apiCache)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return CachedResponse(json: row.json, fetchedAt: row.fetchedAt, ttl: Duration(seconds: row.ttlSec));
  }

  @override
  Future<void> write(String key, CachedResponse value, {required bool private}) =>
      _db.into(_db.apiCache).insertOnConflictUpdate(ApiCacheCompanion.insert(
            key: key,
            json: value.json,
            fetchedAt: value.fetchedAt,
            ttlSec: value.ttl.inSeconds,
            private: Value(private),
          ));

  @override
  Future<void> deleteAll() => _db.delete(_db.apiCache).go();

  @override
  Future<void> deleteOlderThan(DateTime before) =>
      (_db.delete(_db.apiCache)..where((t) => t.fetchedAt.isSmallerThanValue(before))).go();
}

/// عدّاد الحصة اليومي لكل وعاء (جدول `quota`). الإضافة ذرّية (upsert بجمع).
class DriftQuotaStore implements QuotaStore {
  DriftQuotaStore(this._db);
  final AppDatabase _db;

  @override
  Future<int> unitsFor(String day, String bucket) async {
    final row = await (_db.select(_db.quota)..where((t) => t.dayPt.equals(day) & t.bucket.equals(bucket)))
        .getSingleOrNull();
    return row?.units ?? 0;
  }

  @override
  Future<void> add(String day, String bucket, int units) => _db.customStatement(
        'INSERT INTO quota (day_pt, bucket, units) VALUES (?, ?, ?) '
        'ON CONFLICT(day_pt, bucket) DO UPDATE SET units = units + excluded.units',
        [day, bucket, units],
      );

  @override
  Future<void> raiseTo(String day, String bucket, int units) => _db.customStatement(
        'INSERT INTO quota (day_pt, bucket, units) VALUES (?, ?, ?) '
        'ON CONFLICT(day_pt, bucket) DO UPDATE SET units = MAX(units, excluded.units)',
        [day, bucket, units],
      );
}
