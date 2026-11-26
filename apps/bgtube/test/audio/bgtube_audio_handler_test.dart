import 'dart:async';

import 'package:bgtube/audio/audio_engine.dart';
import 'package:bgtube/audio/bgtube_audio_handler.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/models/playback_position.dart';
import 'package:bgtube/domain/models/resolved_audio.dart';
import 'package:bgtube/domain/ports/audio_source_resolver.dart';
import 'package:bgtube/domain/ports/position_repository.dart';
import 'package:bgtube/domain/ports/speed_store.dart';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class FakeEngine implements AudioEngine {
  final events = StreamController<PlaybackEvent>.broadcast();
  final playingCtl = StreamController<bool>.broadcast();
  final log = <String>[];
  final setUrls = <({Uri url, Duration start})>[];
  Future<void> Function(Uri url)? onSetUrl;

  @override
  Duration position = Duration.zero;
  @override
  bool playing = false;
  @override
  double speed = 1;

  @override
  Stream<PlaybackEvent> get playbackEventStream => events.stream;
  @override
  Stream<bool> get playingStream => playingCtl.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  final durationCtl = StreamController<Duration?>.broadcast();
  @override
  Stream<Duration?> get durationStream => durationCtl.stream;

  final setHeaders = <Map<String, String>>[];

  @override
  String? sourceErrorDetail;

  @override
  Future<void> setUrl(Uri url, {required Duration initialPosition, Map<String, String> headers = const {}}) async {
    log.add('setUrl');
    setHeaders.add(headers);
    setUrls.add((url: url, start: initialPosition));
    await onSetUrl?.call(url);
  }

  @override
  Future<void> play() async {
    log.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    playing = false;
  }
  @override
  Future<void> stop() async {
    log.add('stop');
    playing = false;
  }

  @override
  Future<void> seek(Duration position) async {}
  final volumes = <double>[];
  @override
  Future<void> setVolume(double v) async => volumes.add(v);
  final speedCalls = <double>[];
  @override
  Future<void> setSpeed(double s) async {
    speed = s;
    speedCalls.add(s);
  }

  @override
  Future<void> dispose() async {}

  int get stops => log.where((e) => e == 'stop').length;

  void emitReady() => events.add(PlaybackEvent(processingState: ProcessingState.ready));
  void emitError() => events.addError(PlayerException(0, 'boom', null));
}

class FakeResolver implements AudioSourceResolver {
  final calls = <String>[];
  final pending = <String, List<Completer<ResolvedAudio>>>{};

  /// إن وُجد يُرجَع فوراً بدل الانتظار.
  Future<ResolvedAudio> Function(String id)? immediate;

  @override
  Future<ResolvedAudio> resolve(String videoId) {
    calls.add(videoId);
    if (immediate != null) return immediate!(videoId);
    final c = Completer<ResolvedAudio>();
    pending.putIfAbsent(videoId, () => []).add(c);
    return c.future;
  }
}

ResolvedAudio audio(String id) => ResolvedAudio(
      url: Uri.parse('https://example.com/$id'),
      title: 'T-$id',
      author: 'A',
      duration: const Duration(minutes: 3),
    );

class FakeSpeedStore implements SpeedStore {
  double? stored;
  bool failing = false;
  Completer<void>? loadGate;
  @override
  Future<double?> load() async {
    await loadGate?.future;
    if (failing) throw StateError('prefs');
    return stored;
  }

  @override
  Future<void> save(double s) async {
    if (failing) throw StateError('prefs');
    stored = s;
  }
}

class FakeRepo implements PositionRepository {
  final store = <String, PlaybackPosition>{};
  bool failing = false;
  int writes = 0;

  /// إن وُجد ينتظر الحفظ حتى يكتمل (لاختبار السباقات).
  Completer<void>? saveGate;
  @override
  Future<PlaybackPosition?> get(String id) async {
    if (failing) throw StateError('db');
    return store[id];
  }

  @override
  Future<void> save(PlaybackPosition p) async {
    writes++;
    await saveGate?.future;
    if (failing) throw StateError('db');
    store[p.videoId] = p;
  }

