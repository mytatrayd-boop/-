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
  Future<void> deletePrivate() => (_db.delete(_db.apiCache)..where((t) => t.private.equals(true))).go();

  @override
  Future<void> deleteOlderThan(DateTime before) =>
      (_db.delete(_db.apiCache)..where((t) => t.fetchedAt.isSmallerThanValue(before))).go();
}

/// عدّاد الحصة اليومي (جدول `quota`). الإضافة ذرّية (upsert بجمع).
class DriftQuotaStore implements QuotaStore {
  DriftQuotaStore(this._db);
  final AppDatabase _db;

  @override
  Future<int> unitsFor(String day) async {
    final row = await (_db.select(_db.quota)..where((t) => t.dayPt.equals(day))).getSingleOrNull();
    return row?.units ?? 0;
  }

  @override
  Future<void> add(String day, int units) => _db.customStatement(
        'INSERT INTO quota (day_pt, units) VALUES (?, ?) '
        'ON CONFLICT(day_pt) DO UPDATE SET units = units + excluded.units',
        [day, units],
      );

  @override
  Future<void> raiseTo(String day, int units) => _db.customStatement(
        'INSERT INTO quota (day_pt, units) VALUES (?, ?) '
        'ON CONFLICT(day_pt) DO UPDATE SET units = MAX(units, excluded.units)',
        [day, units],
      );
}
