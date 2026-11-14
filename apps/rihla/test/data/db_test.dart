import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rihla/data/db/app_database.dart';
import 'package:rihla/data/repositories/trip_repository.dart';

final t0 = DateTime.utc(2026, 1, 1, 10);
TrackSample s(int sec, double lat, double lng, {double? acc}) => TrackSample(
  lat: lat,
  lng: lng,
  ts: t0.add(Duration(seconds: sec)),
  accuracyM: acc,
);

void main() {
  late AppDatabase db;
  late TripRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TripRepository(db);
  });
  tearDown(() => db.close());

  test(
    'start, add, read in order, complete computes distance/duration',
    () async {
      final id = await repo.startTrip(startedAt: t0, quality: 1080);
      expect((await repo.getTrip(id))!.status, TripStatus.recording);
      final n = await repo.addPoints(id, [
        s(0, 24.0, 46.0),
        s(10, 24.001, 46.0),
      ]);
      expect(n, 2);
      expect(await repo.addPoints(id, [s(20, 24.002, 46.0)]), 1); // دفعة ثانية
      final rows = await repo.getPointRows(id);
      expect(rows.map((r) => r.seq), [0, 1, 2]);
      await repo.completeTrip(
        id,
        endedAt: t0.add(const Duration(seconds: 90)),
        videoAssetId: 'asset1',
      );
      final t = (await repo.getTrip(id))!;
      expect(t.status, TripStatus.completed);
      expect(t.durationSec, 90);
      expect(t.quality, 1080);
      expect(t.videoAssetId, 'asset1');
      expect(t.distanceM, closeTo(222, 2));
    },
  );

  test('filters bad accuracy, invalid coords, impossible jumps', () async {
    final id = await repo.startTrip(startedAt: t0);
    final n = await repo.addPoints(id, [
      s(0, 24.0, 46.0, acc: 5),
      s(1, 24.0001, 46.0, acc: 80), // دقة سيئة
      s(2, double.nan, 46.0),
      s(3, 95, 46.0), // خارج النطاق
      s(4, 30.0, 50.0), // قفزة مئات الكم في ثانيتين
      s(5, 24.0002, 46.0, acc: 50), // الحد مقبول
    ]);
    expect(n, 2);
    expect((await repo.getPoints(id)).length, 2);
  });

  test('seq continues after a new repository instance (app restart)', () async {
    final id = await repo.startTrip(startedAt: t0);
    await repo.addPoints(id, [s(0, 24.0, 46.0)]);
    final repo2 = TripRepository(db);
    await repo2.addPoints(id, [s(5, 24.0001, 46.0)]);
    expect((await repo2.getPointRows(id)).map((r) => r.seq), [0, 1]);
  });

  test('markInterruptedTrips only touches recording trips', () async {
    final a = await repo.startTrip(startedAt: t0);
    final b = await repo.startTrip(startedAt: t0);
    await repo.completeTrip(b, endedAt: t0);
    expect(await repo.markInterruptedTrips(), 1);
    expect((await repo.getTrip(a))!.status, TripStatus.interrupted);
    expect((await repo.getTrip(b))!.status, TripStatus.completed);
    expect(await repo.markInterruptedTrips(), 0);
  });

  test('deleteTrip cascades to points and leaves other trips', () async {
    final a = await repo.startTrip(startedAt: t0);
    final b = await repo.startTrip(startedAt: t0);
    await repo.addPoints(a, [s(0, 24.0, 46.0), s(5, 24.0001, 46.0)]);
    await repo.addPoints(b, [s(0, 24.0, 46.0)]);
    await repo.deleteTrip(a);
    expect(await repo.getTrip(a), isNull);
    expect(await repo.getPointRows(a), isEmpty);
    expect((await repo.getPointRows(b)).length, 1);
    expect((await db.select(db.trackPoints).get()).length, 1);
  });

  test('watchTrips emits newest first and updates', () async {
    final first = await repo.startTrip(startedAt: t0);
    final second = await repo.startTrip(
      startedAt: t0.add(const Duration(hours: 1)),
    );
    expect((await repo.watchTrips().first).map((t) => t.id), [second, first]);
  });

  test('empty/unknown ids are safe', () async {
    expect(await repo.getTrip('nope'), isNull);
    expect(await repo.getPoints('nope'), isEmpty);
    await repo.completeTrip('nope');
    await repo.deleteTrip('nope');
  });

  test(
    'schema: v1 DB created by raw SQL opens with expected version and data',
    () async {
      final raw = NativeDatabase.memory(
        setup: (d) {
          d.execute('''CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY,
        started_at INTEGER NOT NULL, ended_at INTEGER,
        duration_sec INTEGER NOT NULL DEFAULT 0, distance_m REAL NOT NULL DEFAULT 0,
        video_asset_id TEXT, video_path TEXT, quality INTEGER NOT NULL DEFAULT 720,
        status TEXT NOT NULL, title TEXT)''');
          d.execute(
            '''CREATE TABLE track_points (id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id TEXT NOT NULL REFERENCES trips (id) ON DELETE CASCADE,
        seq INTEGER NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL,
        ts INTEGER NOT NULL, accuracy_m REAL, speed_mps REAL)''',
          );
          d.execute(
            "INSERT INTO trips (id, started_at, status) VALUES ('old', 1767261600, 'recording')",
          );
          d.execute('PRAGMA user_version = 1');
        },
      );
      final old = AppDatabase(raw);
      addTearDown(old.close);
      final r = TripRepository(old);
      expect((await r.getTrip('old'))!.status, TripStatus.recording);
      expect(await r.markInterruptedTrips(), 1);
      final v = await old.customSelect('PRAGMA user_version').getSingle();
      expect(v.read<int>('user_version'), AppDatabase.version);
      final fk = await old.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fk.read<int>('foreign_keys'), 1);
    },
  );

  test('fresh DB: index on (trip_id, seq) exists and is unique', () async {
    final id = await repo.startTrip(startedAt: t0);
    await repo.addPoints(id, [s(0, 24.0, 46.0)]);
    final idx = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type='index' AND name='track_points_trip_seq'",
        )
        .get();
    expect(idx.length, 1);
    expect(
      () => db
          .into(db.trackPoints)
          .insert(
            TrackPointsCompanion.insert(
              tripId: id,
              seq: 0,
              lat: 1,
              lng: 1,
              ts: t0,
            ),
          ),
      throwsA(isA<Object>()),
    );
  });

  test('markInterruptedTrips sets endedAt, durationSec, distance', () async {
    final a = await repo.startTrip(startedAt: t0);
    await repo.addPoints(a, [s(0, 24.0, 46.0), s(30, 24.001, 46.0)]);
    final empty = await repo.startTrip(startedAt: t0);
    expect(await repo.markInterruptedTrips(), 2);
    final ta = (await repo.getTrip(a))!;
    expect(ta.status, TripStatus.interrupted);
    expect(
      ta.endedAt!.isAtSameMomentAs(t0.add(const Duration(seconds: 30))),
      isTrue,
    );
    expect(ta.durationSec, 30);
    expect(ta.distanceM, greaterThan(100));
    final te = (await repo.getTrip(empty))!;
    expect(te.endedAt!.isAtSameMomentAs(t0), isTrue);
    expect(te.durationSec, 0);
  });

  test('concurrent addPoints on one trip keeps unique ordered seq', () async {
    final id = await repo.startTrip(startedAt: t0);
    final results = await Future.wait([
      for (var i = 0; i < 10; i++)
        repo.addPoints(id, [
          s(i * 10, 24.0 + i * 0.0001, 46.0),
          s(i * 10 + 5, 24.0 + i * 0.0001 + 0.00005, 46.0),
        ]),
    ]);
    expect(results.fold<int>(0, (a, b) => a + b), 20);
    final rows = await repo.getPointRows(id);
    expect(rows.map((r) => r.seq), List.generate(20, (i) => i));
  });

  test('outlier first point does not poison the reference', () async {
    final id = await repo.startTrip(startedAt: t0);
    await repo.addPoints(id, [s(0, 50.0, 10.0)]); // شاذة
    await repo.addPoints(id, [
      s(10, 24.0, 46.0),
      s(20, 24.0001, 46.0),
      s(30, 24.0002, 46.0),
      s(40, 24.0003, 46.0),
    ]);
    final rows = await repo.getPointRows(id);
    expect(rows.first.lat, 24.0002); // أُعيد التثبيت بعد 3 قفزات متسقة
    expect(rows.map((r) => r.seq), List.generate(rows.length, (i) => i));
    expect(rows.length, 2);
    // الرحلة لا تقفز آلاف الكيلومترات
    await repo.completeTrip(id, endedAt: t0.add(const Duration(minutes: 1)));
    expect((await repo.getTrip(id))!.distanceM, lessThan(100));
  });

  test('markGallerySaved: galleryDone بلا معرّف، والمعرّف اختياري', () async {
    final id = await repo.startTrip(startedAt: t0, quality: 720);
    expect((await repo.getTrip(id))!.galleryDone, isFalse);
    await repo.markGallerySaved(id);
    var trip = (await repo.getTrip(id))!;
    expect(trip.galleryDone, isTrue);
    expect(trip.videoAssetId, isNull);
    await repo.markGallerySaved(id, assetId: 'a1');
    trip = (await repo.getTrip(id))!;
    expect(trip.galleryDone, isTrue);
    expect(trip.videoAssetId, 'a1');
  });

  test('ترحيل حقيقي v1 -> v2: تبقى البيانات وتُضاف galleryDone=false', () async {
    final dir = await Directory.systemTemp.createTemp('rihla_mig');
    final file = File('${dir.path}/v1.sqlite');
    addTearDown(() => dir.delete(recursive: true));

    // قاعدة بمخطط v1 الفعلي (قبل galleryDone) وuser_version=1 وبيانات فعلية.
    final v1 = NativeDatabase(
      file,
      setup: (raw) {
        if (raw.select('PRAGMA user_version').first.values.first == 0) {
          raw.execute('''
CREATE TABLE trips (
  id TEXT NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER NULL,
  duration_sec INTEGER NOT NULL DEFAULT 0, distance_m REAL NOT NULL DEFAULT 0,
  video_asset_id TEXT NULL, video_path TEXT NULL,
  quality INTEGER NOT NULL DEFAULT 720, status TEXT NOT NULL, title TEXT NULL,
  PRIMARY KEY (id));
CREATE TABLE track_points (
  id INTEGER PRIMARY KEY AUTOINCREMENT, trip_id TEXT NOT NULL
    REFERENCES trips (id) ON DELETE CASCADE,
  seq INTEGER NOT NULL, lat REAL NOT NULL, lng REAL NOT NULL,
  ts INTEGER NOT NULL, accuracy_m REAL NULL, speed_mps REAL NULL);
CREATE UNIQUE INDEX track_points_trip_seq ON track_points (trip_id, seq);
INSERT INTO trips (id, started_at, duration_sec, video_path, status)
  VALUES ('old', 1767261600, 90, '/v/old.mp4', 'completed');
INSERT INTO track_points (trip_id, seq, lat, lng, ts)
  VALUES ('old', 0, 24.0, 46.0, 1767261600);
PRAGMA user_version = 1;
''');
        }
      },
    );
    final old = AppDatabase(v1);
    final migrated = await old.select(old.trips).get();
    expect(migrated.single.id, 'old');
    expect(migrated.single.videoPath, '/v/old.mp4');
    expect(migrated.single.galleryDone, isFalse);
    expect((await old.select(old.trackPoints).get()).length, 1);
    final ver = await old.customSelect('PRAGMA user_version').getSingle();
    expect(ver.data.values.first, 2);
    await old.close();

    // إعادة الفتح: لا ترحيل ثانٍ، والكتابة تعمل على العمود الجديد.
    final again = AppDatabase(NativeDatabase(file));
    await TripRepository(again).markGallerySaved('old');
    expect((await TripRepository(again).getTrip('old'))!.galleryDone, isTrue);
    await again.customSelect('SELECT ?', variables: [Variable.withInt(1)]).get();
    await again.close();
  });
}