  @override
  Future<void> delete(String id) async {
    writes++;
    if (failing) throw StateError('db');
    store.remove(id);
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeEngine engine;
  late FakeResolver resolver;
  late BgtubeAudioHandler h;

  setUp(() {
    engine = FakeEngine();
    resolver = FakeResolver();
    h = BgtubeAudioHandler(resolver: resolver, engine: engine);
  });

  Future<void> loaded(String id) async {
    final f = h.playVideo(id);
    await settle();
    resolver.pending[id]!.last.complete(audio(id));
    await f;
    engine.emitReady();
    await settle();
  }

  test('newer request wins; late result of the older one is ignored', () async {
    final a = h.playVideo('AAAAAAAAAAA');
    await settle();
    final b = h.playVideo('BBBBBBBBBBB');
    await settle();
    resolver.pending['BBBBBBBBBBB']!.single.complete(audio('BBBBBBBBBBB'));
    await b;
    resolver.pending['AAAAAAAAAAA']!.single.complete(audio('AAAAAAAAAAA'));
    await a;
    expect(engine.setUrls.map((e) => e.url.path), ['/BBBBBBBBBBB']);
    expect(h.nowPlaying.value!.videoId, 'BBBBBBBBBBB');
    expect(h.resolving.value, isFalse);
  });

  test('old audio is stopped as soon as a new video starts resolving', () async {
    await loaded('AAAAAAAAAAA');
    final stopsBefore = engine.stops;
    final f = h.playVideo('BBBBBBBBBBB');
    await settle();
    expect(engine.stops, stopsBefore + 1);
    resolver.pending['BBBBBBBBBBB']!.single.complete(audio('BBBBBBBBBBB'));
    await f;
  });

  test('new video starts from zero even if previous was at 30s', () async {
    await loaded('AAAAAAAAAAA');
    engine.position = const Duration(seconds: 30);
    final f = h.playVideo('BBBBBBBBBBB');
    await settle();
    resolver.pending['BBBBBBBBBBB']!.single.complete(audio('BBBBBBBBBBB'));
    await f;
    expect(engine.setUrls.last.start, Duration.zero);
  });

  test('extractor failure publishes failure, does not throw, stops audio', () async {
    resolver.immediate = (_) async => throw const AppFailure(FailureKind.extractionFailed);
    await h.playVideo('AAAAAAAAAAA'); // لا يرمي
    expect(h.failure.value?.kind, FailureKind.extractionFailed);
    expect(h.resolving.value, isFalse);
    expect(engine.setUrls, isEmpty);
    expect(engine.log.last, 'stop');
  });

  test('failed first load of new video retries from zero, not engine position', () async {
    await loaded('AAAAAAAAAAA');
    engine.position = const Duration(seconds: 30);
    resolver.immediate = (_) async => throw const AppFailure(FailureKind.network);
    await h.playVideo('BBBBBBBBBBB');
    expect(h.failure.value?.kind, FailureKind.network);
    engine.position = const Duration(seconds: 99);
    resolver.immediate = (id) async => audio(id);
    await h.retry();
    expect(h.failure.value, isNull);
    expect(engine.setUrls.last.start, Duration.zero);
    expect(engine.setUrls.last.url.path, '/BBBBBBBBBBB');
  });

  test('retry keeps position of a video that had started playing', () async {
    await loaded('AAAAAAAAAAA');
    engine.position = const Duration(seconds: 42);
    resolver.immediate = (_) async => throw const AppFailure(FailureKind.network);
    await h.retry();
    expect(h.failure.value, isNotNull);
    resolver.immediate = (id) async => audio(id);
    await h.retry();
    expect(engine.setUrls.last.start, const Duration(seconds: 42));
  });

  test('retry without a previous video does nothing', () async {
    await h.retry();
    expect(resolver.calls, isEmpty);
    expect(h.failure.value, isNull);
    expect(engine.log, isEmpty);
  });

  test('stop while resolving cancels the load', () async {
    final f = h.playVideo('AAAAAAAAAAA');
    await settle();
    await h.stop();
    resolver.pending['AAAAAAAAAAA']!.single.complete(audio('AAAAAAAAAAA'));
    await f;
    expect(engine.setUrls, isEmpty);
    expect(h.resolving.value, isFalse);
    expect(h.nowPlaying.value, isNull);
    expect(h.failure.value, isNull);
    await h.retry(); // لا فيديو بعد الإيقاف
    expect(resolver.calls, ['AAAAAAAAAAA']);
  });

  test('stop clears nowPlaying', () async {
    await loaded('AAAAAAAAAAA');
    expect(h.nowPlaying.value, isNotNull);
    await h.stop();
    expect(h.nowPlaying.value, isNull);
  });

  test('player error triggers exactly one automatic retry at the same position', () async {
    resolver.immediate = (id) async => audio(id);
    await h.playVideo('AAAAAAAAAAA');
    engine.emitReady();
    await settle();
    engine.position = const Duration(seconds: 30);
    engine.emitError();
    await settle();
    expect(resolver.calls.length, 2);
    expect(engine.setUrls.last.start, const Duration(seconds: 30));
    // خطأ ثانٍ بلا ready بينهما: فشل ظاهر.
    engine.emitError();
    await settle();
    expect(resolver.calls.length, 2);
    expect(h.failure.value?.kind, FailureKind.playbackFailed);
    expect(engine.log.last, 'stop');
  });

  test('ready resets the automatic retry allowance', () async {
    resolver.immediate = (id) async => audio(id);
    await h.playVideo('AAAAAAAAAAA');
    engine.emitReady();
    engine.emitError();
    await settle();
    expect(resolver.calls.length, 2);
    engine.emitReady();
    await settle();
    engine.emitError();
    await settle();
    expect(resolver.calls.length, 3);
    expect(h.failure.value, isNull);
  });

  test('manual retry resets the automatic retry allowance', () async {
    resolver.immediate = (id) async => audio(id);
    await h.playVideo('AAAAAAAAAAA');
    engine.emitError();
    await settle();
    engine.emitError();
    await settle();
    expect(h.failure.value, isNotNull);
    final before = resolver.calls.length;
    await h.retry();
    engine.emitError();
    await settle();
    expect(resolver.calls.length, before + 2); // يدوية + تلقائية جديدة
    expect(h.failure.value, isNull);
  });

  test('race: setUrl throws and the event stream errors too -> handled once', () async {
    resolver.immediate = (id) async => audio(id);
    var first = true;
    engine.onSetUrl = (_) async {
      if (first) {
        first = false;
        engine.emitError(); // التيار يخطئ أثناء التحميل
        await settle();
        throw PlayerException(0, 'boom', null); // ثم يرمي setUrl نفسه
      }
    };
    await h.playVideo('AAAAAAAAAAA');
    await settle();
    expect(resolver.calls.length, 2); // محاولة تلقائية واحدة فقط
    expect(h.failure.value, isNull);
    expect(engine.setUrls.length, 2);
  });

  test('stale player error after stop is ignored', () async {
    await loaded('AAAAAAAAAAA');
    await h.stop();
    engine.emitError();
    await settle();
    expect(resolver.calls.length, 1);
    expect(h.failure.value, isNull);
  });

  group('position saving', () {
    late FakeRepo repo;
    late BgtubeAudioHandler p;
    const a = 'AAAAAAAAAAA';
    const b = 'BBBBBBBBBBB';

    setUp(() {
      repo = FakeRepo();
      resolver.immediate = (id) async => audio(id);
      p = BgtubeAudioHandler(
        resolver: resolver,
        engine: engine,
        positions: repo,
        saveInterval: const Duration(milliseconds: 20),
      );
    });

    Future<void> start(String id) async {
      await p.playVideo(id);
      engine.emitReady();
      engine.playingCtl.add(true);
      await settle();
    }

    test('stopping mid-video then reopening resumes from the saved spot (1:30)', () async {
      await start(a);
      engine.position = const Duration(
        minutes: 1,
        seconds: 30,
      ); // مدة الصوت 3 دقائق
      await p.stop();
      expect(repo.store[a]!.position, const Duration(seconds: 90));
      await p.playVideo(a);
      expect(engine.setUrls.last.start, const Duration(seconds: 90));
    });

    test('pause saves the position', () async {
      await start(a);
      engine.position = const Duration(seconds: 45);
      engine.playingCtl.add(false);
      await settle();
      expect(repo.store[a]!.position, const Duration(seconds: 45));
    });

    test('periodic save while playing', () async {
      await start(a);
      engine.position = const Duration(seconds: 20);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(repo.store[a]!.position, const Duration(seconds: 20));
      await p.stop();
    });

    test('under 10 seconds is not saved', () async {
      await start(a);
      engine.position = const Duration(seconds: 9);
      await p.stop();
      expect(repo.store, isEmpty);
    });

    test('near the end deletes the saved position', () async {
      repo.store[a] = PlaybackPosition(
        videoId: a,
        position: const Duration(seconds: 60),
        duration: const Duration(minutes: 3),
        updatedAt: DateTime.utc(2026),
      );
      await start(a);
      engine.position = const Duration(minutes: 2, seconds: 55);
      await p.stop();
      expect(repo.store, isEmpty);
    });

    test('completion deletes the saved position', () async {
      await start(a);
      engine.position = const Duration(seconds: 60);
      engine.playingCtl.add(false);
      await settle();
      expect(repo.store[a], isNotNull);
      engine.events.add(
        PlaybackEvent(processingState: ProcessingState.completed),
      );
      await settle();
      expect(repo.store[a], isNull);
    });

    test('switching video saves the old one and starts the new one from its own saved spot', () async {
      repo.store[b] = PlaybackPosition(
        videoId: b,
        position: const Duration(seconds: 33),
        duration: const Duration(minutes: 3),
        updatedAt: DateTime.utc(2026),
      );
      await start(a);
      engine.position = const Duration(seconds: 70);
      await p.playVideo(b);
      expect(repo.store[a]!.position, const Duration(seconds: 70));
      expect(engine.setUrls.last.start, const Duration(seconds: 33));
    });

    test('video with nothing saved starts from zero', () async {
      await start(a);
      expect(engine.setUrls.last.start, Duration.zero);
    });

    test('storage failures never break playback', () async {
      repo.failing = true;
      await start(a);
      expect(engine.setUrls.last.start, Duration.zero);
      engine.position = const Duration(seconds: 50);
      await p.stop();
      expect(p.failure.value, isNull);
      await p.playVideo(b);
      expect(p.failure.value, isNull);
      expect(engine.setUrls.last.url.path, '/$b');
    });

    test('nothing is saved while a video failed to load', () async {
      resolver.immediate = (_) async =>
          throw const AppFailure(FailureKind.network);
      await p.playVideo(a);
      engine.position = const Duration(seconds: 50);
      engine.playingCtl.add(false);
      await settle();
      expect(repo.store, isEmpty);
    });

    test('stop() while the previous video save is pending does not start the new video', () async {
      await start(a);
      engine.position = const Duration(seconds: 50);
      repo.saveGate = Completer<void>();
      final playing = p.playVideo(b); // ينتظر حفظ A
      await settle();
      final stopping = p.stop();
      await settle();
      repo.saveGate!.complete();
      await playing;
      await stopping;
      expect(resolver.calls, [a], reason: 'B must never be resolved');
      expect(engine.setUrls.length, 1);
      expect(engine.playing, isFalse);
      expect(p.nowPlaying.value, isNull);
      expect(p.resolving.value, isFalse);
    });

    test('periodic save timer is cancelled on completion', () async {
      await start(a);
      engine.position = const Duration(seconds: 60);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      engine.events.add(PlaybackEvent(processingState: ProcessingState.completed));
      await settle();
      final writesAfterCompletion = repo.writes;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(repo.writes, writesAfterCompletion);
      expect(repo.store[a], isNull);
    });

    test('returning to under 10s leaves the saved 5:00 untouched (D17)', () async {
      repo.store[a] = PlaybackPosition(
        videoId: a,
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 20),
        updatedAt: DateTime.utc(2026),
      );
      resolver.immediate = (id) async => ResolvedAudio(
            url: Uri.parse('https://example.com/$id'),
            title: 'T',
            duration: const Duration(minutes: 20),
          );
      await start(a);
      engine.position = const Duration(seconds: 4); // المستخدم رجع للبداية
      engine.playingCtl.add(false);
      await settle();
      await p.stop();
      expect(repo.store[a]!.position, const Duration(minutes: 5));
    });
  });

