// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:bgtube/audio/range_fetcher.dart';
import 'package:bgtube/audio/yt_stream_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// خادم محلي يحاكي googlevideo: /ok يحترم Range، /full يتجاهله (200)،
/// /forbidden يعطي 403، /drop يقطع الاتصال وسط الجسم، /hang يرسل الترويسات ثم يصمت.
class FakeGoogleVideo {
  late HttpServer server;
  final data = List<int>.generate(1000, (i) => i % 256);
  final seenUa = <String?>[];
  final seenRange = <String?>[];
  final seenEncoding = <String?>[];
  final hangs = <HttpResponse>[];

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path?c=ANDROID');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      seenUa.add(req.headers.value(HttpHeaders.userAgentHeader));
      seenRange.add(req.headers.value(HttpHeaders.rangeHeader));
      seenEncoding.add(req.headers.value(HttpHeaders.acceptEncodingHeader));
      final res = req.response;
      res.headers.contentType = ContentType('audio', 'mp4');
      switch (req.uri.path) {
        case '/ok':
          final m = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(req.headers.value('range') ?? '')!;
          final a = int.parse(m[1]!);
          final b = m[2]!.isEmpty ? data.length - 1 : int.parse(m[2]!);
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $a-$b/${data.length}');
          res.contentLength = b - a + 1;
          res.add(data.sublist(a, b + 1));
          await res.close();
        case '/full':
          res.statusCode = 200;
          res.contentLength = data.length;
          res.add(data);
          await res.close();
        case '/forbidden':
          res.statusCode = 403;
          await res.close();
        case '/drop':
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-999/1000');
          res.contentLength = 1000;
          final socket = await res.detachSocket(); // يكتب الترويسات
          socket.add(data.sublist(0, 100));
          await socket.flush();
          socket.destroy();
        case '/hang':
          res.bufferOutput = false;
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-999/1000');
          res.contentLength = 1000;
          res.add(data.sublist(0, 10));
          await res.flush();
          hangs.add(res); // لا إغلاق
      }
    });
  }

  Future<void> stop() async {
    for (final h in hangs) {
      unawaited(h.close().catchError((Object _) {}));
    }
    await server.close(force: true);
  }
}

Future<List<int>> collect(Stream<List<int>> s) async => [for (final c in await s.toList()) ...c];

void main() {
  late FakeGoogleVideo g;
  const ua = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

  setUp(() async {
    g = FakeGoogleVideo();
    await g.start();
  });
  tearDown(() => g.stop());

  group('YtStreamAudioSource.request through fetchRange (real local HTTP)', () {
    test('from the start: whole file, exact client User-Agent, no dart:io UA, no gzip', () async {
      final src = YtStreamAudioSource(g.url('/ok'), const {'User-Agent': ua});
      final r = await src.request();
      expect(r.offset, 0);
      expect(r.sourceLength, 1000);
      expect(r.contentLength, 1000);
      expect(r.contentType, 'audio/mp4');
      expect(r.rangeRequestsSupported, isTrue);
      expect(await collect(r.stream), g.data);
      expect(g.seenUa.single, ua);
      expect(g.seenRange.single, 'bytes=0-');
      expect(g.seenEncoding.single, 'identity');
    });

    test('from the middle with an exclusive end', () async {
      final src = YtStreamAudioSource(g.url('/ok'), const {'User-Agent': ua});
      final r = await src.request(400, 600);
      expect(g.seenRange.single, 'bytes=400-599');
      expect(r.offset, 400);
      expect(r.contentLength, 200);
      expect(r.sourceLength, 1000);
      expect(await collect(r.stream), g.data.sublist(400, 600));
    });

    test('open-ended from the middle', () async {
      final r = await YtStreamAudioSource(g.url('/ok'), const {}).request(900);
      expect(r.offset, 900);
      expect(r.contentLength, 100);
      expect(await collect(r.stream), g.data.sublist(900));
    });

    test('no User-Agent header at all when we have none (dart:io default suppressed)', () async {
      await collect((await YtStreamAudioSource(g.url('/ok'), const {}).request()).stream);
      expect(g.seenUa.single, isNull);
    });

    test('server ignoring Range (200): bytes are skipped to the requested offset', () async {
      final r = await YtStreamAudioSource(g.url('/full'), const {}).request(250);
      expect(r.offset, 250);
      expect(r.contentLength, 750);
      expect(r.sourceLength, 1000);
      expect(await collect(r.stream), g.data.sublist(250));
    });

    test('403 -> RangeHttpException (just_audio answers ExoPlayer with 500)', () async {
      await expectLater(
        YtStreamAudioSource(g.url('/forbidden'), const {}).request(),
        throwsA(isA<RangeHttpException>().having((e) => e.statusCode, 'status', 403)),
      );
    });

    test('connection dropped mid-body: stream ends instead of hanging', () async {
      final r = await YtStreamAudioSource(g.url('/drop'), const {}).request();
      final bytes = await collect(r.stream).timeout(const Duration(seconds: 5));
      expect(bytes.length, lessThan(1000));
    });

    test('silent server: idle timeout closes the stream', () async {
      Future<RangeFetchResult> fetch(Uri u, Map<String, String> h, {int? start, int? end}) =>
          fetchRange(u, h, start: start, end: end, idleTimeout: const Duration(milliseconds: 200));
      final r = await YtStreamAudioSource(g.url('/hang'), const {}, fetch: fetch).request();
      final bytes = await collect(r.stream).timeout(const Duration(seconds: 5));
      expect(bytes.length, 10);
    });

    test('unreachable host -> throws (SocketException), no hang', () async {
      final port = g.server.port;
      await g.server.close(force: true);
      final src = YtStreamAudioSource(Uri.parse('http://127.0.0.1:$port/ok'), const {});
      await expectLater(src.request().timeout(const Duration(seconds: 5)), throwsA(isA<SocketException>()));
      g.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0); // لـtearDown
    });

    test('close() cancels in-flight bodies and rejects new requests', () async {
      final src = YtStreamAudioSource(g.url('/hang'), const {});
      final r = await src.request();
      final done = collect(r.stream);
      src.close();
      expect((await done.timeout(const Duration(seconds: 5))).length, lessThanOrEqualTo(10));
      await expectLater(src.request(), throwsA(isA<StateError>()));
    });
  });

  test('parseContentRange', () {
    expect(parseContentRange('bytes 0-99/1000'), (start: 0, end: 99, total: 1000));
    expect(parseContentRange('bytes 5-9/*'), (start: 5, end: 9, total: null));
    expect(parseContentRange('nonsense'), isNull);
    expect(parseContentRange(null), isNull);
  });
}
