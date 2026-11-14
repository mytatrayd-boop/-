import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo/geo.dart';
import '../db/app_database.dart';

/// حدود تصفية النقاط (ARCHITECTURE 5).
const double maxAccuracyM = 50;
const double maxSpeedMps = 100; // قفزة أسرع من هذا غير منطقية

class TrackSample {
  const TrackSample({
    required this.lat,
    required this.lng,
    required this.ts,
    this.accuracyM,
    this.speedMps,
  });

  final double lat;
  final double lng;
  final DateTime ts;
  final double? accuracyM;
  final double? speedMps;
}

/// يُستبدل في main (قاعدة القرص) وفي الاختبارات (قاعدة الذاكرة).
final tripRepositoryProvider = Provider<TripRepository>(
  (_) => throw UnimplementedError('tripRepositoryProvider must be overridden'),
);

class TripRepository {
  TripRepository(this._db);

  final AppDatabase _db;

  static String _newId() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// يبدأ رحلة بحالة recording ويعيد معرّفها.
  Future<String> startTrip({DateTime? startedAt, int quality = 720}) async {
    final id = _newId();
    await _db
        .into(_db.trips)
        .insert(
          TripsCompanion.insert(
            id: id,
            startedAt: startedAt ?? DateTime.now().toUtc(),
            status: TripStatus.recording,
            quality: Value(quality),
          ),
        );
    return id;
  }

  /// آخر نقطة مقبولة ورقمها التالي لكل رحلة (ذاكرة مؤقتة).
  final Map<String, TrackSample?> _last = {};
  final Map<String, int> _next = {};

  /// يضيف نقاطاً بعد التصفية (دقة > 50م، إحداثيات غير صالحة، قفزات غير منطقية).
  /// يعيد عدد النقاط المحفوظة فعلاً.
  /// آمنة للتزامن: الاستدعاءات لنفس الرحلة تُنفَّذ بالتسلسل.
  Future<int> addPoints(String tripId, List<TrackSample> samples) {
    final prev = _locks[tripId] ?? Future<void>.value();
    final run = prev.then((_) => _addPoints(tripId, samples));
    final tail = run.then<void>((_) {}, onError: (_) {});
    _locks[tripId] = tail;
    tail.whenComplete(() {
      if (identical(_locks[tripId], tail)) _locks.remove(tripId);
    });
    return run;
  }

  final Map<String, Future<void>> _locks = {};
  final Map<String, TrackSample?> _rejected = {};
  final Map<String, int> _rejectedCount = {};

  /// بعد هذا العدد من القفزات المتتالية المتسقة فيما بينها نعتبر المرجع هو الشاذ.
  static const int reanchorAfter = 3;

  Future<int> _addPoints(String tripId, List<TrackSample> samples) async {
    if (!_next.containsKey(tripId)) {
      final last =
          await (_db.select(_db.trackPoints)
                ..where((t) => t.tripId.equals(tripId))
                ..orderBy([(t) => OrderingTerm.desc(t.seq)])
                ..limit(1))
              .getSingleOrNull();
      _last[tripId] = last == null
          ? null
          : TrackSample(lat: last.lat, lng: last.lng, ts: last.ts);
      _next[tripId] = last == null ? 0 : last.seq + 1;
    }
    var last = _last[tripId];
    var seq = _next[tripId]!;
    final rows = <TrackPointsCompanion>[];
    for (final s in samples) {
      final p = GeoPoint(s.lat, s.lng);
      if (!p.isValid) continue;
      if (s.accuracyM != null && s.accuracyM! > maxAccuracyM) continue;
      if (last != null) {
        final dt = s.ts.difference(last.ts).inMilliseconds / 1000;
        final d = haversineMeters(GeoPoint(last.lat, last.lng), p);
        if (dt <= 0 ? d > 0 : d / dt > maxSpeedMps) {
          // قد يكون المرجع نفسه شاذاً (نقطة أولى خاطئة): إن توالت نقاط
          // متسقة فيما بينها نعيد التثبيت عليها بدل رفض الرحلة كلها.
          final rej = _rejected[tripId];
          var consistent = false;
          if (rej != null) {
            final rdt = s.ts.difference(rej.ts).inMilliseconds / 1000;
            final rd = haversineMeters(GeoPoint(rej.lat, rej.lng), p);
            consistent = rdt > 0 && rd / rdt <= maxSpeedMps;
          }
          _rejected[tripId] = s;
          _rejectedCount[tripId] = consistent
              ? (_rejectedCount[tripId] ?? 1) + 1
              : 1;
          if (_rejectedCount[tripId]! < reanchorAfter) continue;
          if (seq == 1) {
            // المرجع كان النقطة الأولى الوحيدة: هي الشاذة، نحذفها ونعيد الترقيم.
            if (rows.isNotEmpty) {
              rows.clear();
            } else {
              await (_db.delete(
                _db.trackPoints,
              )..where((t) => t.tripId.equals(tripId))).go();
            }
            seq = 0;
          }
        }
        _rejected.remove(tripId);
        _rejectedCount.remove(tripId);
      }
      rows.add(
        TrackPointsCompanion.insert(
          tripId: tripId,
          seq: seq++,
          lat: s.lat,
          lng: s.lng,
          ts: s.ts,
          accuracyM: Value(s.accuracyM),
          speedMps: Value(s.speedMps),
        ),
      );
      last = s;
    }
    if (rows.isNotEmpty) {
      await _db.batch((b) => b.insertAll(_db.trackPoints, rows));
    }
    _last[tripId] = last;
    _next[tripId] = seq;
    return rows.length;
  }

