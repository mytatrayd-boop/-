import 'package:drift/drift.dart';

import '../../domain/cafe.dart';
import '../db/app_database.dart';

abstract class CafeRepository {
  /// يحفظ مقهى، أو يعيد الموجود بنفس الاسم (دون حساسية حالة الأحرف) فلا تتكرر المقاهي؛
  /// وإن كان الموجود بلا إحداثيات وتوفرت الآن تُضاف له.
  Future<Cafe> save(String name, {double? lat, double? lng});

  /// المقاهي من الأحدث مع عدد الفحوصات وآخر درجة.
  Stream<List<CafeSummary>> watchAll();

  /// يغيّر الاسم. يعيد false إن لم يوجد المقهى؛ يرمي [ArgumentError] لاسم فارغ.
  Future<bool> rename(int id, String name);

  /// يحذف المقهى ويفك ارتباط فحوصاته (الفحوصات نفسها تبقى).
  Future<bool> delete(int id);
}

class DriftCafeRepository implements CafeRepository {
  DriftCafeRepository(this._db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  static String _requireName(String name) {
    final t = name.trim();
    if (t.isEmpty) throw ArgumentError.value(name, 'name', 'must not be empty');
    return t;
  }

  @override
  Future<Cafe> save(String name, {double? lat, double? lng}) async {
    final clean = _requireName(name);
    final hasLoc = lat != null && lng != null;
    final existing = await (_db.select(_db.cafes)
          ..where((t) => t.name.lower().equals(clean.toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) {
      if (existing.lat == null && hasLoc) {
        await (_db.update(_db.cafes)..where((t) => t.id.equals(existing.id)))
            .write(CafesCompanion(lat: Value(lat), lng: Value(lng)));
        return _toCafe((await (_db.select(_db.cafes)..where((t) => t.id.equals(existing.id))).getSingle()));
      }
      return _toCafe(existing);
    }
    final id = await _db.into(_db.cafes).insert(CafesCompanion.insert(
          name: clean,
          savedAt: _clock(),
          lat: Value(hasLoc ? lat : null),
          lng: Value(hasLoc ? lng : null),
        ));
    return _toCafe(await (_db.select(_db.cafes)..where((t) => t.id.equals(id))).getSingle());
  }

  @override
  Stream<List<CafeSummary>> watchAll() => _db
          .customSelect(
            'SELECT c.id, c.name, c.lat, c.lng, c.saved_at, '
            '(SELECT COUNT(*) FROM scans s WHERE s.cafe_id = c.id) AS cnt, '
            '(SELECT s.score FROM scans s WHERE s.cafe_id = c.id '
            'ORDER BY s.created_at DESC, s.id DESC LIMIT 1) AS last_score '
            'FROM cafes c ORDER BY c.saved_at DESC, c.id DESC',
            readsFrom: {_db.cafes, _db.scans},
          )
          .watch()
          .map((rows) => [
                for (final r in rows)
                  CafeSummary(
                    cafe: Cafe(
                      id: r.read<int>('id'),
                      name: r.read<String>('name'),
                      lat: r.readNullable<double>('lat'),
                      lng: r.readNullable<double>('lng'),
                      savedAt: DateTime.fromMillisecondsSinceEpoch(r.read<int>('saved_at') * 1000),
                    ),
                    scanCount: r.read<int>('cnt'),
                    lastScore: r.readNullable<int>('last_score'),
                  ),
              ]);

  @override
  Future<bool> rename(int id, String name) async {
    final clean = _requireName(name);
    final n = await (_db.update(_db.cafes)..where((t) => t.id.equals(id)))
        .write(CafesCompanion(name: Value(clean)));
    return n > 0;
  }

  @override
  Future<bool> delete(int id) => _db.transaction(() async {
        await (_db.update(_db.scans)..where((t) => t.cafeId.equals(id)))
            .write(const ScansCompanion(cafeId: Value(null)));
        final n = await (_db.delete(_db.cafes)..where((t) => t.id.equals(id))).go();
        return n > 0;
      });

  Cafe _toCafe(CafeRow r) =>
      Cafe(id: r.id, name: r.name, lat: r.lat, lng: r.lng, savedAt: r.savedAt);
}
