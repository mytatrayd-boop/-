import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bgtube/audio/local_stream_proxy.dart';
import 'package:bgtube/audio/range_fetcher.dart';
import 'package:bgtube/audio/socket_buffers.dart';
import 'package:flutter_test/flutter_test.dart';

/// بايت الملف الوهمي عند الموضع i (يكشف أي إزاحة خاطئة).
int byteAt(int i) => (i * 7 + (i >> 8) + (i >> 20)) & 0xff;

/// أصل يحاكي googlevideo لعميل بلا PO token: أي Range مفتوح أو بلا Range أو
/// أكبر من [maxSpan] يُرد بـ403؛ غيره 206 مع قصّ النهاية عند حجم الملف.
class StrictOrigin {
  StrictOrigin({this.size = 25 * 1024 * 1024, this.maxSpan = 10 * 1000 * 1000, this.always403 = false});

  final int size;
  final int maxSpan;
  final bool always403;
  late HttpServer server;
  ServerSocket? _socket;
  final accepted = <String>[];
  final rejected = <String?>[];
  int sent = 0;
  int open = 0;

  Uri get url => Uri.parse('http://127.0.0.1:${server.port}/videoplayback?c=ANDROID&sig=SECRETSIG');

  Future<void> start() async {
    final ss = _socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server = HttpServer.listenOn(SendLimitedServerSocket(ss, sendBytes: 64 * 1024));
    server.listen((req) async {
      final res = req.response;
      final header = req.headers.value(HttpHeaders.rangeHeader);
      final m = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(header ?? '');
      if (always403 || m == null || m[2]!.isEmpty || int.parse(m[2]!) - int.parse(m[1]!) + 1 > maxSpan) {
        rejected.add(header);
        res.statusCode = 403;
        await res.close();
        return;
      }
      final a = int.parse(m[1]!);
      if (a >= size) {
        res.statusCode = 416;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$size');
        await res.close();
        return;
      }
      final b = min(int.parse(m[2]!), size - 1);
      accepted.add(header!);
      res.statusCode = 206;
      res.headers.contentType = ContentType('audio', 'mp4');
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $a-$b/$size');
      res.contentLength = b - a + 1;
      open++;
      var gone = false;
      unawaited(res.done.then((_) {}, onError: (Object _) {}).whenComplete(() {
        open--;
        gone = true;
      }));
      Stream<List<int>> gen() async* {
        var p = a;
        while (p <= b && !gone) {
          final n = min(64 * 1024, b - p + 1);
          final buf = Uint8List(n);
          for (var i = 0; i < n; i++) {
            buf[i] = byteAt(p + i);
          }
          sent += n;
          yield buf;
          p += n;
        }
      }

      try {
        await res.addStream(gen());
        await res.close();
      } catch (_) {}
    });
  }

  Future<void> stop() async {
    await server.close(force: true);
    await _socket?.close();
  }
}

/// يقرأ الرد كله ويتحقق من كل بايت عند إزاحته الصحيحة؛ يعيد (الحالة، الطول، الترويسات).
Future<({int status, int length, bool intact, HttpHeaders headers})> fetchAndVerify(Uri u, String? range, int offset) async {
  final c = HttpClient();
  try {
    final req = await c.getUrl(u);
    if (range != null) req.headers.set(HttpHeaders.rangeHeader, range);
    final res = await req.close();
    var n = 0;
    var intact = true;
    await for (final chunk in res) {
      for (var i = 0; i < chunk.length; i++) {
        if (chunk[i] != byteAt(offset + n + i)) intact = false;
      }
      n += chunk.length;
    }
    return (status: res.statusCode, length: n, intact: intact, headers: res.headers);
  } finally {
    c.close(force: true);
  }
}

int endOf(String h) => int.parse(RegExp(r'-(\d+)$').firstMatch(h)!.group(1)!);
int startOf(String h) => int.parse(RegExp(r'^bytes=(\d+)-').firstMatch(h)!.group(1)!);

