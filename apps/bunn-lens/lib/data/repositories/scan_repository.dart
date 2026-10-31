import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../domain/scan.dart';
import '../db/app_database.dart';

/// واجهة السجل المحلي. تستخدمها الواجهة ومسار الفحص لاحقاً.
abstract class ScanRepository {
  /// يحفظ الصورة كملف ثم الصف، ويعيد الفحص المحفوظ.
  Future<Scan> save(NewScan scan);

  /// الفحوصات من الأحدث؛ [type] لتصفية بن/قهوة. تُصدر عند كل تغيير.
  Stream<List<Scan>> watchAll({ScanType? type, bool favoritesOnly = false});

  /// يضبط حالة المفضلة. يعيد false إن لم يوجد الفحص.
  Future<bool> setFavorite(int id, bool value);

  Future<Scan?> getById(int id);

  /// فحص واحد كبث؛ يصدر null إن حُذف.
  Stream<Scan?> watchById(int id);

  /// يحذف الصف وملف الصورة. يعيد false إن لم يوجد.
  Future<bool> delete(int id);
}

class DriftScanRepository implements ScanRepository {
  DriftScanRepository(this._db, {required this.imagesDir, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Directory imagesDir;
  final DateTime Function() _clock;

  @override
  Future<Scan> save(NewScan scan) async {
    if (scan.notes.length != 3) {
      throw ArgumentError.value(scan.notes.length, 'notes', 'must be exactly 3');
    }
    if (scan.score < 0 || scan.score > 100) {
      throw RangeError.range(scan.score, 0, 100, 'score');
    }
    await imagesDir.create(recursive: true);
    final now = _clock();
    final fileName = 'scan_${now.microsecondsSinceEpoch}_${scan.imageBytes.length}.jpg';
    final file = File(p.join(imagesDir.path, fileName));
    await file.writeAsBytes(scan.imageBytes, flush: true);
    try {
      final id = await _db.into(_db.scans).insert(ScansCompanion.insert(
            type: scan.type.name,
            score: scan.score,
            notes: jsonEncode(scan.notes),
            imagePath: fileName, // اسم الملف فقط؛ المسار الكامل يُحسب عند القراءة
            createdAt: now,
            roasterName: Value(_clean(scan.roasterName)),
            price: Value(scan.price),
            promptVersion: Value(scan.promptVersion),
          ));
      return (await getById(id))!;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  @override
  Stream<List<Scan>> watchAll({ScanType? type, bool favoritesOnly = false}) {
    final q = _db.select(_db.scans)
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (type != null) q.where((t) => t.type.equals(type.name));
    if (favoritesOnly) q.where((t) => t.isFavorite.equals(true));
    return q.watch().map((rows) => rows.map(_toScan).toList());
  }

  @override
  Future<bool> setFavorite(int id, bool value) async {
    final n = await (_db.update(_db.scans)..where((t) => t.id.equals(id)))
        .write(ScansCompanion(isFavorite: Value(value)));
    return n > 0;
  }

  @override
  Future<Scan?> getById(int id) async {
    final row = await (_db.select(_db.scans)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toScan(row);
  }

  @override
  Stream<Scan?> watchById(int id) => (_db.select(_db.scans)..where((t) => t.id.equals(id)))
      .watchSingleOrNull()
      .map((r) => r == null ? null : _toScan(r));

  @override
  Future<bool> delete(int id) async {
    final scan = await getById(id);
    if (scan == null) return false;
    await (_db.delete(_db.scans)..where((t) => t.id.equals(id))).go();
    try {
      final file = File(scan.imagePath);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // الصف حُذف؛ فشل حذف الملف لا يُظهَر للمستخدم.
    }
    return true;
  }

  static String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Scan _toScan(ScanRow r) => Scan(
        id: r.id,
        type: ScanType.values.byName(r.type),
        score: r.score,
        notes: (jsonDecode(r.notes) as List).cast<String>(),
        imagePath: p.join(imagesDir.path, p.basename(r.imagePath)),
        createdAt: r.createdAt,
        roasterName: r.roasterName,
        price: r.price,
        isFavorite: r.isFavorite,
        promptVersion: r.promptVersion,
      );
}
