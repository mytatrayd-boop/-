import 'dart:async';

import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/data/extractor/youtube_explode_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// AudioTrack غير مُصدَّر من المكتبة؛ يلزم للاختبار فقط.
// ignore: implementation_imports
import 'package:youtube_explode_dart/src/videos/streams/models/audio_track.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class MockYt extends Mock implements YoutubeExplode {}

class MockVideos extends Mock implements VideoClient {}

class MockStreams extends Mock implements StreamClient {}

class MockVideo extends Mock implements Video {}

class MockThumbs extends Mock implements ThumbnailSet {}

class MockAudio extends Mock implements AudioOnlyStreamInfo {}

const androidUa = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

AudioOnlyStreamInfo stream(
  int tag, {
  required StreamContainer container,
  required String codec,
  required int bps,
  String client = 'ANDROID',
  AudioTrack? track,
}) {
  final s = MockAudio();
  when(() => s.tag).thenReturn(tag);
  when(() => s.container).thenReturn(container);
  when(() => s.audioCodec).thenReturn(codec);
  when(() => s.bitrate).thenReturn(Bitrate(bps));
  when(() => s.fragments).thenReturn(const []);
  when(() => s.audioTrack).thenReturn(track);
  when(() => s.url).thenReturn(
    Uri.parse('https://rr1.googlevideo.com/videoplayback?expire=1700000000&itag=$tag&c=$client&ip=2001:db8::1&sig=SECRET'),
  );
  return s;
}

final opus251 = stream(251, container: StreamContainer.webM, codec: 'opus', bps: 160000);
final m4a140 = stream(140, container: StreamContainer.mp4, codec: 'mp4a.40.2', bps: 130000);
final m4a139 = stream(139, container: StreamContainer.mp4, codec: 'mp4a.40.5', bps: 48000);

