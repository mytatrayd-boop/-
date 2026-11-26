import 'dart:async';

import 'package:bgtube/audio/bgtube_audio_handler.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/models/playback_position.dart';
import 'package:bgtube/domain/models/resolved_audio.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/playback_queue_model.dart';
import 'package:bgtube/domain/ports/playback_queue.dart';
import 'package:bgtube/domain/ports/queue_repository.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'bgtube_audio_handler_test.dart' show FakeEngine, FakeResolver, FakeRepo, FakeSpeedStore, audio, settle;

class SeekEngine extends FakeEngine {
  final seeks = <Duration>[];
  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    this.position = position;
  }
}

class FakeQueueRepo implements QueueRepository {
  QueueSnapshot? stored;
  final saves = <QueueSnapshot>[];
  bool failing = false;
  Completer<void>? gate;

  @override
  Future<QueueSnapshot?> load() async {
    if (failing) throw StateError('db');
    return stored;
  }

  @override
  Future<void> save(QueueSnapshot s) async {
    await gate?.future;
    saves.add(s);
    if (failing) throw StateError('db');
    stored = s;
  }
}

String vid(int i) => 'V${i.toString().padLeft(10, '0')}';
VideoRef ref(int i, {String? title}) => VideoRef(videoId: vid(i), title: title ?? 'Title $i');
List<VideoRef> refs(int n) => [for (var i = 0; i < n; i++) ref(i)];

Future<void> pumpAll() async {
  for (var i = 0; i < 10; i++) {
    await settle();
  }
}

