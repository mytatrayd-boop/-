// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';

import 'package:bgtube/audio/range_fetcher.dart';
import 'package:bgtube/audio/yt_stream_audio_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// خادم محلي يحاكي googlevideo: /ok يحترم Range، /full يتجاهله (200)،
/// /forbidden يعطي 403، /drop يقطع الاتصال وسط الجسم، /hang يرسل الترويسات ثم يصمت،
/// /gzip جسم مضغوط، /aligned يبدأ من مضاعف 100 قبل المطلوب، /nolength و/nolength200 بلا طول.
class FakeGoogleVideo {
  late HttpServer server;
  final data = List<int>.generate(1000, (i) => i % 256);
  final seenUa = <String?>[];
  final seenRange = <String?>[];
  final seenEncoding = <String?>[];
  final hangs = <HttpResponse>[];
  final trickles = <HttpResponse>[];

  /// ردود /trickle التي لم يُغلق اتصالها بعد.
  int open = 0;

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
        case '/gzip':
          final gz = gzip.encode(data);
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-${gz.length - 1}/${gz.length}');
          res.contentLength = gz.length;
          res.add(gz);
          await res.close();
        case '/aligned':
          final m = RegExp(r'bytes=(\d+)-').firstMatch(req.headers.value('range') ?? '')!;
          final a = int.parse(m[1]!) ~/ 100 * 100;
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $a-${data.length - 1}/${data.length}');
          res.contentLength = data.length - a;
          res.add(data.sublist(a));
          await res.close();
        case '/nolength':
        case '/nolength200':
          // chunked بلا Content-Length ولا Content-Range.
          res.statusCode = req.uri.path == '/nolength' ? 206 : 200;
          await trickle(res);
        case '/trickle':
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-99999999/100000000');
          res.contentLength = 100000000;
          await trickle(res);
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