void main() {
  late StrictOrigin origin;
  late LocalStreamProxy proxy;

  Future<void> setUpOrigin(StrictOrigin o) async {
    origin = o;
    await origin.start();
    proxy = LocalStreamProxy();
    await proxy.start();
  }

  tearDown(() async {
    await proxy.close();
    await origin.stop();
  });

  group('bounded origin ranges (403 on open or large Range)', () {
    test('the strict origin really rejects open-ended and oversized ranges (sanity)', () async {
      await setUpOrigin(StrictOrigin());
      for (final r in ['bytes=0-', 'bytes=0-20000000']) {
        final c = HttpClient();
        final req = await c.getUrl(origin.url);
        req.headers.set(HttpHeaders.rangeHeader, r);
        expect((await req.close()).statusCode, 403);
        c.close(force: true);
      }
    });

    test('full playback from `bytes=0-`: whole file intact, every origin Range is bounded and <= 9MB', () async {
      await setUpOrigin(StrictOrigin());
      final s = proxy.register(origin.url, const {'User-Agent': 'UA'});
      final r = await fetchAndVerify(s.localUri, 'bytes=0-', 0);
      expect(r.status, 206);
      expect(r.length, origin.size);
      expect(r.intact, isTrue);
      expect(r.headers.contentLength, origin.size);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 0-${origin.size - 1}/${origin.size}');
      expect(origin.rejected, isEmpty, reason: 'no 403 was ever needed');
      expect(origin.accepted.length, 4); // 25MiB / 8MiB
      for (final h in origin.accepted) {
        expect(endOf(h) - startOf(h) + 1, lessThanOrEqualTo(9 * 1000 * 1000));
      }
      expect(s.lastError, isNull);
      await waitFor(() => s.activeCount == 0);
    });

    test('no Range from the player: 200 with the whole length, still bounded origin requests', () async {
      await setUpOrigin(StrictOrigin());
      final r = await fetchAndVerify(proxy.register(origin.url, const {}).localUri, null, 0);
      expect(r.status, 200);
      expect(r.length, origin.size);
      expect(r.intact, isTrue);
      expect(origin.rejected, isEmpty);
    });

    test('seeking across chunks: open-ended jump, mid-file range crossing a boundary, and the tail', () async {
      await setUpOrigin(StrictOrigin());
      final s = proxy.register(origin.url, const {});
      var r = await fetchAndVerify(s.localUri, 'bytes=17000000-', 17000000);
      expect(r.status, 206);
      expect(r.length, origin.size - 17000000);
      expect(r.intact, isTrue);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 17000000-${origin.size - 1}/${origin.size}');

      r = await fetchAndVerify(s.localUri, 'bytes=8000000-16999999', 8000000);
      expect(r.status, 206);
      expect(r.length, 9000000);
      expect(r.intact, isTrue);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 8000000-16999999/${origin.size}');

      r = await fetchAndVerify(s.localUri, 'bytes=${origin.size - 10}-', origin.size - 10);
      expect(r.length, 10);
      expect(r.intact, isTrue);

      r = await fetchAndVerify(s.localUri, 'bytes=${origin.size}-', 0);
      expect(r.status, 416);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes */${origin.size}');
      expect(origin.rejected.where((h) => h != null && !h.endsWith('-')), isEmpty);
      expect(origin.accepted.every((h) => endOf(h) - startOf(h) + 1 <= originChunkBytes), isTrue);
    });

    test('backpressure: reader stalls after 256KB, origin pulled at most ~2 chunks ahead, one connection', () async {
      await setUpOrigin(StrictOrigin(size: 60 * 1024 * 1024));
      final s = proxy.register(origin.url, const {});
      final c = HttpClient()..connectionFactory = limitedConnectionFactory(receiveBytes: 64 * 1024);
      addTearDown(() => c.close(force: true));
      final req = await c.getUrl(s.localUri);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final res = await req.close();
      expect(res.contentLength, origin.size);
      var read = 0;
      final enough = Completer<void>();
      late final StreamSubscription<List<int>> sub;
      sub = res.listen((d) {
        read += d.length;
        if (read >= 256 * 1024 && !enough.isCompleted) {
          sub.pause();
          enough.complete();
        }
      }, onError: (Object _) {});
      await enough.future;
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(origin.sent, lessThan(2 * originChunkBytes), reason: 'sent ${origin.sent}');
      expect(origin.sent, lessThan(originChunkBytes), reason: 'in fact well under a single chunk');
      expect(origin.accepted.length, 1);
      expect(origin.open, lessThanOrEqualTo(1));
      expect(s.activeCount, 1);
      // يستأنف القارئ فيتقدّم الأصل إلى القطعة التالية فقط عند الحاجة.
      sub.resume();
      c.close(force: true);
      await waitFor(() => origin.open == 0);
      await waitFor(() => s.activeCount == 0);
    });

    test('client leaving mid-file closes the origin connection and stops chaining chunks', () async {
      await setUpOrigin(StrictOrigin(size: 60 * 1024 * 1024));
      final s = proxy.register(origin.url, const {});
      final c = HttpClient();
      final req = await c.getUrl(s.localUri);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final res = await req.close();
      var read = 0;
      final enough = Completer<void>();
      res.listen((d) {
        read += d.length;
        if (read > 1024 * 1024 && !enough.isCompleted) enough.complete();
      }, onError: (Object _) {});
      await enough.future;
      c.close(force: true);
      await waitFor(() => origin.open == 0);
      await waitFor(() => s.activeCount == 0);
      final n = origin.accepted.length;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(origin.accepted.length, n);
      expect(n, 1);
    });
  });

  group('403 retry with a 1MiB chunk', () {
    test('origin that only accepts <= 2MB: first 8MiB request gets 403, then everything plays in 1MiB chunks', () async {
      await setUpOrigin(StrictOrigin(size: 5 * 1024 * 1024 + 123, maxSpan: 2 * 1000 * 1000));
      final s = proxy.register(origin.url, const {});
      final r = await fetchAndVerify(s.localUri, 'bytes=0-', 0);
      expect(r.status, 206);
      expect(r.length, origin.size);
      expect(r.intact, isTrue);
      expect(origin.rejected, ['bytes=0-8388607'], reason: 'exactly one rejection: the retry happens once');
      expect(origin.accepted.first, 'bytes=0-1048575');
      expect(origin.accepted.every((h) => endOf(h) - startOf(h) + 1 <= originRetryChunkBytes), isTrue);
      expect(s.chunkBytes, originRetryChunkBytes);
      expect(s.lastOriginRange, startsWith('bytes='));
      expect(s.lastError, isNull);
    });

    test('origin that always rejects: 403 reaches the player after exactly one retry, diagnostics carry the Range', () async {
      await setUpOrigin(StrictOrigin(always403: true));
      final s = proxy.register(origin.url, const {});
      final c = HttpClient();
      final req = await c.getUrl(s.localUri);
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
      final res = await req.close();
      await res.drain<void>();
      c.close(force: true);
      expect(res.statusCode, 403);
      expect(origin.rejected, ['bytes=0-8388607', 'bytes=0-1048575']);
      expect(s.lastError.toString(), 'OriginStatusException(403)');
      expect(s.lastOriginRange, 'bytes=0-1048575');
      expect(s.chunkBytes, originRetryChunkBytes);
      expect('${s.lastError}', isNot(contains('SECRETSIG')));
      expect(s.lastOriginRange, isNot(contains('SECRETSIG')));
    });

    test('the downgrade persists for the source: later requests start with 1MiB chunks, no second retry', () async {
      await setUpOrigin(StrictOrigin(size: 3 * 1000 * 1000, maxSpan: 2 * 1000 * 1000));
      final s = proxy.register(origin.url, const {});
      await fetchAndVerify(s.localUri, 'bytes=0-', 0);
      final rejectedBefore = origin.rejected.length;
      final r = await fetchAndVerify(s.localUri, 'bytes=1000000-', 1000000);
      expect(r.intact, isTrue);
      expect(r.length, origin.size - 1000000);
      expect(origin.rejected.length, rejectedBefore);
    });
  });
}

Future<void> waitFor(bool Function() ok) async {
  final sw = Stopwatch()..start();
  while (!ok()) {
    if (sw.elapsed > const Duration(seconds: 5)) fail('timed out waiting for condition');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