void main() {
  group('pickAudioStream', () {
    test('prefers m4a/AAC over higher-bitrate webm/opus', () {
      expect(pickAudioStream([opus251, m4a139, m4a140])?.tag, 140);
    });
    test('falls back to the highest bitrate when no m4a exists', () {
      final low = stream(249, container: StreamContainer.webM, codec: 'opus', bps: 50000);
      expect(pickAudioStream([low, opus251])?.tag, 251);
    });
    test('prefers the original audio track over dubbed ones', () {
      final dub = stream(
        140,
        container: StreamContainer.mp4,
        codec: 'mp4a.40.2',
        bps: 200000,
        track: const AudioTrack(displayName: 'Dub', id: 'x', audioIsDefault: false),
      );
      final orig = stream(
        139,
        container: StreamContainer.mp4,
        codec: 'mp4a.40.5',
        bps: 48000,
        track: const AudioTrack(displayName: 'Orig', id: 'y', audioIsDefault: true),
      );
      expect(pickAudioStream([dub, orig])?.tag, 139);
    });
    test('null for no streams', () => expect(pickAudioStream(const []), isNull));
  });

  group('headersForStreamUrl', () {
    test('ANDROID url gets the android app user-agent from the library', () {
      expect(
        headersForStreamUrl(Uri.parse('https://x.googlevideo.com/videoplayback?c=ANDROID')),
        {'User-Agent': androidUa},
      );
    });
    test('IOS url gets the iOS user-agent', () {
      final h = headersForStreamUrl(Uri.parse('https://x/v?c=IOS'));
      expect(h['User-Agent'], startsWith('com.google.ios.youtube/'));
    });
    test('ANDROID_VR url gets the VR user-agent with the library clientVersion', () {
      expect(headersForStreamUrl(Uri.parse('https://x.googlevideo.com/videoplayback?c=ANDROID_VR')), {
        'User-Agent': 'com.google.android.apps.youtube.vr.oculus/1.56.21 '
            '(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      });
    });
    test('unknown or missing client -> no headers (player default)', () {
      expect(headersForStreamUrl(Uri.parse('https://x/v?c=MWEB')), isEmpty);
      expect(headersForStreamUrl(Uri.parse('https://x/v')), isEmpty);
    });
    test('only User-Agent, never cookies or auth', () {
      for (final c in ['ANDROID', 'IOS', 'WEB', 'TVHTML5', 'ANDROID_VR', 'MWEB', '']) {
        final h = headersForStreamUrl(Uri.parse('https://x/v?c=$c'));
        expect(h.keys.every((k) => k == 'User-Agent'), isTrue, reason: c);
        final lower = h.keys.map((k) => k.toLowerCase());
        expect(lower, isNot(contains('authorization')), reason: c);
        expect(lower, isNot(contains('cookie')), reason: c);
      }
    });
  });

  test('sourceInfoFor is short and has no url or signature', () {
    final info = sourceInfoFor(m4a140);
    expect(info, 'ANDROID itag140 mp4a.40.2 ip6');
    expect(info, isNot(contains('SECRET')));
  });

  group('extractionDetail', () {
    test('type plus HTTP status from message', () {
      expect(
        extractionDetail(YoutubeExplodeException('Video abc returned 403 (stream: 18)')),
        'YoutubeExplodeException HTTP 403',
      );
    });
    test('type only when no status', () {
      expect(extractionDetail(VideoUnavailableException('gone')), 'VideoUnavailableException');
    });
  });

  group('resolver with fake client', () {
    late MockYt yt;
    late MockVideos videos;
    late MockStreams streams;
    late DateTime now;
    final calls = <List<YoutubeApiClient>?>[];

    setUp(() {
      yt = MockYt();
      videos = MockVideos();
      streams = MockStreams();
      now = DateTime(2026, 11, 26, 10);
      calls.clear();
      final video = MockVideo();
      final thumbs = MockThumbs();
      when(() => thumbs.highResUrl).thenReturn('https://i.ytimg.com/x.jpg');
      when(() => video.title).thenReturn('Title');
      when(() => video.author).thenReturn('Author');
      when(() => video.duration).thenReturn(const Duration(minutes: 3));
      when(() => video.thumbnails).thenReturn(thumbs);
      when(() => yt.videos).thenReturn(videos);
      when(() => videos.streamsClient).thenReturn(streams);
      when(() => videos.get(any())).thenAnswer((_) async => video);
      when(() => streams.getManifest(any(), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage'))).thenAnswer((inv) async {
        calls.add(inv.namedArguments[#ytClients] as List<YoutubeApiClient>?);
        return StreamManifest([opus251, m4a140]);
      });
    });

    YoutubeExplodeResolver resolver() => YoutubeExplodeResolver(client: yt, now: () => now);

    test('returns m4a with matching user-agent and diagnostics', () async {
      final a = await resolver().resolve('dQw4w9WgXcQ');
      expect(a.url.queryParameters['itag'], '140');
      expect(a.httpHeaders, {'User-Agent': androidUa});
      expect(a.sourceInfo, 'ANDROID itag140 mp4a.40.2 ip6');
      expect(a.expiresAt, isNotNull);
      expect(calls, [null]); // إدارة المكتبة الافتراضية أولاً
    });

    test('re-resolving the same video soon rotates to the next client set', () async {
      final r = resolver();
      await r.resolve('dQw4w9WgXcQ');
      now = now.add(const Duration(seconds: 10));
      await r.resolve('dQw4w9WgXcQ');
      now = now.add(const Duration(seconds: 10));
      await r.resolve('dQw4w9WgXcQ');
      now = now.add(const Duration(seconds: 10));
      await r.resolve('dQw4w9WgXcQ');
      expect(calls, [
        null,
        [YoutubeApiClient.ios],
        [YoutubeApiClient.androidVr],
        null,
      ]);
    });

    test('a different video or a late replay starts from the default again', () async {
      final r = resolver();
      await r.resolve('dQw4w9WgXcQ');
      await r.resolve('aaaaaaaaaaa');
      now = now.add(const Duration(minutes: 5));
      await r.resolve('aaaaaaaaaaa');
      expect(calls, [null, null, null]);
    });

    test('alternative client failing falls back to the default once', () async {
      final r = resolver();
      await r.resolve('dQw4w9WgXcQ');
      when(() => streams.getManifest(any(), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage'))).thenAnswer((inv) async {
        final c = inv.namedArguments[#ytClients] as List<YoutubeApiClient>?;
        calls.add(c);
        if (c != null) throw VideoUnavailableException('ios refused');
        return StreamManifest([m4a140]);
      });
      final a = await r.resolve('dQw4w9WgXcQ');
      expect(a.url.queryParameters['itag'], '140');
      expect(calls.skip(1), [
        [YoutubeApiClient.ios],
        null,
      ]);
    });

    test('fallback path is getManifest(videoId, requireWatchPage: false) with the library default', () async {
      final r = resolver();
      await r.resolve('dQw4w9WgXcQ'); // الأول افتراضي؛ الثاني ios
      final seen = <(Object?, List<YoutubeApiClient>?, bool)>[];
      when(() => streams.getManifest(any(),
          ytClients: any(named: 'ytClients'),
          requireWatchPage: any(named: 'requireWatchPage'))).thenAnswer((inv) async {
        final c = inv.namedArguments[#ytClients] as List<YoutubeApiClient>?;
        seen.add((inv.positionalArguments.first, c, inv.namedArguments[#requireWatchPage] as bool));
        if (c != null) throw VideoUnavailableException('ios refused');
        return StreamManifest([m4a140]);
      });
      await r.resolve('dQw4w9WgXcQ');
      expect(seen.length, 2);
      expect(seen[0].$1, 'dQw4w9WgXcQ');
      expect(seen[0].$2, [YoutubeApiClient.ios]);
      expect(seen[0].$3, isFalse);
      expect(seen[1], ('dQw4w9WgXcQ', null, false));
    });

    test('extraction failure detail has type and HTTP status, no message text', () async {
      when(() => streams.getManifest(any(), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage')))
          .thenThrow(YoutubeExplodeException('Video dQw4w9WgXcQ returned 403 (stream: 140) https://x/y?sig=S'));
      await expectLater(
        resolver().resolve('dQw4w9WgXcQ'),
        throwsA(isA<AppFailure>()
            .having((f) => f.kind, 'kind', FailureKind.extractionFailed)
            .having((f) => f.debugDetail, 'detail', 'YoutubeExplodeException HTTP 403')),
      );
    });

    test('manifest is fetched without the watch page, in parallel with metadata', () async {
      final videoGate = Completer<Video>();
      when(() => videos.get(any())).thenAnswer((_) => videoGate.future);
      final watchPage = <bool>[];
      when(() => streams.getManifest(any(),
          ytClients: any(named: 'ytClients'),
          requireWatchPage: any(named: 'requireWatchPage'))).thenAnswer((inv) async {
        watchPage.add(inv.namedArguments[#requireWatchPage] as bool);
        return StreamManifest([m4a140]);
      });
      final pending = resolver().resolve('dQw4w9WgXcQ');
      await pumpEventQueue();
      // الـmanifest طُلب قبل اكتمال البيانات الوصفية (لا تسلسل).
      expect(watchPage, [false]);
      final v = MockVideo();
      final thumbs = MockThumbs();
      when(() => thumbs.highResUrl).thenReturn('t');
      when(() => v.title).thenReturn('Late');
      when(() => v.author).thenReturn('A');
      when(() => v.duration).thenReturn(null);
      when(() => v.thumbnails).thenReturn(thumbs);
      videoGate.complete(v);
      expect((await pending).title, 'Late');
    });

    test('slow metadata does not hold playback beyond the grace period', () async {
      when(() => videos.get(any())).thenAnswer((_) => Completer<Video>().future);
      final r = YoutubeExplodeResolver(client: yt, now: () => now, metadataGrace: const Duration(milliseconds: 20));
      final a = await r.resolve('dQw4w9WgXcQ');
      expect(a.title, 'dQw4w9WgXcQ');
      expect(a.url.queryParameters['itag'], '140');
      expect(a.lateMetadata, isNotNull);
    });

    test('late metadata is delivered when it finally arrives (not dropped)', () async {
      final gate = Completer<Video>();
      when(() => videos.get(any())).thenAnswer((_) => gate.future);
      final r = YoutubeExplodeResolver(client: yt, now: () => now, metadataGrace: const Duration(milliseconds: 20));
      final a = await r.resolve('dQw4w9WgXcQ');
      final v = MockVideo();
      final thumbs = MockThumbs();
      when(() => thumbs.highResUrl).thenReturn('https://i.ytimg.com/late.jpg');
      when(() => v.title).thenReturn('Late title');
      when(() => v.author).thenReturn('Late author');
      when(() => v.duration).thenReturn(const Duration(minutes: 5));
      when(() => v.thumbnails).thenReturn(thumbs);
      gate.complete(v);
      final m = await a.lateMetadata!;
      expect(m!.title, 'Late title');
      expect(m.author, 'Late author');
      expect(m.duration, const Duration(minutes: 5));
      expect(m.thumbnailUrl, 'https://i.ytimg.com/late.jpg');
    });

    test('late metadata failure completes with null (no unhandled error)', () async {
      final gate = Completer<Video>();
      when(() => videos.get(any())).thenAnswer((_) => gate.future);
      final r = YoutubeExplodeResolver(client: yt, now: () => now, metadataGrace: const Duration(milliseconds: 20));
      final a = await r.resolve('dQw4w9WgXcQ');
      gate.completeError(RequestLimitExceededException('429'));
      expect(await a.lateMetadata, isNull);
    });

    test('on-time metadata: no lateMetadata', () async {
      final a = await resolver().resolve('dQw4w9WgXcQ');
      expect(a.title, 'Title');
      expect(a.lateMetadata, isNull);
    });

    test('metadata failure alone does not block playback (title falls back to id)', () async {
      when(() => videos.get(any())).thenAnswer((_) async => throw RequestLimitExceededException('429'));
      final a = await resolver().resolve('dQw4w9WgXcQ');
      expect(a.title, 'dQw4w9WgXcQ');
      expect(a.author, isNull);
      expect(a.url.queryParameters['itag'], '140');
    });

    test('manifest failure while metadata is still pending -> mapped failure, no unhandled error', () async {
      when(() => videos.get(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        throw StateError('late metadata failure');
      });
      when(() => streams.getManifest(any(),
              ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage')))
          .thenAnswer((_) async => throw RequestLimitExceededException('429'));
      await expectLater(
        resolver().resolve('dQw4w9WgXcQ'),
        throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.rateLimited)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    test('no playable audio -> extractionFailed', () async {
      when(() => streams.getManifest(any(), ytClients: any(named: 'ytClients'), requireWatchPage: any(named: 'requireWatchPage')))
          .thenAnswer((_) async => StreamManifest(const []));
      await expectLater(
        resolver().resolve('dQw4w9WgXcQ'),
        throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.extractionFailed)),
      );
    });
  });
}