  /// يرسل 10 بايتات كل 20 م.ث بلا نهاية؛ الكتابة بعد انقطاع العميل تفشل فيُعلم
  /// الخادم بإغلاق الاتصال ([open] ينقص).
  Future<void> trickle(HttpResponse res) async {
    res.bufferOutput = false;
    open++;
    var gone = false;
    unawaited(res.done.then((_) {}, onError: (Object _) {}).whenComplete(() {
      gone = true;
      open--;
    }));
    trickles.add(res);
    while (!gone) {
      // بلا await flush: ينتظر بلا نهاية في الوضع غير المخزَّن؛ done يكفي للكشف.
      res.add(List<int>.filled(10, 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> stop() async {
    for (final h in [...hangs, ...trickles]) {
      unawaited(h.close().catchError((Object _) {}));
    }
    await server.close(force: true);
  }
}

/// ينتظر حتى يصير عدد اتصالات /trickle المفتوحة عند الخادم [n] (أو يفشل بعد 5 ث).
Future<void> waitConnections(FakeGoogleVideo g, int n) async {
  final sw = Stopwatch()..start();
  while (g.open != n) {
    if (sw.elapsed > const Duration(seconds: 5)) {
      fail('open connections: ${g.open}, expected $n');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
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

  group('review fixes (real fetchRange, local HTTP)', () {
    test('request -> listen -> cancel -> close does not throw and frees the connection', () async {
      final src = YtStreamAudioSource(g.url('/trickle'), const {});
      final r = await src.request(0, null);
      final sub = r.stream.listen((_) {});
      await waitConnections(g, 1);
      await sub.cancel();
      expect(src.close, returnsNormally);
      expect(src.close, returnsNormally); // مرتين أيضاً
      await waitConnections(g, 0);
    });

    test('fetchRange: cancel() after the body subscription was cancelled is a no-op', () async {
      final r = await fetchRange(g.url('/trickle'), const {});
      await r.body.listen((_) {}).cancel();
      expect(r.cancel, returnsNormally);
      expect(r.cancel, returnsNormally);
      await waitConnections(g, 0);
    });

    test('fetchRange: cancel() before listening closes the connection without reading', () async {
      final r = await fetchRange(g.url('/trickle'), const {});
      await waitConnections(g, 1);
      expect(r.cancel, returnsNormally);
      expect(r.cancel, returnsNormally);
      await waitConnections(g, 0);
      expect(await collect(r.body), isEmpty);
    });

    test('cancelling the body subscription alone closes the origin connection', () async {
      final r = await YtStreamAudioSource(g.url('/trickle'), const {}).request();
      final sub = r.stream.listen((_) {});
      await waitConnections(g, 1);
      await sub.cancel();
      await waitConnections(g, 0);
    });

    test('a new Range request cancels the previous one: three requests leave one connection', () async {
      final src = YtStreamAudioSource(g.url('/trickle'), const {});
      final bodies = <Future<List<int>>>[];
      for (final start in [0, 500, 200]) {
        final r = await src.request(start);
        bodies.add(collect(r.stream)); // كما يفعل وكيل just_audio
      }
      await waitConnections(g, 1);
      // السابقان انتهيا (done) فيُغلق الوكيل ردّيهما، ولا يعلقان.
      await Future.wait(bodies.take(2)).timeout(const Duration(seconds: 5));
      src.close();
      await waitConnections(g, 0);
      await bodies.last.timeout(const Duration(seconds: 5));
    });

    test('previous response superseded before the proxy listened: its stream just ends', () async {
      final src = YtStreamAudioSource(g.url('/trickle'), const {});
      final first = await src.request(0);
      final second = await src.request(500);
      expect(await collect(first.stream).timeout(const Duration(seconds: 5)), isEmpty);
      final sub = second.stream.listen((_) {});
      await waitConnections(g, 1);
      await sub.cancel();
      src.close();
      await waitConnections(g, 0);
    });

    test('idle timeout default is 10 s', () async {
      // خادم صامت بعد أول البايتات: الجالب بإعداداته الافتراضية يقطع بعد ~10 ث.
      final r = await fetchRange(g.url('/hang'), const {});
      final sw = Stopwatch()..start();
      await collect(r.body).timeout(const Duration(seconds: 15));
      expect(sw.elapsed, greaterThan(const Duration(seconds: 9)));
      expect(sw.elapsed, lessThan(const Duration(seconds: 12)));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('gzip body is passed through as raw bytes (no auto-uncompress)', () async {
      final r = await YtStreamAudioSource(g.url('/gzip'), const {}).request();
      final gz = gzip.encode(g.data);
      expect(r.contentLength, gz.length);
      expect(await collect(r.stream), gz);
    });

    test('offset comes from Content-Range start, not from the requested start', () async {
      final r = await YtStreamAudioSource(g.url('/aligned'), const {}).request(250);
      expect(g.seenRange.single, 'bytes=250-');
      expect(r.offset, 200);
      expect(r.contentLength, 800);
      expect(await collect(r.stream), g.data.sublist(200));
    });

    for (final path in ['/nolength', '/nolength200']) {
      test('unknown length ($path) -> RangeHttpException, never contentLength null', () async {
        await expectLater(
          YtStreamAudioSource(g.url(path), const {}).request(),
          throwsA(isA<RangeHttpException>()),
        );
        await waitConnections(g, 0);
      });
    }

    test('source closed while fetching: response is dropped and the request rejected', () async {
      final gate = Completer<void>();
      Future<RangeFetchResult> fetch(Uri u, Map<String, String> h, {int? start, int? end}) async {
        final r = await fetchRange(u, h, start: start, end: end);
        await gate.future;
        return r;
      }

      final src = YtStreamAudioSource(g.url('/trickle'), const {}, fetch: fetch);
      final f = src.request();
      await waitConnections(g, 1);
      src.close();
      gate.complete();
      await expectLater(f, throwsA(isA<StateError>()));
      await waitConnections(g, 0);
    });

    test('a request overtaken by a newer one while fetching is dropped', () async {
      final gate = Completer<void>();
      var calls = 0;
      Future<RangeFetchResult> fetch(Uri u, Map<String, String> h, {int? start, int? end}) async {
        final first = calls++ == 0;
        final r = await fetchRange(u, h, start: start, end: end);
        if (first) await gate.future;
        return r;
      }

      final src = YtStreamAudioSource(g.url('/trickle'), const {}, fetch: fetch);
      final old = src.request(0);
      await waitConnections(g, 1);
      final fresh = await src.request(500);
      gate.complete();
      await expectLater(old, throwsA(isA<StateError>()));
      final sub = fresh.stream.listen((_) {});
      await waitConnections(g, 1);
      await sub.cancel();
      src.close();
    });
  });

  test('parseContentRange', () {
    expect(parseContentRange('bytes 0-99/1000'), (start: 0, end: 99, total: 1000));
    expect(parseContentRange('bytes 5-9/*'), (start: 5, end: 9, total: null));
    expect(parseContentRange('nonsense'), isNull);
    expect(parseContentRange(null), isNull);
  });
}
