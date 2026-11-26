import 'package:bgtube/data/local/app_database.dart';
import 'package:bgtube/data/local/drift_api_cache_store.dart';
import 'package:bgtube/domain/ports/api_cache_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('cache round-trip, overwrite, freshness by TTL', () async {
    final s = DriftApiCacheStore(db);
    final t0 = DateTime.utc(2026, 11, 26, 10);
    expect(await s.read('k'), isNull);
    await s.write('k', CachedResponse(json: '{"a":1}', fetchedAt: t0, ttl: const Duration(minutes: 15)), private: false);
    await s.write('k', CachedResponse(json: '{"a":2}', fetchedAt: t0, ttl: const Duration(minutes: 15)), private: false);
    final r = (await s.read('k'))!;
    expect(r.json, '{"a":2}');
    expect(r.ttl, const Duration(minutes: 15));
    expect(r.isFresh(t0.add(const Duration(minutes: 14))), isTrue);
    expect(r.isFresh(t0.add(const Duration(minutes: 15))), isFalse);
  });

  test('deleteAll empties the cache; deleteOlderThan prunes', () async {
    final s = DriftApiCacheStore(db);
    final old = DateTime.utc(2026, 11, 1);
    final recent = DateTime.utc(2026, 11, 26);
    await s.write('mine', CachedResponse(json: '{}', fetchedAt: recent, ttl: Duration.zero), private: true);
    await s.write('pub', CachedResponse(json: '{}', fetchedAt: recent, ttl: Duration.zero), private: false);
    await s.write('old', CachedResponse(json: '{}', fetchedAt: old, ttl: Duration.zero), private: false);
    await s.deleteOlderThan(DateTime.utc(2026, 11, 19));
    expect(await s.read('old'), isNull);
    expect(await s.read('pub'), isNotNull);
    await s.deleteAll();
    expect(await s.read('mine'), isNull);
    expect(await s.read('pub'), isNull);
  });

  test('quota adds atomically per Pacific day and bucket; raiseTo never lowers', () async {
    final q = DriftQuotaStore(db);
    expect(await q.unitsFor('2026-11-26', 'general'), 0);
    await Future.wait([q.add('2026-11-26', 'general', 5), q.add('2026-11-26', 'general', 1), q.add('2026-11-26', 'search', 1)]);
    expect(await q.unitsFor('2026-11-26', 'general'), 6);
    expect(await q.unitsFor('2026-11-26', 'search'), 1);
    expect(await q.unitsFor('2026-11-27', 'general'), 0);
    await q.raiseTo('2026-11-26', 'general', 3);
    expect(await q.unitsFor('2026-11-26', 'general'), 6);
    await q.raiseTo('2026-11-26', 'search', 100);
    expect(await q.unitsFor('2026-11-26', 'search'), 100);
    expect(await q.unitsFor('2026-11-26', 'general'), 6);
  });
}