  group('speed', () {
    late FakeSpeedStore store;
    late BgtubeAudioHandler s;
    setUp(() {
      store = FakeSpeedStore();
      resolver.immediate = (id) async => audio(id);
      s = BgtubeAudioHandler(resolver: resolver, engine: engine, speedStore: store);
    });

    test('defaults to 1x when nothing is stored', () async {
      await settle();
      expect(s.speed.value, 1.0);
    });

    test('setSpeed applies to engine, notification state, and storage', () async {
      await s.setSpeed(1.5);
      expect(engine.speed, 1.5);
      expect(s.speed.value, 1.5);
      expect(s.playbackState.value.speed, 1.5);
      expect(store.stored, 1.5);
    });

    test('all five options are accepted', () async {
      for (final v in [0.75, 1.0, 1.25, 1.5, 2.0]) {
        await s.setSpeed(v);
        expect(engine.speed, v);
        expect(store.stored, v);
      }
    });

    test('invalid value falls back to 1x', () async {
      await s.setSpeed(7);
      expect(s.speed.value, 1.0);
      expect(engine.speed, 1.0);
    });

    test('stored speed is restored on startup', () async {
      store.stored = 1.25;
      final s2 = BgtubeAudioHandler(resolver: resolver, engine: engine, speedStore: store);
      await settle();
      await settle();
      expect(s2.speed.value, 1.25);
      expect(engine.speed, 1.25);
    });

    test('corrupt stored value falls back to 1x', () async {
      store.stored = 3.3;
      final s2 = BgtubeAudioHandler(resolver: resolver, engine: engine, speedStore: store);
      await settle();
      await settle();
      expect(s2.speed.value, 1.0);
    });

    test('user choice is not overwritten by a late storage read', () async {
      store.stored = 2.0;
      store.loadGate = Completer<void>();
      final s2 = BgtubeAudioHandler(resolver: resolver, engine: engine, speedStore: store);
      await s2.setSpeed(0.75);
      store.loadGate!.complete();
      await settle();
      await settle();
      expect(s2.speed.value, 0.75);
      expect(engine.speed, 0.75);
    });

    test('speed persists to the next video and is applied after loading it', () async {
      await s.setSpeed(1.5);
      await s.playVideo('AAAAAAAAAAA');
      expect(engine.speedCalls.last, 1.5);
      expect(engine.log.indexOf('setUrl'), lessThan(engine.log.length));
      engine.speed = 1.0; // المحرك أُعيد ضبطه
      await s.playVideo('BBBBBBBBBBB');
      expect(engine.speed, 1.5);
      expect(s.speed.value, 1.5);
    });

    test('speed change while paused is also reflected in the notification', () async {
      await s.playVideo('AAAAAAAAAAA');
      await s.setSpeed(2.0);
      expect(s.playbackState.value.speed, 2.0);
    });

    test('storage failure does not break changing speed', () async {
      store.failing = true;
      await s.setSpeed(1.25);
      expect(engine.speed, 1.25);
      expect(s.speed.value, 1.25);
    });
  });

