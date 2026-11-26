import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bgtube/audio/local_stream_proxy.dart';
import 'package:bgtube/audio/range_fetcher.dart';
import 'package:bgtube/audio/socket_buffers.dart';
import 'package:flutter_test/flutter_test.dart';

/// خادم أصل محلي يحاكي googlevideo:
/// /ok يحترم Range، /full يتجاهله (200)، /forbidden 403، /drop يقطع وسط الجسم،
/// /hang يرسل الترويسات ثم يصمت، /gzip جسم مضغوط، /aligned يبدأ من مضاعف 100،
/// /nolength و/nolength200 بلا طول، /trickle لا ينتهي، /big ‏60MB بضغط عكسي حقيقي.
class FakeGoogleVideo {
  late HttpServer server;
  ServerSocket? socket;
  final data = List<int>.generate(1000, (i) => i % 256);
  final seenUa = <String?>[];
  final seenRange = <String?>[];
  final seenEncoding = <String?>[];
  final hangs = <HttpResponse>[];
  final trickles = <HttpResponse>[];

  /// ردود /trickle و/big التي لم يُغلق اتصالها بعد.
  int open = 0;

  /// بايتات /big التي سلّمها الأصل إلى مقبسه (يتوقف المولّد حين يمتلئ المقبس).
  int bigSent = 0;
  static const bigSize = 60 * 1024 * 1024;

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path?c=ANDROID&sig=SECRETSIG');