  /// ينهي الرحلة: المسافة والمدة من النقاط المحفوظة.
  Future<void> completeTrip(
    String tripId, {
    DateTime? endedAt,
    String? videoAssetId,
    String? videoPath,
  }) async {
    final trip = await getTrip(tripId);
    if (trip == null) return;
    final pts = await getPoints(tripId);
    final end = endedAt ?? DateTime.now().toUtc();
    await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(
        endedAt: Value(end),
        durationSec: Value(max(0, end.difference(trip.startedAt).inSeconds)),
        distanceM: Value(pathLengthMeters(pts)),
        videoAssetId: Value(videoAssetId),
        videoPath: Value(videoPath),
        status: const Value(TripStatus.completed),
      ),
    );
    _forget(tripId);
  }

  /// ينهي الرحلة بانقطاع أو فشل حفظ الفيديو: تُحفظ النقاط والمسافة والمدة،
  /// ومسار الفيديو إن وُجد (ما صُوِّر قبل الانقطاع).
  Future<void> interruptTrip(
    String tripId, {
    DateTime? endedAt,
    String? videoPath,
  }) async {
    final trip = await getTrip(tripId);
    if (trip == null) return;
    final pts = await getPoints(tripId);
    final end = endedAt ?? DateTime.now().toUtc();
    await (_db.update(_db.trips)..where((t) => t.id.equals(tripId))).write(
      TripsCompanion(
        endedAt: Value(end),
        durationSec: Value(max(0, end.difference(trip.startedAt).inSeconds)),
        distanceM: Value(pathLengthMeters(pts)),
        videoPath: Value(videoPath),
        status: const Value(TripStatus.interrupted),
      ),
    );
    _forget(tripId);
  }

  /// كل رحلة status=recording تُعلَّم interrupted (عند فتح التطبيق). تعيد عددها.
  /// تضبط endedAt (آخر نقطة أو وقت البدء) وdurationSec وdistanceM.
  Future<int> markInterruptedTrips() async {
    _last.clear();
    _next.clear();
    _rejected.clear();
    _rejectedCount.clear();
    final trips = await (_db.select(
      _db.trips,
    )..where((t) => t.status.equalsValue(TripStatus.recording))).get();
    for (final t in trips) {
      final rows = await _rows(t.id);
      var end = t.startedAt;
      if (rows.isNotEmpty && rows.last.ts.isAfter(end)) end = rows.last.ts;
      await (_db.update(_db.trips)..where((x) => x.id.equals(t.id))).write(
        TripsCompanion(
          endedAt: Value(end),
          durationSec: Value(end.difference(t.startedAt).inSeconds),
          distanceM: Value(
            pathLengthMeters([
              for (final r in rows) GeoPoint(r.lat, r.lng, time: r.ts),
            ]),
          ),
          status: const Value(TripStatus.interrupted),
        ),
      );
    }
    return trips.length;
  }

  Future<TripRow?> getTrip(String id) =>
      (_db.select(_db.trips)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<TrackPointRow>> _rows(String tripId) =>
      (_db.select(_db.trackPoints)
            ..where((t) => t.tripId.equals(tripId))
            ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
          .get();

  /// نقاط الرحلة مرتبة حسب seq.
  Future<List<GeoPoint>> getPoints(String tripId) async => [
    for (final r in await _rows(tripId)) GeoPoint(r.lat, r.lng, time: r.ts),
  ];

  Future<List<TrackPointRow>> getPointRows(String tripId) => _rows(tripId);

  /// الأحدث أولاً.
  Stream<List<TripRow>> watchTrips() => (_db.select(
    _db.trips,
  )..orderBy([(t) => OrderingTerm.desc(t.startedAt)])).watch();

  /// يحذف الرحلة ونقاطها (CASCADE). الفيديو لا يُمسّ.
  Future<void> deleteTrip(String id) async {
    await (_db.delete(_db.trips)..where((t) => t.id.equals(id))).go();
    _forget(id);
  }

  void _forget(String id) {
    _last.remove(id);
    _next.remove(id);
    _rejected.remove(id);
    _rejectedCount.remove(id);
  }
}