  group('sleep timer (fake clock)', () {
    const a = 'AAAAAAAAAAA';
    late FakeRepo repo;
    late BgtubeAudioHandler t;

    // يبدأ فيديو ويعتبره يعمل (play استُدعي في المحرّك الوهمي).
    Future<void> startPlaying(FakeAsync fa) async {
      unawaited(t.playVideo(a));
      fa.flushMicrotasks();
      fa.flushTimers(flushPeriodicTimers: false);
      fa.flushMicrotasks();
      engine.emitReady();
      fa.flushMicrotasks();
    }

    setUp(() {
      repo = FakeRepo();
      resolver.immediate = (id) async => audio(id);
      t = BgtubeAudioHandler(resolver: resolver, engine: engine, positions: repo);
    });

    test('start shows remaining and counts down', () {
      fakeAsync((fa) {
        t.startSleepTimer(const Duration(minutes: 15));
        expect(t.sleepRemaining.value, const Duration(minutes: 15));
        fa.elapse(const Duration(minutes: 1));
        expect(t.sleepRemaining.value, const Duration(minutes: 14));
        t.cancelSleepTimer();
      });
    });

    test('fades gradually over the last 10s, then pauses and saves position', () {
      fakeAsync((fa) {
        startPlaying(fa);
        engine.position = const Duration(minutes: 1);
        engine.volumes.clear();
        t.startSleepTimer(const Duration(seconds: 30));
        fa.elapse(const Duration(seconds: 19));
        expect(engine.volumes.where((v) => v < 1), isEmpty); // لا تلاشي قبل آخر ١٠ ث
        fa.elapse(const Duration(seconds: 5)); // متبقٍ ٦ ث
        final mid = engine.volumes.last;
        expect(mid, inInclusiveRange(0.5, 0.7));
        expect(engine.log.contains('pause'), isFalse);
        fa.elapse(const Duration(seconds: 7));
        final fade = engine.volumes.where((v) => v < 1).toList();
        for (var i = 1; i < fade.length; i++) {
          expect(fade[i], lessThanOrEqualTo(fade[i - 1])); // تنازلي
        }
        expect(engine.log.last == 'pause' || engine.log.contains('pause'), isTrue);
        expect(engine.playing, isFalse);
        expect(engine.volumes.last, 1.0); // يعود الصوت بعد الإيقاف
        expect(t.sleepRemaining.value, isNull);
        expect(repo.store[a]!.position, const Duration(minutes: 1));
      });
    });

    test('cancel stops the countdown, restores volume, never pauses', () {
      fakeAsync((fa) {
        startPlaying(fa);
        t.startSleepTimer(const Duration(seconds: 30));
        fa.elapse(const Duration(seconds: 25)); // داخل التلاشي
        t.cancelSleepTimer();
        expect(t.sleepRemaining.value, isNull);
        expect(engine.volumes.last, 1.0);
        fa.elapse(const Duration(minutes: 5));
        expect(engine.log.contains('pause'), isFalse);
        expect(engine.playing, isTrue);
      });
    });

    test('switching video keeps the timer running and it still stops playback', () {
      fakeAsync((fa) {
        startPlaying(fa);
        t.startSleepTimer(const Duration(seconds: 30));
        fa.elapse(const Duration(seconds: 10));
        unawaited(t.playVideo('BBBBBBBBBBB'));
        fa.flushMicrotasks();
        engine.emitReady();
        fa.flushMicrotasks();
        expect(engine.playing, isTrue);
        expect(t.sleepRemaining.value, const Duration(seconds: 20));
        fa.elapse(const Duration(seconds: 21));
        expect(engine.playing, isFalse);
        expect(t.sleepRemaining.value, isNull);
      });
    });

    test('manual pause during timer: timer keeps going and ends cleanly', () {
      fakeAsync((fa) {
        startPlaying(fa);
        t.startSleepTimer(const Duration(seconds: 30));
        fa.elapse(const Duration(seconds: 5));
        unawaited(t.pause());
        fa.flushMicrotasks();
        final pauses = engine.log.where((e) => e == 'pause').length;
        expect(t.sleepRemaining.value, const Duration(seconds: 25));
        fa.elapse(const Duration(seconds: 26));
        expect(t.sleepRemaining.value, isNull);
        // لم يُرسَل إيقاف ثانٍ لأن المحرّك متوقف أصلاً
        expect(engine.log.where((e) => e == 'pause').length, pauses);
        expect(engine.volumes.last, 1.0);
      });
    });

    test('manual stop cancels the timer', () {
      fakeAsync((fa) {
        startPlaying(fa);
        t.startSleepTimer(const Duration(seconds: 30));
        unawaited(t.stop());
        fa.flushMicrotasks();
        expect(t.sleepRemaining.value, isNull);
        fa.elapse(const Duration(minutes: 1));
        expect(engine.volumes.last, 1.0);
      });
    });

    test('playback can be resumed after the timer ends, at full volume', () {
      fakeAsync((fa) {
        startPlaying(fa);
        t.startSleepTimer(const Duration(seconds: 12));
        fa.elapse(const Duration(seconds: 13));
        expect(engine.playing, isFalse);
        unawaited(t.play());
        fa.flushMicrotasks();
        expect(engine.playing, isTrue);
        expect(engine.volumes.last, 1.0);
        fa.elapse(const Duration(minutes: 1));
        expect(engine.playing, isTrue); // لا مؤقت ثانٍ
      });
    });

    test('late ticks do not stretch the timer: remaining comes from absolute end time', () {
      fakeAsync((fa) {
        // ساعة قابلة للتقديم تُحاكي نبضات فائتة (الساعة تتقدم دون إطلاق المؤقتات).
        var skew = Duration.zero;
        final skewed = Clock(() => DateTime(2026).add(fa.elapsed + skew));
        withClock(skewed, () => t.startSleepTimer(const Duration(minutes: 15)));
        expect(t.sleepRemaining.value, const Duration(minutes: 15));
        skew = const Duration(minutes: 5); // ٥ دقائق مرّت دون أي نبضة
        fa.elapse(const Duration(milliseconds: 250)); // أول نبضة بعد التأخر
        // خصم 250ms لكل نبضة كان سيُظهر ١٥:٠٠ تقريباً؛ المطلق يُظهر ١٠:٠٠.
        expect(t.sleepRemaining.value, const Duration(minutes: 10));
        skew = const Duration(minutes: 15);
        fa.elapse(const Duration(milliseconds: 250));
        expect(t.sleepRemaining.value, isNull); // انتهى في وقته لا بعده
        t.cancelSleepTimer();
      });
    });

    test('timer expiring while a new video is still loading: no play() after load', () {
      fakeAsync((fa) {
        resolver.immediate = null;
        unawaited(t.playVideo('BBBBBBBBBBB'));
        fa.flushMicrotasks();
        expect(t.resolving.value, isTrue);
        expect(engine.playing, isFalse);
        t.startSleepTimer(const Duration(seconds: 12));
        fa.elapse(const Duration(seconds: 13)); // انتهى والتحميل لم يكتمل
        expect(t.sleepRemaining.value, isNull);
        resolver.pending['BBBBBBBBBBB']!.single.complete(audio('BBBBBBBBBBB'));
        fa.flushMicrotasks();
        expect(engine.log.contains('play'), isFalse);
        expect(engine.playing, isFalse);
        expect(engine.volumes.last, 1.0);
        expect(t.resolving.value, isFalse);
        // الاستئناف اليدوي يعمل بعدها.
        unawaited(t.play());
        fa.flushMicrotasks();
        expect(engine.playing, isTrue);
      });
    });

    test('a new user request after the timer expired plays normally', () {
      fakeAsync((fa) {
        resolver.immediate = null;
        unawaited(t.playVideo('BBBBBBBBBBB'));
        fa.flushMicrotasks();
        t.startSleepTimer(const Duration(seconds: 12));
        fa.elapse(const Duration(seconds: 13));
        resolver.pending['BBBBBBBBBBB']!.single.complete(audio('BBBBBBBBBBB'));
        fa.flushMicrotasks();
        resolver.immediate = (id) async => audio(id);
        unawaited(t.playVideo(a));
        fa.flushMicrotasks();
        expect(engine.playing, isTrue);
      });
    });

    test('starting a new timer replaces the old one', () {
      fakeAsync((fa) {
        t.startSleepTimer(const Duration(minutes: 15));
        t.startSleepTimer(const Duration(minutes: 60));
        expect(t.sleepRemaining.value, const Duration(minutes: 60));
        fa.elapse(const Duration(minutes: 16));
        expect(t.sleepRemaining.value, const Duration(minutes: 44));
        t.cancelSleepTimer();
      });
    });
  });

