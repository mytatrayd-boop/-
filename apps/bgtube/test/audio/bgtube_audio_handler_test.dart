import 'dart:async';

import 'package:bgtube/audio/audio_engine.dart';
import 'package:bgtube/audio/bgtube_audio_handler.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/domain/models/resolved_audio.dart';
import 'package:bgtube/domain/ports/audio_source_resolver.dart';
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

  @override
  Future<void> setUrl(Uri url, {required Duration initialPosition}) async {
    log.add('setUrl');
    setUrls.add((url: url, start: initialPosition));
    await onSetUrl?.call(url);
  }

  @override
  Future<void> play() async {
    log.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async => log.add('pause');
  @override
  Future<void> stop() async {
    log.add('stop');
    playing = false;
  }

  @override
  Future<void> seek(Duration position) async {}
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
}
