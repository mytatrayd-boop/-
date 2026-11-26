import 'dart:io';

import 'package:bgtube/data/local/app_database.dart';
import 'package:bgtube/data/local/drift_local_playlist_repository.dart';
import 'package:bgtube/data/local/drift_queue_repository.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/playback_queue_model.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VideoRef r(int i) => VideoRef(
      videoId: 'V${i.toString().padLeft(10, '0')}',
      title: i.isEven ? 'عنوان $i' : null,
      author: 'A$i',
      duration: Duration(seconds: 60 + i),
      thumbUrl: i == 0 ? 'https://i.ytimg.com/x.jpg' : null,
    );

void main() {
  // اختبار الحفظ يفتح الملف نفسه مرتين عمداً (إغلاق ثم إعادة فتح).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('DriftQueueRepository', () {
    test('nothing saved -> null', () async {
      expect(await DriftQueueRepository(db).load(), isNull);
    });

    test('round-trips order, current, failed flag and metadata', () async {
      final repo = DriftQueueRepository(db);
      final snap = QueueSnapshot(entries: [
        QueueEntry(key: 5, ref: r(0)),
        QueueEntry(key: 2, ref: r(1), failed: true),
        QueueEntry(key: 9, ref: r(2)),
      ], currentKey: 2);
      await repo.save(snap);
      expect(await repo.load(), snap);
    });

    test('each save replaces the whole snapshot (no stale rows, ord intact)', () async {
      final repo = DriftQueueRepository(db);
      await repo.save(QueueSnapshot(entries: [for (var i = 0; i < 5; i++) QueueEntry(key: i, ref: r(i))], currentKey: 0));
      final smaller = QueueSnapshot(entries: [QueueEntry(key: 3, ref: r(3)), QueueEntry(key: 1, ref: r(1))], currentKey: 1);
      await repo.save(smaller);
      expect(await repo.load(), smaller);
      await repo.save(QueueSnapshot.empty);
      final empty = await repo.load();
      expect(empty!.isEmpty, isTrue);
    });

    test('200 items save and load in order', () async {
      final repo = DriftQueueRepository(db);
      final snap = QueueSnapshot(entries: [for (var i = 0; i < 200; i++) QueueEntry(key: 1000 - i, ref: r(i))], currentKey: 900);
      await repo.save(snap);
      expect(await repo.load(), snap);
    });
  });

  group('DriftLocalPlaylistRepository', () {
    late DriftLocalPlaylistRepository repo;
    var t = DateTime.utc(2026, 11, 26);
    setUp(() {
      t = DateTime.utc(2026, 11, 26);
      repo = DriftLocalPlaylistRepository(db, now: () => t = t.add(const Duration(seconds: 1)));
    });

    test('create with items, list with count and total duration', () async {
      final id = await repo.create('  صباحي  ', [r(0), r(1)]);
      final all = await repo.list();
      expect(all.single.id, id);
      expect(all.single.name, 'صباحي');
      expect(all.single.itemCount, 2);
      expect(all.single.totalDuration, const Duration(seconds: 121));
      expect(await repo.items(id), [r(0), r(1)]);
    });

    test('empty playlists are listed with zero items; duplicate names allowed (D27)', () async {
      await repo.create('x', []);
      await repo.create('x', [r(3)]);
      final all = await repo.list();
      expect(all.map((p) => p.itemCount), [1, 0]); // الأحدث أولاً
      expect(all.map((p) => p.name), ['x', 'x']);
    });

    test('names must be 1..100 characters after trimming', () async {
      expect(() => repo.create('   ', []), throwsArgumentError);
      expect(() => repo.create('a' * 101, []), throwsArgumentError);
      final id = await repo.create('a' * 100, []);
      expect(() => repo.rename(id, ''), throwsArgumentError);
    });

    test('rename, setItems (reorder/remove) and delete cascade to items', () async {
      final id = await repo.create('a', [r(0), r(1), r(2)]);
      await repo.rename(id, 'b');
      await repo.setItems(id, [r(2), r(0)]);
      expect((await repo.list()).single.name, 'b');
      expect(await repo.items(id), [r(2), r(0)]);
      await repo.delete(id);
      expect(await repo.list(), isEmpty);
      expect(await db.select(db.localPlaylistItems).get(), isEmpty);
    });

    test('watchAll and watchItems emit updates', () async {
      final lists = repo.watchAll();
      final id = await repo.create('w', [r(0)]);
      expect(await lists.first, hasLength(1));
      final items = repo.watchItems(id);
      expect(await items.first, [r(0)]);
      await repo.setItems(id, [r(0), r(1)]);
      expect(await repo.watchItems(id).first, [r(0), r(1)]);
    });

    test('playlists survive reopening the database file (persistence)', () async {
      // نفس الاتصال يُغلق ثم يُفتح على ملف مؤقت.
      final dir = await Directory.systemTemp.createTemp('bgtube_db');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db.sqlite');
      var fdb = AppDatabase(NativeDatabase(file));
      await DriftLocalPlaylistRepository(fdb).create('باقٍ', [r(0)]);
      await DriftQueueRepository(fdb).save(QueueSnapshot(entries: [QueueEntry(key: 1, ref: r(1))], currentKey: 1));
      await fdb.close();
      fdb = AppDatabase(NativeDatabase(file));
      expect((await DriftLocalPlaylistRepository(fdb).list()).single.name, 'باقٍ');
      expect((await DriftQueueRepository(fdb).load())!.current!.ref, r(1));
      await fdb.close();
    });
  });
}