  group('playback diagnostics (D24)', () {
    late FakeResolver r;
    late FakeEngine e;
    late BgtubeAudioHandler d;
    final probed = <({Uri url, Map<String, String> headers})>[];
    const ua = {'User-Agent': 'com.google.android.youtube/x'};

    ResolvedAudio diagAudio(String id) => ResolvedAudio(
          url: Uri.parse('https://rr1.googlevideo.com/videoplayback?id=$id&sig=SECRET&c=ANDROID'),
          title: 'T',
          httpHeaders: ua,
          sourceInfo: 'ANDROID itag140 mp4a.40.2 ip6',
        );

    setUp(() {
      probed.clear();
      r = FakeResolver()..immediate = (id) async => diagAudio(id);
      e = FakeEngine();
      d = BgtubeAudioHandler(
        resolver: r,
        engine: e,
        probe: (url, headers) async {
          probed.add((url: url, headers: headers));
          return 'probe HTTP 403';
        },
      );
    });

    test('resolver headers are passed to the engine on every load', () async {
      await d.playVideo('AAAAAAAAAAA');
      e.emitError(); // محاولة تلقائية
      await settle();
      expect(e.setHeaders, [ua, ua]);
    });

    test('final playback failure carries player error, probe and source info', () async {
      await d.playVideo('AAAAAAAAAAA');
      e.emitError();
      await settle();
      expect(probed, isEmpty); // لا فحص في المحاولة التلقائية
      e.emitError();
      await settle();
      await settle();
      final f = d.failure.value!;
      expect(f.kind, FailureKind.playbackFailed);
      expect(f.debugDetail, 'PlayerException(0) boom · probe HTTP 403 · ANDROID itag140 mp4a.40.2 ip6');
      expect(probed.single.headers, ua);
      expect(f.debugDetail, isNot(contains('SECRET')));
      expect(f.debugDetail, isNot(contains('http')));
    });

    test('setUrl throwing twice still produces a detailed failure', () async {
      e.onSetUrl = (_) async => throw PlayerException(1, 'MediaCodecAudioRenderer error, see https://x.googlevideo.com/a?sig=Z', null);
      await d.playVideo('AAAAAAAAAAA');
      await settle();
      final detail = d.failure.value!.debugDetail!;
      expect(detail, startsWith('PlayerException(1) MediaCodecAudioRenderer error'));
      expect(detail, isNot(contains('sig=Z')));
      expect(detail, contains('probe HTTP 403'));
    });

    test('failure shows immediately; the probe result is added when it arrives', () async {
      final gate = Completer<String>();
      d = BgtubeAudioHandler(resolver: r, engine: e, probe: (_, _) => gate.future);
      await d.playVideo('AAAAAAAAAAA');
      e.emitError();
      await settle();
      e.emitError();
      await settle();
      // لا انتظار للفحص قبل إظهار الفشل.
      expect(d.failure.value?.kind, FailureKind.playbackFailed);
      expect(d.failure.value?.debugDetail, 'PlayerException(0) boom · ANDROID itag140 mp4a.40.2 ip6');
      gate.complete('probe HTTP 206');
      await settle();
      expect(d.failure.value?.debugDetail, 'PlayerException(0) boom · probe HTTP 206 · ANDROID itag140 mp4a.40.2 ip6');
    });

    test('success path never probes', () async {
      await d.playVideo('AAAAAAAAAAA');
      e.emitReady();
      await settle();
      expect(probed, isEmpty);
      expect(e.log, contains('play'));
    });

    test('manual retry during the probe: late probe result does not resurrect the failure', () async {
      final gate = Completer<String>();
      d = BgtubeAudioHandler(resolver: r, engine: e, probe: (_, _) => gate.future);
      await d.playVideo('AAAAAAAAAAA');
      e.emitError();
      await settle();
      e.emitError();
      await settle();
      await d.retry();
      gate.complete('probe HTTP 403');
      await settle();
      expect(d.failure.value, isNull);
    });

    test('a newer request during the probe wins (no stale failure)', () async {
      final gate = Completer<String>();
      d = BgtubeAudioHandler(resolver: r, engine: e, probe: (_, _) => gate.future);
      await d.playVideo('AAAAAAAAAAA');
      e.emitError();
      await settle();
      e.emitError();
      await settle();
      r.immediate = (id) async => diagAudio(id);
      final next = d.playVideo('BBBBBBBBBBB');
      gate.complete('probe HTTP 200');
      await next;
      await settle();
      expect(d.failure.value, isNull);
      expect(e.setUrls.last.url.queryParameters['id'], 'BBBBBBBBBBB');
    });

    test('the proxy\'s last source error is part of the detail', () async {
      e.sourceErrorDetail = 'proxy UnknownLengthException';
      await d.playVideo('AAAAAAAAAAA');
      e.emitError();
      await settle();
      e.emitError();
      await settle();
      await settle();
      expect(d.failure.value!.debugDetail,
          'PlayerException(0) boom · proxy UnknownLengthException · probe HTTP 403 · ANDROID itag140 mp4a.40.2 ip6');
    });

    test('no probe configured -> detail without probe part', () async {
      d = BgtubeAudioHandler(resolver: r, engine: e);
      await d.playVideo('AAAAAAAAAAA');
      e.emitError();
      await settle();
      e.emitError();
      await settle();
      expect(d.failure.value!.debugDetail, 'PlayerException(0) boom · ANDROID itag140 mp4a.40.2 ip6');
    });
  });