  /// [sendBuffer]: يحدّ مخزن إرسال الأصل فيقترب عدّاده مما عبر الشبكة فعلاً
  /// (مخزن إرسال خادم بعيد لا يُحسب تنزيلاً على الجهاز).
  Future<void> start({int? sendBuffer}) async {
    final ss = socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server = HttpServer.listenOn(sendBuffer == null ? ss : SendLimitedServerSocket(ss, sendBytes: sendBuffer));
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
          res.statusCode = req.uri.path == '/nolength' ? 206 : 200;
          await trickle(res);
        case '/trickle':
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-99999999/100000000');
          res.contentLength = 100000000;
          await trickle(res);
        case '/big':
        case '/big16':
          await big(req, res, req.uri.path == '/big16' ? 16 * 1024 * 1024 : bigSize);
        case '/late':
          // يبدأ بعد البايت المطلوب بـ100.
          final m = RegExp(r'bytes=(\d+)-').firstMatch(req.headers.value('range') ?? '')!;
          final a = int.parse(m[1]!) + 100;
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $a-${data.length - 1}/${data.length}');
          res.contentLength = data.length - a;
          res.add(data.sublist(a));
          await res.close();
        case '/r416':
          res.statusCode = 416;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */${data.length}');
          await res.close();
        case '/hang':
          res.bufferOutput = false;
          res.statusCode = 206;
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-999/1000');
          res.contentLength = 1000;
          res.add(data.sublist(0, 10));
          await res.flush();
          hangs.add(res);
      }
    });
  }

  void _track(HttpResponse res, void Function() onGone) {
    open++;
    unawaited(res.done.then((_) {}, onError: (Object _) {}).whenComplete(() {
      open--;
      onGone();
    }));
  }

  Future<void> trickle(HttpResponse res) async {
    res.bufferOutput = false;
    var gone = false;
    _track(res, () => gone = true);
    trickles.add(res);
    while (!gone) {
      res.add(List<int>.filled(10, 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  /// 60MB عبر addStream من مولّد: لا يُنتج قطعة جديدة إلا إذا قبلها المقبس.
  Future<void> big(HttpRequest req, HttpResponse res, int size) async {
    final m = RegExp(r'bytes=(\d+)-').firstMatch(req.headers.value('range') ?? 'bytes=0-')!;
    final a = int.parse(m[1]!);
    res.statusCode = 206;
    res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $a-${size - 1}/$size');
    res.contentLength = size - a;
    var gone = false;
    _track(res, () => gone = true);
    final chunk = Uint8List(64 * 1024);
    Stream<List<int>> gen() async* {
      var left = size - a;
      while (left > 0 && !gone) {
        final n = min(chunk.length, left);
        bigSent += n;
        yield n == chunk.length ? chunk : Uint8List.sublistView(chunk, 0, n);
        left -= n;
      }
    }

    try {
      await res.addStream(gen());
      await res.close();
    } catch (_) {}
  }

  Future<void> stop() async {
    for (final h in [...hangs, ...trickles]) {
      unawaited(h.close().catchError((Object _) {}));
    }
    await server.close(force: true);
    await socket?.close();
  }
}

Future<void> waitFor(bool Function() ok, String what) async {
  final sw = Stopwatch()..start();
  while (!ok()) {
    if (sw.elapsed > const Duration(seconds: 5)) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

Future<void> waitConnections(FakeGoogleVideo g, int n) => waitFor(() => g.open == n, 'origin open == $n (now ${g.open})');

/// رد كامل من الوكيل كما يراه ExoPlayer.
typedef Got = ({int status, String reason, HttpHeaders headers, List<int> body});

Future<Got> get(Uri u, {String? range}) async {
  final c = HttpClient();
  try {
    final req = await c.getUrl(u);
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    final res = await req.close();
    final body = <int>[];
    try {
      await for (final b in res) {
        body.addAll(b);
      }
    } on HttpException {
      // جسم مقطوع: نعيد ما وصل.
    }
    return (status: res.statusCode, reason: res.reasonPhrase, headers: res.headers, body: body);
  } finally {
    c.close(force: true);
  }
}

/// يفتح طلباً ويعيد الرد بلا قراءة الجسم، مع العميل لقطعه.
Future<(HttpClient, HttpClientResponse)> open(Uri u, {String? range, int? receiveBuffer}) async {
  final c = HttpClient();
  if (receiveBuffer != null) c.connectionFactory = limitedConnectionFactory(receiveBytes: receiveBuffer);
  final req = await c.getUrl(u);
  if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
  return (c, await req.close());
}

/// يشغّل [body] داخل zone محروسة ويعيد كل خطأ غير معالج وصل إليها.
Future<List<Object>> guarded(Future<void> Function() body) async {
  final errors = <Object>[];
  final done = Completer<void>();
  runZonedGuarded(() async {
    try {
      await body();
      done.complete();
    } catch (e, st) {
      if (!done.isCompleted) done.completeError(e, st);
    }
  }, (e, _) => errors.add(e));
  await done.future;
  // مهلة لتصل أي أخطاء متأخرة (done/close بعد الانقطاع).
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return errors;
}

/// عميل يطلب /big ‏(60MB) ويقرأ 256KB ثم يتوقف 3 ث ثم ينقطع. يعيد ما قرأه، وما
/// سحبه الوكيل إلى ذاكرة Dart، وما أنتجه الأصل بعد 2 ث و3 ث من التوقف.
Future<({int read, int intoDart, int origin, int originLater, List<Object> errors})> backpressureRun(
  FakeGoogleVideo g, {
  int? clientReceive,
}) async {
  var read = 0;
  var pulled = 0;
  var intoDart = 0;
  var origin = 0;
  var originLater = 0;
  final errors = await guarded(() async {
    final p = LocalStreamProxy(fetch: (u, h, {start, end}) async {
      final r = await fetchRange(u, h, start: start, end: end);
      return RangeFetchResult(
        statusCode: r.statusCode,
        offset: r.offset,
        contentLength: r.contentLength,
        sourceLength: r.sourceLength,
        contentType: r.contentType,
        body: r.body.map((c) {
          pulled += c.length;
          return c;
        }),
        cancel: r.cancel,
      );
    });
    await p.start();
    final s = p.register(g.url('/big'), const {});
    final (client, res) = await open(s.localUri, range: 'bytes=0-', receiveBuffer: clientReceive);
    expect(res.statusCode, 206);
    expect(res.contentLength, FakeGoogleVideo.bigSize);
    final enough = Completer<void>();
    late final StreamSubscription<List<int>> sub;
    sub = res.listen((c) {
      read += c.length;
      if (read >= 256 * 1024 && !enough.isCompleted) {
        sub.pause();
        enough.complete();
      }
    }, onError: (Object _) {});
    await enough.future;
    await Future<void>.delayed(const Duration(seconds: 2));
    origin = g.bigSent;
    intoDart = pulled;
    await Future<void>.delayed(const Duration(seconds: 1));
    originLater = g.bigSent;
    expect(s.activeCount, 1);
    // العميل يرحل: يُغلق اتصال الأصل ويفرغ _active.
    client.close(force: true);
    await waitConnections(g, 0);
    await waitFor(() => s.activeCount == 0, 'active empty after disconnect');
    await p.close();
  });
  return (read: read, intoDart: intoDart, origin: origin, originLater: originLater, errors: errors);
}

void main() {
  late FakeGoogleVideo g;
  late LocalStreamProxy proxy;
  const ua = 'com.google.android.youtube/20.10.38 (Linux; U; Android 11) gzip';

  setUp(() async {
    g = FakeGoogleVideo();
    await g.start();
    proxy = LocalStreamProxy();
    await proxy.start();
  });
  tearDown(() async {
    await proxy.close();
    await g.stop();
  });

  ProxiedStream reg(String path, [Map<String, String> h = const {}]) => proxy.register(g.url(path), h);

  group('serving ExoPlayer requests (real local HTTP both sides)', () {
    test('no Range: 200 with the whole file, exact client UA, no dart:io UA, identity', () async {
      final s = reg('/ok', const {'User-Agent': ua});
      final r = await get(s.localUri);
      expect(r.status, 200);
      expect(r.headers.contentLength, 1000);
      expect(r.headers.contentType?.mimeType, 'audio/mp4');
      expect(r.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
      expect(r.body, g.data);
      expect(g.seenUa.single, ua);
      expect(g.seenRange.single, 'bytes=0-');
      expect(g.seenEncoding.single, 'identity');
    });

    test('Range with an end: 206 + Content-Range + Content-Length', () async {
      final r = await get(reg('/ok').localUri, range: 'bytes=400-599');
      expect(g.seenRange.single, 'bytes=400-599');
      expect(r.status, 206);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 400-599/1000');
      expect(r.headers.contentLength, 200);
      expect(r.body, g.data.sublist(400, 600));
    });

    test('open-ended Range from the middle', () async {
      final r = await get(reg('/ok').localUri, range: 'bytes=900-');
      expect(r.status, 206);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 900-999/1000');
      expect(r.body, g.data.sublist(900));
    });

    test('no User-Agent at all when the client has none', () async {
      await get(reg('/ok').localUri);
      expect(g.seenUa.single, isNull);
    });

    test('origin ignoring Range (200): bytes skipped, client still gets a correct 206', () async {
      final r = await get(reg('/full').localUri, range: 'bytes=250-');
      expect(r.status, 206);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 250-999/1000');
      expect(r.body, g.data.sublist(250));
    });

    test('origin starting earlier than asked: proxy skips to the exact requested byte', () async {
      final r = await get(reg('/aligned').localUri, range: 'bytes=250-');
      expect(g.seenRange.single, 'bytes=250-');
      expect(r.status, 206);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 250-999/1000');
      expect(r.body, g.data.sublist(250));
    });

    test('gzip body passes through as raw bytes', () async {
      final r = await get(reg('/gzip').localUri, range: 'bytes=0-');
      expect(r.body, gzip.encode(g.data));
    });

    test('403 from origin is passed through as 403', () async {
      final s = reg('/forbidden');
      final r = await get(s.localUri, range: 'bytes=0-');
      expect(r.status, 403);
      expect(s.lastError, isA<OriginStatusException>().having((e) => e.statusCode, 'status', 403));
      expect(s.activeCount, 0);
    });

    test('unreachable origin: 502 "Origin unreachable", error has no signed url', () async {
      final port = g.server.port;
      await g.stop();
      final s = proxy.register(Uri.parse('http://127.0.0.1:$port/ok?sig=SECRETSIG&ip=1.2.3.4'), const {});
      final r = await get(s.localUri, range: 'bytes=0-').timeout(const Duration(seconds: 5));
      expect(r.status, 502);
      expect(r.reason, ProxyReason.unreachable);
      expect(s.lastError, isA<RangeFetchNetworkException>());
      expect(s.lastError.toString(), isNot(contains('SECRETSIG')));
      expect(s.lastError.toString(), isNot(contains('127.0.0.1')));
      g.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0); // لـtearDown
    });

    for (final path in ['/nolength', '/nolength200']) {
      test('unknown length ($path): distinct UnknownLengthException, not an origin rejection', () async {
        final s = reg(path);
        final r = await get(s.localUri, range: 'bytes=0-');
        expect(r.status, 502);
        expect(r.reason, ProxyReason.unknownLength);
        expect(s.lastError, isA<UnknownLengthException>());
        expect(s.lastError, isNot(isA<OriginStatusException>()));
        await waitConnections(g, 0);
        expect(s.activeCount, 0);
      });
    }

    test('origin drops mid-body: client sees a short body, no hang, nothing unhandled', () async {
      late ProxiedStream s;
      late Got r;
      final errors = await guarded(() async {
        final p = LocalStreamProxy();
        await p.start();
        s = p.register(g.url('/drop'), const {});
        r = await get(s.localUri, range: 'bytes=0-').timeout(const Duration(seconds: 5));
        await waitFor(() => s.activeCount == 0, 'active empty');
        await p.close();
      });
      expect(r.body.length, lessThan(1000));
      expect(errors, isEmpty);
    });

    test('silent origin: idle timeout ends the client body', () async {
      final p = LocalStreamProxy(
        fetch: (u, h, {start, end}) =>
            fetchRange(u, h, start: start, end: end, idleTimeout: const Duration(milliseconds: 200)),
      );
      await p.start();
      addTearDown(p.close);
      final s = p.register(g.url('/hang'), const {});
      final r = await get(s.localUri, range: 'bytes=0-').timeout(const Duration(seconds: 5));
      expect(r.body.length, 10);
      expect(s.activeCount, 0);
    });
  });

  group('backpressure and disconnects (review issue 1)', () {
    test('client reads 256KB then stops (this machine\'s default buffers): origin stalls, nothing unhandled',
        () async {
      final m = await backpressureRun(g);
      // ignore: avoid_print
      print('backpressure default: $m');
      expect(m.originLater, m.origin, reason: 'origin must stall while the client is paused');
      expect(m.intoDart, lessThan(6 * 1024 * 1024));
      expect(m.origin, lessThan(16 * 1024 * 1024));
      expect(m.errors, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('client reads 256KB then stops (Android-like 1MB client buffer, network-only origin count): '
        'origin sends only a few MB of 60MB', () async {
      final origin = FakeGoogleVideo();
      await origin.start(sendBuffer: 256 * 1024);
      addTearDown(origin.stop);
      final m = await backpressureRun(origin, clientReceive: 1024 * 1024);
      // ignore: avoid_print
      print('backpressure limited: $m');
      expect(m.originLater, m.origin);
      // معظم ما سُحب جالس في مخزن استقبال العميل (ExoPlayer على الجهاز)، لا في Dart.
      expect(m.origin, lessThan(8 * 1024 * 1024));
      expect(m.intoDart, lessThan(6 * 1024 * 1024));
      expect(m.errors, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('client disconnect mid-body closes the origin connection, nothing unhandled', () async {
      late ProxiedStream s;
      final errors = await guarded(() async {
        final p = LocalStreamProxy();
        await p.start();
        s = p.register(g.url('/trickle'), const {});
        final (client, res) = await open(s.localUri, range: 'bytes=0-');
        final first = Completer<void>();
        res.listen((_) {
          if (!first.isCompleted) first.complete();
        }, onError: (Object _) {});
        await first.future;
        await waitConnections(g, 1);
        client.close(force: true);
        await waitConnections(g, 0);
        await waitFor(() => s.activeCount == 0, 'active empty');
        // الطلب التالي للمصدر نفسه يعمل (لا حالة عالقة).
        final again = await open(s.localUri, range: 'bytes=0-');
        expect(again.$2.statusCode, 206);
        again.$1.close(force: true);
        await waitConnections(g, 0);
        await p.close();
      });
      expect(errors, isEmpty);
    });

    // dart:io لا يقرأ مقبس الطلب أثناء الرد، فلا يرى رحيل العميل إلا عند فشل
    // كتابة. مع أصل صامت لا تُنزَّل بيانات أصلاً، وتنظّفه مهلة الخمول.
    test('client leaves while the origin is silent: cleaned up by the idle timeout, nothing unhandled', () async {
      final errors = await guarded(() async {
        final p = LocalStreamProxy(
          fetch: (u, h, {start, end}) =>
              fetchRange(u, h, start: start, end: end, idleTimeout: const Duration(milliseconds: 300)),
        );
        await p.start();
        final s = p.register(g.url('/hang'), const {});
        final (client, res) = await open(s.localUri, range: 'bytes=0-');
        final first = Completer<void>();
        res.listen((_) {
          if (!first.isCompleted) first.complete();
        }, onError: (Object _) {});
        await first.future;
        client.close(force: true);
        await waitFor(() => s.activeCount == 0, 'active empty');
        await p.close();
      });
      expect(errors, isEmpty);
    });

    test('a new Range request cuts the previous one: one origin connection per source', () async {
      final s = reg('/trickle');
      final clients = <HttpClient>[];
      final ends = <Future<void>>[];
      for (final r in ['bytes=0-', 'bytes=500-', 'bytes=200-']) {
        final (c, res) = await open(s.localUri, range: r);
        clients.add(c);
        ends.add(res.drain<void>().catchError((Object _) {}));
        await waitConnections(g, 1);
      }
      await Future.wait(ends.take(2)).timeout(const Duration(seconds: 5));
      expect(s.activeCount, 1);
      s.close();
      await waitConnections(g, 0);
      await ends.last.timeout(const Duration(seconds: 5));
      expect(s.activeCount, 0);
      for (final c in clients) {
        c.close(force: true);
      }
    });
  });

  group('review of the local proxy', () {
    test('reader paused longer than the idle timeout: full body over one origin connection', () async {
      const size = 16 * 1024 * 1024;
      final errors = await guarded(() async {
        final p = LocalStreamProxy(
          fetch: (u, h, {start, end}) =>
              fetchRange(u, h, start: start, end: end, idleTimeout: const Duration(milliseconds: 300)),
        );
        await p.start();
        final s = p.register(g.url('/big16'), const {});
        final (client, res) = await open(s.localUri, range: 'bytes=0-');
        var read = 0;
        var paused = false;
        final done = Completer<void>();
        late final StreamSubscription<List<int>> sub;
        sub = res.listen((c) {
          read += c.length;
          if (!paused && read >= 256 * 1024) {
            paused = true;
            sub.pause();
            // توقف أطول من مهلة الخمول بأربع مرات؛ الجلب موقوف خلاله بالضغط العكسي.
            Timer(const Duration(milliseconds: 1200), sub.resume);
          }
        }, onDone: done.complete, onError: (Object e) => done.completeError(e));
        await done.future.timeout(const Duration(seconds: 20));
        expect(read, size);
        expect(g.seenRange, ['bytes=0-'], reason: 'one origin request, never re-opened');
        client.close(force: true);
        await p.close();
      });
      expect(errors, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 40)));

    test('origin starting after the requested byte: 502 "Origin range mismatch"', () async {
      final s = reg('/late');
      final r = await get(s.localUri, range: 'bytes=250-');
      expect(r.status, 502);
      expect(r.reason, ProxyReason.rangeMismatch);
      expect(r.body, isEmpty);
      expect(s.lastError, isA<OriginRangeMismatchException>());
      expect(s.activeCount, 0);
    });

    test('an older request whose fetch completes after a newer one gets 503 and frees its origin connection',
        () async {
      final gate = Completer<void>();
      var calls = 0;
      final p = LocalStreamProxy(fetch: (u, h, {start, end}) async {
        final first = calls++ == 0;
        final r = await fetchRange(u, h, start: start, end: end);
        if (first) await gate.future;
        return r;
      });
      await p.start();
      addTearDown(p.close);
      final s = p.register(g.url('/trickle'), const {});
      final old = get(s.localUri, range: 'bytes=0-');
      await waitConnections(g, 1);
      final (c, fresh) = await open(s.localUri, range: 'bytes=500-');
      expect(fresh.statusCode, 206);
      gate.complete();
      final o = await old.timeout(const Duration(seconds: 5));
      expect(o.status, 503);
      expect(o.reason, ProxyReason.superseded);
      await waitConnections(g, 1); // القديم أُغلق، والأحدث وحده باقٍ
      expect(s.activeCount, 1);
      c.close(force: true);
      await waitConnections(g, 0);
    });

    test('416 from origin is passed on with Content-Range: bytes */total', () async {
      final s = reg('/r416');
      final r = await get(s.localUri, range: 'bytes=5000-');
      expect(r.status, 416);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes */1000');
    });

    test('origin returning more than the requested end is trimmed to it', () async {
      final r = await get(reg('/full').localUri, range: 'bytes=100-199');
      expect(r.status, 206);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 100-199/1000');
      expect(r.headers.contentLength, 100);
      expect(r.body, g.data.sublist(100, 200));
    });

    test('close() during start(): the bound port is released and start fails', () async {
      final p = LocalStreamProxy();
      final f = p.start();
      await p.close();
      await expectLater(f, throwsStateError);
      final port = p.debugBoundPort!;
      expect(p.port, isNull);
      await expectLater(Socket.connect(InternetAddress.loopbackIPv4, port), throwsA(isA<SocketException>()));
    });
  });

  group('_active bookkeeping (review issue 3)', () {
    test('empty after the body completes', () async {
      final s = reg('/ok');
      final r = await get(s.localUri, range: 'bytes=0-');
      expect(r.body.length, 1000);
      await waitFor(() => s.activeCount == 0, 'active empty');
    });

    test('empty after the client cancels', () async {
      final s = reg('/trickle');
      final (c, res) = await open(s.localUri, range: 'bytes=0-');
      final sub = res.listen((_) {}, onError: (Object _) {});
      await waitConnections(g, 1);
      expect(s.activeCount, 1);
      await sub.cancel();
      c.close(force: true);
      await waitConnections(g, 0);
      await waitFor(() => s.activeCount == 0, 'active empty');
    });

    test('empty after close(), and the path is gone (404)', () async {
      final s = reg('/trickle');
      final (c, res) = await open(s.localUri, range: 'bytes=0-');
      final ended = res.drain<void>().catchError((Object _) {});
      await waitConnections(g, 1);
      expect(s.close, returnsNormally);
      expect(s.close, returnsNormally);
      expect(s.activeCount, 0);
      await waitConnections(g, 0);
      await ended.timeout(const Duration(seconds: 5));
      c.close(force: true);
      expect((await get(s.localUri)).status, 404);
      expect(proxy.registeredCount, 0);
    });
  });

  group('local endpoint', () {
    test('loopback only, random unguessable path per source', () {
      final a = reg('/ok');
      final b = reg('/ok');
      expect(a.localUri.host, '127.0.0.1');
      expect(a.localUri.port, proxy.port);
      expect(a.localUri.pathSegments.single.length, greaterThanOrEqualTo(32));
      expect(a.localUri.path, isNot(b.localUri.path));
      expect(a.localUri.hasQuery, isFalse);
      expect(a.localUri.toString(), isNot(contains('SECRETSIG')));
    });

    test('unknown path, extra query, and non-GET are refused', () async {
      final s = reg('/ok');
      expect((await get(s.localUri.replace(path: '/nope'))).status, 404);
      expect((await get(s.localUri.replace(query: 'x=1'))).status, 404);
      final c = HttpClient();
      final res = await (await c.headUrl(s.localUri)).close();
      expect(res.statusCode, 405);
      c.close(force: true);
      expect(g.seenRange, isEmpty);
    });

    test('closed proxy refuses register and start', () async {
      await proxy.close();
      expect(() => proxy.register(g.url('/ok'), const {}), throwsStateError);
      await expectLater(proxy.start(), throwsStateError);
    });
  });

  group('fetchRange', () {
    test('cancel() before listening closes the connection without reading', () async {
      final r = await fetchRange(g.url('/trickle'), const {});
      await waitConnections(g, 1);
      expect(r.cancel, returnsNormally);
      expect(r.cancel, returnsNormally);
      await waitConnections(g, 0);
      expect(await r.body.toList(), isEmpty);
    });

    test('cancel() after the body subscription was cancelled is a no-op', () async {
      final r = await fetchRange(g.url('/trickle'), const {});
      await r.body.listen((_) {}).cancel();
      expect(r.cancel, returnsNormally);
      await waitConnections(g, 0);
    });

    test('network error: RangeFetchNetworkException without the signed url', () async {
      final port = g.server.port;
      await g.stop();
      final url = Uri.parse('http://127.0.0.1:$port/v?sig=SECRETSIG&ip=1.2.3.4');
      Object? err;
      try {
        await fetchRange(url, const {});
      } catch (e) {
        err = e;
      }
      expect(err, isA<RangeFetchNetworkException>().having((e) => e.cause, 'cause', 'SocketException'));
      expect(err.toString(), isNot(contains('SECRETSIG')));
      expect(err.toString(), isNot(contains('$port')));
      g.server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });

    test('idle timeout default is 10 s', () async {
      final r = await fetchRange(g.url('/hang'), const {});
      final sw = Stopwatch()..start();
      await r.body.drain<void>().timeout(const Duration(seconds: 15));
      expect(sw.elapsed, greaterThan(const Duration(seconds: 9)));
      expect(sw.elapsed, lessThan(const Duration(seconds: 12)));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('socket buffers', () {
    test('origin connections get a small receive buffer; local connections a small send buffer', () async {
      // 48KB: لينكس يضاعفها إلى 98304، وهي تختلف عن الافتراضي هنا (131072 استقبالاً)
      // فإزالة الضبط تُكتشف. (64KB تُضاعف إلى 131072 نفسها فلا تكشف شيئاً.)
      const want = 48 * 1024;
      final ss = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final plainAccepted = Completer<Socket>();
      final plain = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      plain.listen(plainAccepted.complete);
      final defaultClient = await Socket.connect(InternetAddress.loopbackIPv4, plain.port);
      final defaults = (
        receive: readSocketBuffers(defaultClient).receive,
        send: readSocketBuffers(await plainAccepted.future).send,
      );
      expect(defaults.receive, isNot(2 * want));
      expect(defaults.send, isNot(2 * want));

      final limited = SendLimitedServerSocket(ss, sendBytes: want);
      final accepted = Completer<Socket>();
      limited.listen(accepted.complete);
      final task = await limitedConnectionFactory(receiveBytes: want)(Uri.parse('http://127.0.0.1:${ss.port}/'), null, null);
      final client = await task.socket;
      final server = await accepted.future;
      expect(readSocketBuffers(client).receive, 2 * want);
      expect(readSocketBuffers(server).send, 2 * want);
      defaultClient.destroy();
      await plain.close();
      client.destroy();
      server.destroy();
      await limited.close();
    }, testOn: 'linux');
  });

  group('TLS through limitedConnectionFactory', () {
    late Directory dir;
    late HttpServer tls;
    late SecurityContext trusted;

    setUpAll(() async {
      dir = await Directory.systemTemp.createTemp('bgtube_tls');
      final r = await Process.run('openssl', [
        'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '1', //
        '-keyout', '${dir.path}/key.pem', '-out', '${dir.path}/cert.pem',
        '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1',
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final server = SecurityContext()
        ..useCertificateChain('${dir.path}/cert.pem')
        ..usePrivateKey('${dir.path}/key.pem');
      trusted = SecurityContext(withTrustedRoots: false)..setTrustedCertificates('${dir.path}/cert.pem');
      tls = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, server);
      tls.listen((req) async {
        req.response.statusCode = 206;
        req.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-2/3');
        req.response.add([1, 2, 3]);
        await req.response.close();
      });
    });
    tearDownAll(() async {
      await tls.close(force: true);
      await dir.delete(recursive: true);
    });

    Uri tlsUrl() => Uri.parse('https://127.0.0.1:${tls.port}/v');

    test('a trusted certificate succeeds over TLS (bytes intact, buffer limited)', () async {
      final c = HttpClient()..connectionFactory = limitedConnectionFactory(context: trusted);
      addTearDown(() => c.close(force: true));
      final res = await (await c.getUrl(tlsUrl())).close();
      expect(res.statusCode, 206);
      expect([for (final b in await res.toList()) ...b], [1, 2, 3]);
    });

    test('an untrusted certificate is rejected (default roots), never downgraded to plain HTTP', () async {
      final c = HttpClient()..connectionFactory = limitedConnectionFactory();
      addTearDown(() => c.close(force: true));
      await expectLater(() async => (await c.getUrl(tlsUrl())).close(), throwsA(isA<HandshakeException>()));
      // ومن fetchRange: خطأ شبكة مغلّف بلا رابط.
      await expectLater(
        fetchRange(tlsUrl(), const {}),
        throwsA(isA<RangeFetchNetworkException>().having((e) => e.cause, 'cause', 'HandshakeException')),
      );
    });
  });

  group('pure helpers', () {
    test('parseRangeHeader', () {
      expect(parseRangeHeader('bytes=0-'), (start: 0, endEx: null));
      expect(parseRangeHeader('bytes=100-199'), (start: 100, endEx: 200));
      expect(parseRangeHeader('bytes=-500'), isNull);
      expect(parseRangeHeader('bytes=9-1'), isNull);
      expect(parseRangeHeader(null), isNull);
    });

    test('parseUnsatisfiedRange', () {
      expect(parseUnsatisfiedRange('bytes */1000'), 1000);
      expect(parseUnsatisfiedRange('bytes 0-1/1000'), isNull);
      expect(parseUnsatisfiedRange(null), isNull);
    });

    test('parseContentRange', () {
      expect(parseContentRange('bytes 0-99/1000'), (start: 0, end: 99, total: 1000));
      expect(parseContentRange('bytes 5-9/*'), (start: 5, end: 9, total: null));
      expect(parseContentRange('nonsense'), isNull);
    });

    test('window skips then limits exactly, and cancels the source when full', () async {
      var cancelled = false;
      final src = StreamController<List<int>>(onCancel: () => cancelled = true);
      final out = window(src.stream, skip: 3, length: 5).toList();
      src
        ..add([0, 1])
        ..add([2, 3, 4])
        ..add([5, 6, 7, 8, 9]);
      expect([for (final c in await out) ...c], [3, 4, 5, 6, 7]);
      expect(cancelled, isTrue);
    });

    test('window: source error ends the stream without throwing', () async {
      final src = StreamController<List<int>>();
      final out = window(src.stream, skip: 0, length: 10).toList();
      src
        ..add([1])
        ..addError(const SocketException('x'));
      expect([for (final c in await out) ...c], [1]);
    });
  });
}
