import 'package:bgtube/data/local/app_database.dart';
import 'package:bgtube/data/local/drift_library_repositories.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

VideoRef r(int i, {String? title}) => VideoRef(
      videoId: 'VID${i.toString().padLeft(8, '0')}',
      title: title ?? 'T$i',
      author: 'A',
      duration: const Duration(minutes: 3),
      thumbUrl: 'https://i.ytimg.com/$i.jpg',
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  var clock = DateTime.utc(2026, 11, 26, 10);
  DateTime now() => clock = clock.add(const Duration(seconds: 1));

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('history', () {
    test('newest first; playing again moves it to the top without duplicating', () async {
      final h = DriftHistoryRepository(db, now: now);
      await h.record(r(1));
      await h.record(r(2));
      await h.record(r(1));
      final list = await h.list();
      expect(list.map((e) => e.ref.videoId), [r(1).videoId, r(2).videoId]);
      expect(list.first.ref, r(1));
      expect(list.first.playedAt.isAfter(list.last.playedAt), isTrue);
    });

    test('a later record without a title keeps the known title', () async {
      final h = DriftHistoryRepository(db, now: now);
      await h.record(r(1));
      await h.record(VideoRef(videoId: r(1).videoId));
      expect((await h.list()).single.ref.title, 'T1');
    });

    test('keeps at most 500 entries (the oldest go first)', () async {
      final h = DriftHistoryRepository(db, now: now);
      for (var i = 0; i < 503; i++) {
        await h.record(r(i));
      }
      final list = await h.list();
      expect(list, hasLength(500));
      expect(list.first.ref.videoId, r(502).videoId);
      expect(list.last.ref.videoId, r(3).videoId);
    });

    test('remove one, clear all, and the stream follows', () async {
      final h = DriftHistoryRepository(db, now: now);
      await h.record(r(1));
      await h.record(r(2));
      final first = (await h.list()).first;
      final seen = <int>[];
      final sub = h.watchAll().listen((l) => seen.add(l.length));
      await pumpEventQueue();
      await h.remove(first.id);
      await pumpEventQueue();
      expect((await h.list()).single.ref.videoId, r(1).videoId);
      await h.clear();
      await pumpEventQueue();
      expect(await h.list(), isEmpty);
      expect(seen, [2, 1, 0]);
      await sub.cancel();
    });
  });

  group('favorites', () {
    test('add/remove/contains; newest first; adding again does not duplicate or move it', () async {
      final f = DriftFavoritesRepository(db, now: now);
      expect(await f.contains(r(1).videoId), isFalse);
      await f.add(r(1));
      await f.add(r(2));
      await f.add(r(1, title: 'new title'));
      final list = await f.list();
      expect(list.map((v) => v.videoId), [r(2).videoId, r(1).videoId]);
      expect(list.last.title, 'new title');
      expect(await f.contains(r(1).videoId), isTrue);
      await f.remove(r(1).videoId);
      expect(await f.contains(r(1).videoId), isFalse);
      expect(await f.list(), [r(2)]);
    });

    test('watchContains follows changes', () async {
      final f = DriftFavoritesRepository(db, now: now);
      final seen = <bool>[];
      final sub = f.watchContains(r(1).videoId).listen(seen.add);
      await pumpEventQueue();
      await f.add(r(1));
      await pumpEventQueue();
      await f.remove(r(1).videoId);
      await pumpEventQueue();
      expect(seen, [false, true, false]);
      await sub.cancel();
    });

    test('an add without metadata keeps the known one', () async {
      final f = DriftFavoritesRepository(db, now: now);
      await f.add(r(1));
      await f.add(VideoRef(videoId: r(1).videoId));
      expect((await f.list()).single, r(1));
    });
  });
}
