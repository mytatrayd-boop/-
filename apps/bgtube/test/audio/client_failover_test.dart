import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:bgtube/audio/local_stream_proxy.dart';
import 'package:bgtube/audio/range_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chunked_origin_test.dart' show byteAt, endOf, fetchAndVerify, startOf;

const mib = 1024 * 1024;

/// سلوك عميل واحد عند الأصل: يقبل فقط Range الذي ينتهي عند [cap] أو قبله
/// (null = بلا سقف)، وإلا 403. [size] الطول الكلي كما يعلنه هذا العميل.
class ClientBehavior {
  ClientBehavior({this.cap, this.size = 5 * mib});
  final int? cap;
  final int size;
}

/// أصل يميّز العميل بمعامل `c` في الرابط (كرابط googlevideo موقّع لكل عميل).
class MultiClientOrigin {
  MultiClientOrigin(this.clients);

  final Map<String, ClientBehavior> clients;
  late HttpServer server;
  final accepted = <(String, int, int)>[]; // (client, start, end)
  final rejected = <(String, String?)>[];
  int open = 0;
  int maxOpen = 0;

  Uri urlFor(String client) => Uri.parse('http://127.0.0.1:${server.port}/videoplayback?c=$client&sig=SECRETSIG');

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = req.response;
      final client = req.uri.queryParameters['c'] ?? '';
      final b = clients[client]!;
      final header = req.headers.value(HttpHeaders.rangeHeader);
      final m = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(header ?? '');
      if (m == null || m[2]!.isEmpty) {
        rejected.add((client, header));
        res.statusCode = 403;
        await res.close();
        return;
      }
      final a = int.parse(m[1]!);
      final end = min(int.parse(m[2]!), b.size - 1);
      if (b.cap != null && end + 1 > b.cap!) {
        rejected.add((client, header));
        res.statusCode = 403;
        await res.close();
        return;
      }
      if (a >= b.size) {
        res.statusCode = 416;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */${b.size}');
        await res.close();
        return;
      }
      accepted.add((client, a, end));
      res.statusCode = 206;
      res.headers.contentType = ContentType('audio', 'mp4');
      res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $a-$end/${b.size}');
      res.contentLength = end - a + 1;
      open++;
      maxOpen = max(maxOpen, open);
      var gone = false;
      unawaited(res.done.then((_) {}, onError: (Object _) {}).whenComplete(() {
        open--;
        gone = true;
      }));
      Stream<List<int>> gen() async* {
        var p = a;
        while (p <= end && !gone) {
          final n = min(64 * 1024, end - p + 1);
          final buf = Uint8List(n);
          for (var i = 0; i < n; i++) {
            buf[i] = byteAt(p + i);
          }
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

  Future<void> stop() => server.close(force: true);
}

Future<void> waitFor(bool Function() ok) async {
  for (var i = 0; i < 200 && !ok(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  expect(ok(), isTrue);
}

void main() {
  late MultiClientOrigin origin;
  late LocalStreamProxy proxy;

  Future<void> setUp0(Map<String, ClientBehavior> clients) async {
    origin = MultiClientOrigin(clients);
    await origin.start();
    proxy = LocalStreamProxy();
    await proxy.start();
  }

  tearDown(() async {
    await proxy.close();
    await origin.stop();
  });

  /// بدائل بالترتيب؛ تسجّل ما طُلب (أسماء العملاء المجرَّبة فقط).
  ({OriginFailover cb, List<Set<String>> calls}) failoverOver(List<String> order, {Duration delay = Duration.zero}) {
    final calls = <Set<String>>[];
    Future<AlternateOrigin?> cb(Set<String> tried) async {
      calls.add({...tried});
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      for (final c in order) {
        if (!tried.contains(c)) return (url: origin.urlFor(c), headers: {'User-Agent': 'UA-$c'}, client: c);
      }
      return null;
    }

    return (cb: cb, calls: calls);
  }

  group('client failover on 403 after the first chunk (D24)', () {
    test('A serves the first 1MiB then 403s; B takes over from the same byte; bytes intact, one origin connection', () async {
      await setUp0({
        'A': ClientBehavior(cap: mib), // يرفض 8MiB ثم أي قطعة بعد أول 1MiB
        'B': ClientBehavior(),
      });
      final f = failoverOver(['A', 'B']);
      final s = proxy.register(origin.urlFor('A'), const {'User-Agent': 'UA-A'}, failover: f.cb);
      final r = await fetchAndVerify(s.localUri, 'bytes=0-', 0);
      expect(r.status, 206);
      expect(r.length, 5 * mib);
      expect(r.intact, isTrue, reason: 'every byte at its right offset across the switch');
      expect(r.headers.contentLength, 5 * mib);
      expect(r.headers.value(HttpHeaders.contentRangeHeader), 'bytes 0-${5 * mib - 1}/${5 * mib}');

      expect(f.calls, [
        {'A'}
      ]); // الاستدعاء يحمل أسماء العملاء فقط، لا روابط
      expect(s.client, 'B');
      expect(s.switches, 1);
      // A أعطى أول 1MiB فقط ثم B أكمل من البايت نفسه.
      expect(origin.accepted.where((e) => e.$1 == 'A').map((e) => (e.$2, e.$3)), [(0, mib - 1)]);
      final b = origin.accepted.where((e) => e.$1 == 'B').toList();
      expect(b.first.$2, mib);
      expect(b.last.$3, 5 * mib - 1);
      // لا قطعتان متزامنتان من الأصل أبداً.
      expect(origin.maxOpen, 1);
      // التشخيص يحتفظ بآخر فشل بعد الاكتمال: العميل A عند البايت 1MiB بالحالة 403.
      final fail = s.lastFailure!;
      expect((fail.client, fail.byte, fail.status, fail.switches), ('A', mib, 403, 0));
      expect(fail.toString(), 'client=A byte=$mib chunk#2 status=403 switches=0');
      await waitFor(() => s.activeCount == 0);
    });

    test('a seek after the switch keeps using B (no second switch)', () async {
      await setUp0({'A': ClientBehavior(cap: mib), 'B': ClientBehavior()});
      final f = failoverOver(['A', 'B']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      await fetchAndVerify(s.localUri, 'bytes=0-', 0);
      final r = await fetchAndVerify(s.localUri, 'bytes=3000000-', 3000000);
      expect(r.intact, isTrue);
      expect(r.length, 5 * mib - 3000000);
      expect(f.calls.length, 1);
    });

    test('fails over through several clients up to the cap, then fails explicitly with 403', () async {
      await setUp0({
        'A': ClientBehavior(cap: mib),
        'B': ClientBehavior(cap: mib),
        'C': ClientBehavior(cap: mib),
        'D': ClientBehavior(cap: mib),
        'E': ClientBehavior(), // لن يُجرَّب: الحد 3 تبديلات
      });
      final f = failoverOver(['A', 'B', 'C', 'D', 'E']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      // أول طلب يثبّت الطول من A.
      var r = await fetchAndVerify(s.localUri, 'bytes=0-99', 0);
      expect(r.length, 100);
      expect(r.status, 206);
      // قفزة بعد 1MiB: كل العملاء يرفضون.
      r = await fetchAndVerify(s.localUri, 'bytes=${2 * mib}-${2 * mib + 99}', 2 * mib);
      expect(r.status, 403);
      expect(f.calls.length, maxClientSwitches);
      expect(f.calls.last, {'A', 'B', 'C'});
      expect(s.switches, maxClientSwitches);
      expect(origin.accepted.any((e) => e.$1 == 'E'), isFalse);
      expect(s.lastError, isA<OriginStatusException>());
      final fail = s.lastFailure!;
      expect((fail.client, fail.byte, fail.status, fail.switches), ('D', 2 * mib, 403, 3));
      expect('proxy-line: $fail', contains('client=D'));
      expect(fail.toString(), isNot(contains('SECRETSIG')));
      expect(fail.toString(), isNot(contains('http')));
    });

    test('no alternative left (callback returns null): the 403 is passed to the player at once', () async {
      await setUp0({'A': ClientBehavior(cap: mib)});
      final f = failoverOver(['A']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      final r = await fetchAndVerify(s.localUri, 'bytes=${2 * mib}-${2 * mib + 9}', 2 * mib);
      expect(r.status, 403);
      expect(f.calls.length, 1);
      expect(s.switches, 0);
      expect(s.lastFailure!.client, 'A');
    });

    test('playback that dies mid-body: mid-stream 403 with every client failing ends the body short (player retries) and records why', () async {
      await setUp0({
        'A': ClientBehavior(cap: mib),
        'B': ClientBehavior(cap: mib),
      });
      final f = failoverOver(['A', 'B']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      var got = 0;
      try {
        await fetchAndVerify(s.localUri, 'bytes=0-', 0);
      } catch (_) {
        got = -1; // الاتصال قُطع قبل اكتمال Content-Length
      }
      expect(got, -1);
      final fail = s.lastFailure!;
      expect(fail.byte, mib);
      expect(fail.status, 403);
      expect(fail.client, 'B');
      expect(fail.switches, 1);
      expect(s.lastError, isA<OriginStatusException>());
    });

    test('a client with a different total length is skipped: the next client (within the cap) finishes with intact bytes', () async {
      await setUp0({
        'A': ClientBehavior(cap: mib, size: 5 * mib),
        'B': ClientBehavior(size: 5 * mib + 123),
        'C': ClientBehavior(size: 5 * mib),
      });
      final f = failoverOver(['A', 'B', 'C']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      expect((await fetchAndVerify(s.localUri, 'bytes=0-99', 0)).status, 206); // الطول الكلي 5MiB معروف
      final r = await fetchAndVerify(s.localUri, 'bytes=${2 * mib}-', 2 * mib);
      expect(r.status, 206);
      expect(r.intact, isTrue);
      expect(r.length, 3 * mib);
      expect(s.client, 'C');
      expect(s.switches, 2);
      expect(f.calls, [
        {'A'},
        {'A', 'B'}
      ]);
    });

    test('every alternative has another length: explicit 502 (never mixes two files)', () async {
      await setUp0({
        'A': ClientBehavior(cap: mib, size: 5 * mib),
        'B': ClientBehavior(size: 5 * mib + 123),
        'C': ClientBehavior(size: 5 * mib + 456),
      });
      final f = failoverOver(['A', 'B', 'C']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      await fetchAndVerify(s.localUri, 'bytes=0-99', 0);
      final r = await fetchAndVerify(s.localUri, 'bytes=${2 * mib}-${2 * mib + 99}', 2 * mib);
      expect(r.status, 502);
      expect(s.lastError, isA<OriginLengthMismatchException>());
      expect(origin.open, 0);
      await waitFor(() => s.activeCount == 0);
    });

    test('once the callback returned null it is never called again for this source', () async {
      await setUp0({'A': ClientBehavior(cap: mib)});
      final f = failoverOver(['A']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      for (var i = 0; i < 4; i++) {
        final r = await fetchAndVerify(s.localUri, 'bytes=${(2 + i) * mib}-${(2 + i) * mib + 9}', (2 + i) * mib);
        expect(r.status, 403);
      }
      expect(f.calls.length, 1);
    });

    test('a throwing callback is not called again either', () async {
      await setUp0({'A': ClientBehavior(cap: mib)});
      var n = 0;
      final s = proxy.register(origin.urlFor('A'), const {}, failover: (_) async {
        n++;
        throw StateError('boom');
      });
      for (var i = 0; i < 3; i++) {
        await fetchAndVerify(s.localUri, 'bytes=${2 * mib}-${2 * mib + 9}', 2 * mib);
      }
      expect(n, 1);
    });

    test('a 416 or 2xx never records a failure', () async {
      await setUp0({'A': ClientBehavior()});
      final s = proxy.register(origin.urlFor('A'), const {});
      await fetchAndVerify(s.localUri, 'bytes=0-99', 0);
      expect(s.lastFailure, isNull);
      final r = await fetchAndVerify(s.localUri, 'bytes=${6 * mib}-', 0);
      expect(r.status, 416);
      expect(s.lastFailure, isNull);
    });

    test('a late 403 from the replaced client is not blamed on the new one (its chunk size stays 8MiB)', () async {
      final heldA = Completer<void>();
      final bRanges = <String>[];
      var aCalls = 0;
      RangeFetchResult res(int status, int start, int end) => RangeFetchResult(
            statusCode: status,
            offset: start,
            contentLength: status == 206 ? 100 : 0,
            sourceLength: 5 * mib,
            contentType: 'audio/mp4',
            body: Stream.value(List<int>.filled(100, 1)),
            cancel: () {},
          );
      Future<RangeFetchResult> fake(Uri url, Map<String, String> h, {int? start, int? end}) async {
        final c = url.queryParameters['c'];
        if (c == 'B') {
          bRanges.add(originRangeHeader(start!, end));
          return res(206, start, end!);
        }
        aCalls++;
        if (aCalls == 1) await heldA.future; // طلب قديم يتأخر رفضه
        return res(403, start!, end!);
      }

      proxy = LocalStreamProxy(fetch: fake);
      origin = MultiClientOrigin({});
      await origin.start();
      await proxy.start();
      final f = Completer<void>();
      final s = proxy.register(Uri.parse('http://x/v?c=A'), const {}, failover: (tried) async {
        f.complete();
        return (url: Uri.parse('http://x/v?c=B'), headers: const <String, String>{}, client: 'B');
      });
      final r1 = fetchAndVerify(s.localUri, 'bytes=${2 * mib}-', 2 * mib).then<int>((r) => r.status, onError: (_) => -1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final r2 = fetchAndVerify(s.localUri, 'bytes=${2 * mib}-', 2 * mib).then<int>((r) => r.status, onError: (_) => -1);
      await f.future; // التبديل جرى بطلب 2
      await Future<void>.delayed(const Duration(milliseconds: 100));
      heldA.complete(); // الآن يصل 403 القديم
      await Future.wait([r1, r2]);
      expect(s.client, 'B');
      expect(s.chunkBytes, originChunkBytes);
      expect(bRanges, isNotEmpty);
      for (final h in bRanges) {
        // لا 1MiB: لم يُخفَّض حجم قطعة B.
        expect(endOf(h) - startOf(h) + 1, isNot(originRetryChunkBytes), reason: h);
      }
    });

    test('a failing callback is treated as no alternative', () async {
      await setUp0({'A': ClientBehavior(cap: mib)});
      final s = proxy.register(origin.urlFor('A'), const {}, failover: (_) async => throw StateError('boom'));
      final r = await fetchAndVerify(s.localUri, 'bytes=${2 * mib}-${2 * mib + 9}', 2 * mib);
      expect(r.status, 403);
    });

    test('concurrent requests during a switch trigger one switch only (latest wins)', () async {
      await setUp0({'A': ClientBehavior(cap: mib), 'B': ClientBehavior()});
      final f = failoverOver(['A', 'B'], delay: const Duration(milliseconds: 300));
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      final first = fetchAndVerify(s.localUri, 'bytes=${2 * mib}-', 2 * mib).then<int>((r) => r.status, onError: (_) => -1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final second = await fetchAndVerify(s.localUri, 'bytes=${3 * mib}-', 3 * mib);
      await first;
      expect(second.status, 206);
      expect(second.intact, isTrue);
      expect(second.length, 2 * mib);
      expect(f.calls.length, 1);
      expect(s.client, 'B');
    });

    test('without a failover the 403 behaves as before (one 1MiB retry, then passed through)', () async {
      await setUp0({'A': ClientBehavior(cap: mib)});
      final s = proxy.register(origin.urlFor('A'), const {});
      final r = await fetchAndVerify(s.localUri, 'bytes=${2 * mib}-${2 * mib + 9}', 2 * mib);
      expect(r.status, 403);
      expect(s.switches, 0);
      expect(s.lastFailure!.byte, 2 * mib);
    });

    test('after a switch the new client is tried with the big chunk again (the 1MiB limit was A-specific)', () async {
      await setUp0({'A': ClientBehavior(cap: mib), 'B': ClientBehavior()});
      final f = failoverOver(['A', 'B']);
      final s = proxy.register(origin.urlFor('A'), const {}, failover: f.cb);
      await fetchAndVerify(s.localUri, 'bytes=0-', 0);
      expect(s.chunkBytes, originChunkBytes);
      expect(origin.rejected.where((e) => e.$1 == 'B'), isEmpty);
    });
  });
}