  group('late metadata and player duration (D26)', () {
    late FakeResolver r;
    late FakeEngine e;
    late BgtubeAudioHandler d;

    setUp(() {
      r = FakeResolver();
      e = FakeEngine();
      d = BgtubeAudioHandler(resolver: r, engine: e);
    });

    ResolvedAudio quick(String id, Future<AudioMetadata?> late) => ResolvedAudio(
          url: Uri.parse('https://example.com/$id'),
          title: id, // المعرّف عنواناً مؤقتاً
          lateMetadata: late,
        );

    test('metadata arriving after playback started updates nowPlaying and the notification', () async {
      final late = Completer<AudioMetadata?>();
      r.immediate = (id) async => quick(id, late.future);
      await d.playVideo('AAAAAAAAAAA');
      expect(e.log, contains('play')); // التشغيل لم ينتظر البيانات
      expect(d.nowPlaying.value?.title, 'AAAAAAAAAAA');
      late.complete(const AudioMetadata(
        title: 'Real title',
        author: 'Channel',
        duration: Duration(minutes: 4),
        thumbnailUrl: 'https://i.ytimg.com/x.jpg',
      ));
      await settle();
      expect(d.nowPlaying.value?.title, 'Real title');
      expect(d.nowPlaying.value?.author, 'Channel');
      expect(d.nowPlaying.value?.duration, const Duration(minutes: 4));
      final item = d.mediaItem.value!;
      expect(item.title, 'Real title');
      expect(item.artist, 'Channel');
      expect(item.artUri, Uri.parse('https://i.ytimg.com/x.jpg'));
    });

    test('late metadata of a previous video is ignored', () async {
      final lateA = Completer<AudioMetadata?>();
      r.immediate = (id) async => quick(id, id == 'AAAAAAAAAAA' ? lateA.future : Completer<AudioMetadata?>().future);
      await d.playVideo('AAAAAAAAAAA');
      await d.playVideo('BBBBBBBBBBB');
      lateA.complete(const AudioMetadata(title: 'Old A'));
      await settle();
      expect(d.nowPlaying.value?.videoId, 'BBBBBBBBBBB');
      expect(d.nowPlaying.value?.title, 'BBBBBBBBBBB');
      expect(d.mediaItem.value?.title, 'BBBBBBBBBBB');
    });

    test('failed late metadata leaves the id title, no crash', () async {
      r.immediate = (id) async => quick(id, Future<AudioMetadata?>.value(null));
      await d.playVideo('AAAAAAAAAAA');
      await settle();
      expect(d.nowPlaying.value?.title, 'AAAAAAAAAAA');
    });

    test('player duration fills nowPlaying and mediaItem (progress, notification, PositionPolicy)', () async {
      r.immediate = (id) async => quick(id, Completer<AudioMetadata?>().future);
      await d.playVideo('AAAAAAAAAAA');
      expect(d.nowPlaying.value?.duration, isNull);
      e.durationCtl.add(const Duration(minutes: 3, seconds: 33));
      await settle();
      expect(d.nowPlaying.value?.duration, const Duration(minutes: 3, seconds: 33));
      expect(d.mediaItem.value?.duration, const Duration(minutes: 3, seconds: 33));
      e.durationCtl.add(null); // تجاهل
      await settle();
      expect(d.nowPlaying.value?.duration, const Duration(minutes: 3, seconds: 33));
    });

    test('player duration wins over late metadata duration', () async {
      final late = Completer<AudioMetadata?>();
      r.immediate = (id) async => quick(id, late.future);
      await d.playVideo('AAAAAAAAAAA');
      e.durationCtl.add(const Duration(seconds: 200));
      await settle();
      late.complete(const AudioMetadata(title: 'T', duration: Duration(seconds: 199)));
      await settle();
      expect(d.nowPlaying.value?.duration, const Duration(seconds: 200));
      expect(d.nowPlaying.value?.title, 'T');
    });
  });
}
