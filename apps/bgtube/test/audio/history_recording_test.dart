// السجل المحلي يُملأ عند بدء تشغيل مقطع (الميزة 5، D30) عبر منفذ الكتابة
// PlayHistoryRecorder فقط؛ المعالج لا يعرف الحساب ولا الواجهة.
import 'dart:async';

import 'package:bgtube/audio/bgtube_audio_handler.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/ports/play_history.dart';
import 'package:bgtube/domain/ports/playback_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'bgtube_audio_handler_test.dart' show FakeResolver, FakeRepo, audio;
import 'queue_handler_test.dart' show SeekEngine, FakeQueueRepo, ref, vid, pumpAll;

/// كالمشغّل الحقيقي: ينشر تغيّر playing.
class PlayingEngine extends SeekEngine {
  void _set(bool p) {
    if (playing == p) return;
    playing = p;
    playingCtl.add(p);
  }

  @override
  Future<void> play() async {
    log.add('play');
    _set(true);
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    _set(false);
  }

  @override
  Future<void> stop() async {
    log.add('stop');
    _set(false);
  }
}

class RecordingHistory implements PlayHistoryRecorder {
  final recorded = <VideoRef>[];
  bool failing = false;
  @override
  Future<void> record(VideoRef ref) async {
    if (failing) throw StateError('db');
    recorded.add(ref);
  }
}

void main() {
  late PlayingEngine engine;
  late FakeResolver resolver;
  late RecordingHistory history;
  late BgtubeAudioHandler h;

  setUp(() {
    engine = PlayingEngine();
    resolver = FakeResolver()..immediate = (id) async => audio(id);
    history = RecordingHistory();
    h = BgtubeAudioHandler(
      resolver: resolver,
      engine: engine,
      positions: FakeRepo(),
      queueRepo: FakeQueueRepo(),
      history: history,
      saveInterval: const Duration(hours: 1),
      prefetchQuiet: Duration.zero,
    );
  });

  List<String> ids() => [for (final r in history.recorded) r.videoId];

  test('starting a video records it once, with its metadata; pause/resume does not repeat it', () async {
    await h.enqueue([ref(0, title: 'Known')], QueuePlacement.playNow);
    await pumpAll();
    expect(ids(), [vid(0)]);
    expect(history.recorded.single.title, 'Known');
    await h.pause();
    await h.play();
    await pumpAll();
    expect(ids(), [vid(0)]);
  });

  test('each transition records the new item; jumping back records it again', () async {
    await h.enqueue([ref(0), ref(1)], QueuePlacement.playNow);
    await pumpAll();
    await h.skipToNext();
    await pumpAll();
    final first = h.queueState.value.entries.first.key;
    await h.jumpTo(first);
    await pumpAll();
    expect(ids(), [vid(0), vid(1), vid(0)]);
  });

  test('adding without playing (play next) and a failed load record nothing', () async {
    await h.enqueue([ref(0)], QueuePlacement.playNow);
    await pumpAll();
    await h.enqueue([ref(1)], QueuePlacement.playNext);
    await pumpAll();
    expect(ids(), [vid(0)]);
    resolver.immediate = (id) async => throw const AppFailure(FailureKind.network);
    await h.skipToNext();
    await pumpAll();
    expect(ids(), [vid(0)]);
  });

  test('a retry of the same item does not record it twice', () async {
    await h.enqueue([ref(0)], QueuePlacement.playNow);
    await pumpAll();
    await h.retry();
    await pumpAll();
    expect(ids(), [vid(0)]);
  });

  test('replaying the only item after it completed records it again', () async {
    await h.enqueue([ref(0)], QueuePlacement.playNow);
    await pumpAll();
    engine.emitReady();
    await pumpAll();
    engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
    await pumpAll();
    await h.play(); // يعيد الطابور من أوله
    await pumpAll();
    expect(ids(), [vid(0), vid(0)]);
  });

  test('play pressed while preparing (already playing before load) still records', () async {
    resolver.immediate = null; // ينتظر
    unawaited(h.enqueue([ref(0)], QueuePlacement.playNow));
    await pumpAll();
    await h.play(); // أثناء التحضير: playing يصبح true قبل التحميل
    await pumpAll();
    expect(ids(), isEmpty);
    resolver.pending[vid(0)]!.single.complete(audio(vid(0)));
    await pumpAll();
    expect(ids(), [vid(0)]);
  });

  test('a failing history store never breaks playback', () async {
    history.failing = true;
    await h.enqueue([ref(0), ref(1)], QueuePlacement.playNow);
    await pumpAll();
    expect(engine.playing, isTrue);
    await h.skipToNext();
    await pumpAll();
    expect(h.queueState.value.current?.ref.videoId, vid(1));
    expect(h.failure.value, isNull);
  });

  test('enqueueAfter inserts after the given item without touching the current', () async {
    final a = await h.enqueue([ref(0), ref(1), ref(2)], QueuePlacement.playNow);
    await pumpAll();
    final r = await h.enqueueAfter(a.keys[1], [ref(7), ref(8)]);
    expect([for (final e in h.queueState.value.entries) e.ref.videoId], [vid(0), vid(1), vid(7), vid(8), vid(2)]);
    expect(h.queueState.value.current?.ref.videoId, vid(0));
    expect(r.count, 2);
    // عنصر غير موجود: للنهاية.
    await h.enqueueAfter(99999, [ref(9)]);
    expect(h.queueState.value.entries.last.ref.videoId, vid(9));
  });

  test('enqueueAfter respects the 500 limit', () async {
    final a = await h.enqueue([for (var i = 0; i < 499; i++) ref(i)], QueuePlacement.addToEnd);
    await pumpAll();
    final r = await h.enqueueAfter(a.keys.first, [ref(600), ref(601)]);
    expect(r.count, 1);
    expect(r.truncated, isTrue);
    expect(h.queueState.value.entries, hasLength(PlaybackQueue.maxLength));
  });
}