void main() {
  late SeekEngine engine;
  late FakeResolver resolver;
  late FakeRepo positions;
  late FakeQueueRepo store;
  late BgtubeAudioHandler h;

  BgtubeAudioHandler make() => BgtubeAudioHandler(
        resolver: resolver,
        engine: engine,
        positions: positions,
        queueRepo: store,
        saveInterval: const Duration(hours: 1),
      );

  setUp(() {
    engine = SeekEngine();
    resolver = FakeResolver()..immediate = (id) async => audio(id);
    positions = FakeRepo();
    store = FakeQueueRepo();
    h = make();
  });

  List<String> order() => [for (final e in h.queueState.value.entries) e.ref.videoId];
  String? currentId() => h.queueState.value.current?.ref.videoId;

  Future<void> ready() async {
    engine.emitReady();
    await pumpAll();
  }

  Future<void> complete() async {
    engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
    await pumpAll();
  }

  group('enqueue', () {
    test('adding to an empty queue starts playback immediately, whatever the placement', () async {
      final r = await h.enqueue([ref(0)], QueuePlacement.addToEnd);
      expect(r.count, 1);
      expect(currentId(), vid(0));
      expect(engine.log, contains('play'));
      expect(resolver.calls, [vid(0)]);
    });

    test('play next goes right after the current, add to end goes last; neither interrupts', () async {
      await h.enqueue([ref(0)], QueuePlacement.playNow);
      await h.enqueue([ref(1), ref(2)], QueuePlacement.addToEnd);
      final r = await h.enqueue([ref(3)], QueuePlacement.playNext);
      expect(order(), [vid(0), vid(3), vid(1), vid(2)]);
      expect(currentId(), vid(0));
      expect(resolver.calls, [vid(0)]);
      expect(r.keys, [h.queueState.value.entries[1].key]);
    });

    test('play now inserts after the current and jumps to it, saving the current position', () async {
      await h.enqueue([ref(0), ref(1)], QueuePlacement.addToEnd);
      engine.position = const Duration(seconds: 40);
      await h.enqueue([ref(5)], QueuePlacement.playNow);
      expect(order(), [vid(0), vid(5), vid(1)]);
      expect(currentId(), vid(5));
      expect(positions.store[vid(0)]!.position, const Duration(seconds: 40));
      expect(engine.setUrls.last.url.path, '/${vid(5)}');
    });

    test('the same video can be queued twice (unique keys)', () async {
      await h.enqueue([ref(0), ref(0)], QueuePlacement.addToEnd);
      final keys = h.queueState.value.entries.map((e) => e.key).toSet();
      expect(keys, hasLength(2));
    });

    test('playVideo is a wrapper for enqueue(playNow)', () async {
      await h.playVideo(vid(0));
      await h.playVideo(vid(1));
      expect(order(), [vid(0), vid(1)]);
      expect(currentId(), vid(1));
    });

    test('caps the queue at 500 and reports truncation', () async {
      await h.enqueue(refs(498), QueuePlacement.addToEnd);
      final r = await h.enqueue([ref(1000), ref(1001), ref(1002)], QueuePlacement.addToEnd);
      expect(r.count, 2);
      expect(r.truncated, isTrue);
      expect(h.queueState.value.entries, hasLength(PlaybackQueue.maxLength));
    });

    test('queue, current media item and queueIndex are published to audio_service', () async {
      await h.enqueue([ref(0), ref(1)], QueuePlacement.addToEnd);
      final items = h.queue.value;
      expect(items.map((m) => m.extras!['videoId']), [vid(0), vid(1)]);
      expect(items.map((m) => m.id), [for (final e in h.queueState.value.entries) '${e.key}']);
      expect(h.mediaItem.value!.id, items.first.id);
      expect(h.playbackState.value.queueIndex, 0);
      await h.skipToNext();
      expect(h.playbackState.value.queueIndex, 1);
      expect(h.mediaItem.value!.id, items[1].id);
    });
  });

  group('sequential playback', () {
    test('completed plays the next automatically; the last one stops (no repeat)', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await ready();
      await complete();
      expect(currentId(), vid(1));
      await ready();
      await complete();
      expect(currentId(), vid(2));
      await ready();
      final before = engine.setUrls.length;
      await complete();
      expect(currentId(), vid(2));
      expect(engine.setUrls.length, before);
      expect(engine.setUrls.map((e) => e.url.path), ['/${vid(0)}', '/${vid(1)}', '/${vid(2)}']);
    });

    test('a completed item starts from zero later; a transition resumes from the saved spot', () async {
      positions.store[vid(1)] = PlaybackPosition(
          videoId: vid(1), position: const Duration(seconds: 77), duration: const Duration(minutes: 3), updatedAt: DateTime.utc(2026));
      positions.store[vid(0)] = PlaybackPosition(
          videoId: vid(0), position: const Duration(seconds: 50), duration: const Duration(minutes: 3), updatedAt: DateTime.utc(2026));
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      expect(engine.setUrls.last.start, const Duration(seconds: 50));
      await ready();
      await complete();
      expect(positions.store[vid(0)], isNull);
      expect(engine.setUrls.last.start, const Duration(seconds: 77));
    });

    test('race: user jumps at the same moment as the automatic advance -> the user wins', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await ready();
      engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
      final c = h.queueState.value.entries[2].key;
      final jump = h.jumpTo(c); // قبل أن ينفّذ الانتقال التلقائي
      await pumpAll();
      await jump;
      expect(currentId(), vid(2));
      // 1 استُخرج مسبقاً فقط (ready)، ولم يُحمَّل في المشغّل.
      expect(engine.setUrls.map((e) => e.url.path), ['/${vid(0)}', '/${vid(2)}']);
    });

    test('race: user presses next as the item completes -> exactly one step, not two', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await ready();
      engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
      final next = h.skipToNext(); // في اللحظة نفسها
      await pumpAll();
      await next;
      expect(currentId(), vid(1));
      expect(engine.setUrls.map((e) => e.url.path), ['/${vid(0)}', '/${vid(1)}']);
    });

    test('rapid next presses: the latest one wins', () async {
      await h.enqueue(refs(4), QueuePlacement.addToEnd);
      resolver.immediate = null;
      await ready(); // استخراج مسبق لـ1 معلّق
      unawaited(h.skipToNext()); // إلى 1 (ينتظر استخراجه المسبق)
      await settle();
      unawaited(h.skipToNext()); // إلى 2 قبل اكتمال الأول
      await pumpAll();
      resolver.pending[vid(1)]!.single.complete(audio(vid(1)));
      await pumpAll();
      resolver.pending[vid(2)]!.single.complete(audio(vid(2)));
      await pumpAll();
      expect(currentId(), vid(2));
      expect(engine.setUrls.map((e) => e.url.path), ['/${vid(0)}', '/${vid(2)}']);
    });

    test('a duplicate or stale completed event does not advance twice', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await ready();
      engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
      engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
      await pumpAll();
      expect(currentId(), vid(1));
    });

    test('previous after 3s restarts the item; before 3s goes to the previous item', () async {
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      await h.skipToNext();
      engine.position = const Duration(seconds: 10);
      await h.skipToPrevious();
      expect(engine.seeks.last, Duration.zero);
      expect(currentId(), vid(1));
      engine.position = const Duration(seconds: 2);
      await h.skipToPrevious();
      expect(currentId(), vid(0));
      // في أول الطابور: يعيد من البداية.
      engine.position = const Duration(seconds: 1);
      await h.skipToPrevious();
      expect(currentId(), vid(0));
      expect(engine.seeks.last, Duration.zero);
    });

    test('next at the end does nothing; skipToQueueItem maps the index to the entry', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await h.skipToQueueItem(2);
      expect(currentId(), vid(2));
      final n = engine.setUrls.length;
      await h.skipToNext();
      expect(engine.setUrls.length, n);
      await h.skipToQueueItem(9); // خارج الحدود: لا شيء
      expect(currentId(), vid(2));
    });

    test('after the queue ended, play restarts from the first item', () async {
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      await h.skipToNext();
      await ready();
      await complete();
      await h.play();
      expect(currentId(), vid(0));
      expect(engine.setUrls.last.url.path, '/${vid(0)}');
    });
  });

  group('failures', () {
    test('a final extraction failure marks the item, announces it, and moves to the next', () async {
      final skipped = <VideoRef>[];
      h.skippedFailures.listen(skipped.add);
      resolver.immediate = (id) async =>
          id == vid(1) ? throw const AppFailure(FailureKind.extractionFailed) : audio(id);
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await h.skipToNext();
      await pumpAll();
      expect(currentId(), vid(2));
      expect(h.queueState.value.entries[1].failed, isTrue);
      expect(h.failure.value, isNull);
      expect(skipped.single.videoId, vid(1));
      expect(engine.playing, isTrue);
    });

    test('player failure after the single automatic retry also skips', () async {
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      engine.emitError();
      await pumpAll();
      expect(resolver.calls, [vid(0), vid(0)]); // محاولة تلقائية واحدة
      engine.emitError();
      await pumpAll();
      expect(currentId(), vid(1));
      expect(h.queueState.value.entries.first.failed, isTrue);
    });

    test('network failure stops the queue without marking the item', () async {
      resolver.immediate = (id) async =>
          id == vid(1) ? throw const AppFailure(FailureKind.network) : audio(id);
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await h.skipToNext();
      await pumpAll();
      expect(currentId(), vid(1));
      expect(h.failure.value?.kind, FailureKind.network);
      expect(h.queueState.value.entries[1].failed, isFalse);
      expect(resolver.calls, isNot(contains(vid(2))));
    });

    test('three consecutive failures stop the queue (a 200-item queue is not burned)', () async {
      resolver.immediate = (_) async => throw const AppFailure(FailureKind.rateLimited);
      await h.enqueue(refs(200), QueuePlacement.addToEnd);
      await pumpAll();
      expect(resolver.calls, [vid(0), vid(1), vid(2)]);
      expect(h.failure.value?.kind, FailureKind.queueStopped);
      expect(currentId(), vid(2));
      final flags = h.queueState.value.entries.take(3).map((e) => e.failed).toList();
      expect(flags, [true, true, false]);
    });

    test('a success resets the consecutive failure count', () async {
      resolver.immediate = (id) async =>
          {vid(0), vid(1), vid(3)}.contains(id) ? throw const AppFailure(FailureKind.extractionFailed) : audio(id);
      await h.enqueue(refs(5), QueuePlacement.addToEnd);
      await pumpAll();
      expect(currentId(), vid(2));
      await ready(); // نجح 2
      await complete();
      await pumpAll();
      expect(currentId(), vid(4)); // 3 فشل وتُخطّي، ولم يتوقف الطابور
      expect(h.failure.value, isNull);
    });

    test('the last item failing is marked and shows the failure with retry', () async {
      resolver.immediate = (_) async => throw const AppFailure(FailureKind.extractionFailed);
      await h.playVideo(vid(0));
      expect(h.failure.value?.kind, FailureKind.extractionFailed);
      expect(h.queueState.value.entries.single.failed, isTrue);
      resolver.immediate = (id) async => audio(id);
      await h.retry();
      expect(h.failure.value, isNull);
      expect(h.queueState.value.entries.single.failed, isFalse);
    });

    test('jumping to a failed item clears its mark and tries again', () async {
      resolver.immediate = (id) async =>
          id == vid(1) ? throw const AppFailure(FailureKind.extractionFailed) : audio(id);
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await h.skipToNext();
      await pumpAll();
      resolver.immediate = (id) async => audio(id);
      final key = h.queueState.value.entries[1].key;
      await h.jumpTo(key);
      expect(currentId(), vid(1));
      expect(h.queueState.value.entries[1].failed, isFalse);
    });
  });

  group('lazy extraction', () {
    test('a 200-item queue extracts only the current and, after it is ready, the next', () async {
      await h.enqueue(refs(200), QueuePlacement.addToEnd);
      expect(resolver.calls, [vid(0)]);
      await ready();
      expect(resolver.calls, [vid(0), vid(1)]);
      await ready(); // ready متكرر لا يكرر الاستخراج
      expect(resolver.calls, [vid(0), vid(1)]);
      // الانتقال يستعمل الناتج المسبق ولا يستخرج مرة أخرى.
      await h.skipToNext();
      expect(resolver.calls, [vid(0), vid(1)]);
      expect(engine.setUrls.last.url.path, '/${vid(1)}');
      await ready();
      expect(resolver.calls, [vid(0), vid(1), vid(2)]);
      expect(engine.setUrls, hasLength(2)); // لا مصدر مسبق في المشغّل (D26)
    });

    test('a prefetch still in flight is awaited, not repeated', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      resolver.immediate = null;
      await ready();
      expect(resolver.calls, [vid(0), vid(1)]);
      final next = h.skipToNext();
      await pumpAll();
      resolver.pending[vid(1)]!.single.complete(audio(vid(1)));
      await next;
      expect(resolver.calls, [vid(0), vid(1)]);
      expect(engine.setUrls.last.url.path, '/${vid(1)}');
    });

    test('prefetch is discarded when the next item changes (reorder)', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await ready();
      expect(resolver.calls, [vid(0), vid(1)]);
      final c = h.queueState.value.entries[2].key;
      expect(h.prefetchedKeys, {h.queueState.value.entries[1].key});
      await h.moveEntry(c, 1); // صار 2 هو التالي
      expect(h.prefetchedKeys, isEmpty); // رُمي ناتج 1
      await h.skipToNext();
      expect(currentId(), vid(2));
      expect(resolver.calls, [vid(0), vid(1), vid(2)]);
    });

    test('a failed prefetch is swallowed; the real failure shows on transition', () async {
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      resolver.immediate = (id) async => throw const AppFailure(FailureKind.extractionFailed);
      await ready();
      expect(h.failure.value, isNull);
      await h.skipToNext();
      expect(resolver.calls, [vid(0), vid(1), vid(1)]);
      expect(h.failure.value?.kind, FailureKind.extractionFailed);
    });

    test('a prefetched link close to expiry is not used', () async {
      resolver.immediate = (id) async => ResolvedAudio(
            url: Uri.parse('https://example.com/$id'),
            title: 'T',
            expiresAt: clock.now().add(const Duration(minutes: 5)),
          );
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      await ready();
      await h.skipToNext();
      expect(resolver.calls, [vid(0), vid(1), vid(1)]);
    });

    test('play after a long pause with an expired link reloads from the same position', () {
      fakeAsync((fa) {
        h = make();
        unawaited(h.enqueue([ref(0)], QueuePlacement.addToEnd));
        fa.flushMicrotasks();
        engine.emitReady();
        fa.flushMicrotasks();
        unawaited(h.pause());
        engine.position = const Duration(minutes: 2);
        fa.elapse(const Duration(minutes: 31)); // رابط بلا انتهاء معروف: ٣٠ د
        unawaited(h.play());
        fa.flushMicrotasks();
        expect(resolver.calls, [vid(0), vid(0)]);
        expect(engine.setUrls.last.start, const Duration(minutes: 2));
        expect(engine.playing, isTrue);
      });
    });

    test('play after a short pause just resumes', () async {
      await h.enqueue([ref(0)], QueuePlacement.addToEnd);
      await ready();
      await h.pause();
      await h.play();
      expect(resolver.calls, [vid(0)]);
      expect(engine.playing, isTrue);
    });
  });

  group('sleep timer and speed across transitions', () {
    test('the timer keeps running across automatic transitions and its expiry pauses the whole queue', () {
      fakeAsync((fa) {
        h = make(); // داخل المنطقة الوهمية حتى تمر أحداث المشغّل عبرها
        unawaited(h.enqueue(refs(3), QueuePlacement.addToEnd));
        fa.flushMicrotasks();
        engine.emitReady();
        fa.flushMicrotasks();
        h.startSleepTimer(const Duration(seconds: 30));
        fa.elapse(const Duration(seconds: 10));
        engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
        fa.flushMicrotasks();
        expect(currentId(), vid(1));
        engine.emitReady();
        fa.flushMicrotasks();
        expect(h.sleepRemaining.value, const Duration(seconds: 20));
        fa.elapse(const Duration(seconds: 21));
        expect(engine.playing, isFalse);
        expect(currentId(), vid(1)); // لا انتقال بعد الانتهاء
        fa.elapse(const Duration(minutes: 5));
        expect(currentId(), vid(1));
      });
    });

    test('timer expiring while the automatic next is loading: it stays paused', () {
      fakeAsync((fa) {
        h = make();
        unawaited(h.enqueue(refs(2), QueuePlacement.addToEnd));
        fa.flushMicrotasks();
        resolver.immediate = null;
        h.startSleepTimer(const Duration(seconds: 12));
        engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
        fa.flushMicrotasks();
        expect(h.resolving.value, isTrue);
        fa.elapse(const Duration(seconds: 13));
        final plays = engine.log.where((e) => e == 'play').length;
        resolver.pending[vid(1)]!.single.complete(audio(vid(1)));
        fa.flushMicrotasks();
        expect(engine.log.where((e) => e == 'play').length, plays);
        expect(engine.playing, isFalse);
      });
    });

    test('the chosen speed applies to every item', () async {
      final speedStore = FakeSpeedStore();
      h = BgtubeAudioHandler(resolver: resolver, engine: engine, speedStore: speedStore);
      await h.setSpeed(1.5);
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      engine.speed = 1.0; // المحرك أُعيد ضبطه
      await ready();
      await complete();
      expect(currentId(), vid(1));
      expect(engine.speed, 1.5);
      expect(engine.speedCalls.where((s) => s == 1.5).length, greaterThanOrEqualTo(3));
    });
  });

  group('editing', () {
    test('removing an upcoming item; undo puts it back in place', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      final s = h.queueState.value;
      final removed = IndexedEntry(1, s.entries[1]);
      await h.removeEntry(s.entries[1].key);
      expect(order(), [vid(0), vid(2)]);
      await h.restoreEntries([removed]);
      expect(order(), [vid(0), vid(1), vid(2)]);
    });

    test('removing the current playing item moves to the next and keeps playing', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await ready();
      await h.removeEntry(h.queueState.value.currentKey!);
      expect(order(), [vid(1), vid(2)]);
      expect(currentId(), vid(1));
      expect(engine.playing, isTrue);
    });

    test('removing the current paused item moves to the next without playing', () async {
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      await ready();
      await h.pause();
      await h.removeEntry(h.queueState.value.currentKey!);
      expect(currentId(), vid(1));
      expect(engine.playing, isFalse);
    });

    test('removing the only item stops and empties the queue', () async {
      await h.enqueue([ref(0)], QueuePlacement.addToEnd);
      await h.removeEntry(h.queueState.value.currentKey!);
      expect(h.queueState.value.isEmpty, isTrue);
      expect(h.nowPlaying.value, isNull);
      expect(engine.playing, isFalse);
    });

    test('undo of an add removes exactly what was added', () async {
      await h.enqueue([ref(0)], QueuePlacement.addToEnd);
      await h.enqueue([ref(1)], QueuePlacement.addToEnd);
      final r = await h.enqueue([ref(2), ref(3)], QueuePlacement.playNext);
      await h.removeEntries(r.keys);
      expect(order(), [vid(0), vid(1)]);
    });

    test('clear keeps the current playing; undo restores everything in order', () async {
      await h.enqueue(refs(4), QueuePlacement.addToEnd);
      await h.skipToNext();
      final cleared = clearedEntries(h.queueState.value);
      await h.clearUpcoming();
      expect(order(), [vid(1)]);
      expect(engine.playing, isTrue);
      await h.restoreEntries(cleared);
      expect(order(), [vid(0), vid(1), vid(2), vid(3)]);
      expect(currentId(), vid(1));
    });

    test('reordering keeps the current by key', () async {
      await h.enqueue(refs(3), QueuePlacement.addToEnd);
      await h.moveEntry(h.queueState.value.currentKey!, 2);
      expect(order(), [vid(1), vid(2), vid(0)]);
      expect(currentId(), vid(0));
    });

    test('stop keeps the queue; play then loads the current from its saved spot', () async {
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      await h.skipToNext();
      engine.position = const Duration(seconds: 45);
      await h.stop();
      expect(order(), [vid(0), vid(1)]);
      expect(h.nowPlaying.value, isNull);
      await h.play();
      expect(engine.setUrls.last.url.path, '/${vid(1)}');
      expect(engine.setUrls.last.start, const Duration(seconds: 45));
    });
  });

  group('metadata enrichment', () {
    test('a pasted link (id only) is enriched from extraction and saved', () async {
      await h.playVideo(vid(0));
      final r = h.queueState.value.current!.ref;
      expect(r.title, 'T-${vid(0)}');
      expect(r.duration, const Duration(minutes: 3));
      await h.queueSavesIdle;
      expect(store.stored!.entries.single.ref.title, 'T-${vid(0)}');
    });

    test('a known title is not replaced by the id fallback', () async {
      resolver.immediate = (id) async => ResolvedAudio(url: Uri.parse('https://example.com/$id'), title: id);
      await h.enqueue([ref(0, title: 'Known')], QueuePlacement.addToEnd);
      expect(h.queueState.value.current!.ref.title, 'Known');
      expect(h.nowPlaying.value!.title, 'Known');
      expect(h.mediaItem.value!.title, 'Known');
    });
  });

  group('persistence and restore', () {
    test('every change is saved; pending snapshots are coalesced to the latest', () async {
      store.gate = Completer<void>();
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      await h.enqueue([ref(5)], QueuePlacement.addToEnd);
      await h.enqueue([ref(6)], QueuePlacement.addToEnd);
      store.gate!.complete();
      await pumpAll();
      await h.queueSavesIdle;
      expect(store.saves.length, lessThanOrEqualTo(2));
      expect([for (final e in store.stored!.entries) e.ref.videoId], [vid(0), vid(1), vid(5), vid(6)]);
    });

    test('storage failure does not break playback', () async {
      store.failing = true;
      await h.enqueue(refs(2), QueuePlacement.addToEnd);
      await h.queueSavesIdle;
      expect(engine.playing, isTrue);
      expect(h.failure.value, isNull);
    });

    test('restore shows the queue and current item without extracting or playing', () async {
      store.stored = QueueSnapshot(entries: [
        QueueEntry(key: 7, ref: ref(0)),
        QueueEntry(key: 8, ref: ref(1)),
        QueueEntry(key: 9, ref: ref(2), failed: true),
      ], currentKey: 8);
      positions.store[vid(1)] = PlaybackPosition(
          videoId: vid(1), position: const Duration(minutes: 5), duration: const Duration(minutes: 20), updatedAt: DateTime.utc(2026));
      await h.restoreQueue();
      expect(order(), [vid(0), vid(1), vid(2)]);
      expect(currentId(), vid(1));
      expect(h.queueState.value.entries[2].failed, isTrue);
      expect(h.nowPlaying.value!.title, 'Title 1');
      expect(h.mediaItem.value!.title, 'Title 1');
      expect(h.queue.value, hasLength(3));
      expect(resolver.calls, isEmpty);
      expect(engine.log, isNot(contains('play')));
      await h.play();
      expect(resolver.calls, [vid(1)]);
      expect(engine.setUrls.single.start, const Duration(minutes: 5));
      expect(engine.playing, isTrue);
    });

    test('items shared before restore finished stay current after the restored ones', () async {
      await h.playVideo(vid(9));
      await h.queueSavesIdle;
      store.stored = QueueSnapshot(entries: [QueueEntry(key: 1, ref: ref(0))], currentKey: 1);
      await h.restoreQueue();
      expect(order(), [vid(0), vid(9)]);
      expect(currentId(), vid(9));
      expect(h.queueState.value.entries.map((e) => e.key).toSet(), hasLength(2));
    });

    test('nothing stored or unreadable storage: empty queue, no crash', () async {
      await h.restoreQueue();
      expect(h.queueState.value.isEmpty, isTrue);
      store.failing = true;
      await h.restoreQueue();
      expect(h.queueState.value.isEmpty, isTrue);
    });
  });
}
