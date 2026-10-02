import 'dart:async';
import 'dart:io';

import 'package:durur/src/updates/update_fetcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// الطلب الفعلي عبر dart:io على خادم HTTP محلي (ARCHITECTURE §16.2، §16.9).
/// الخادم المحلي http (لا شهادة TLS في الاختبار) عبر المنشئ الصريح
/// `allowingHttpForTesting`؛ المنشئ الافتراضي يرفض كل مخطط غير https قبل أي
/// اتصال (اختبار أدناه)، وفرض https في UpdateConfig في data_updater_test.
void main() {
  late HttpServer server;
  late Uri base;
  final requests = <HttpRequest>[];
  final headers = <Map<String, List<String>>>[];
  late Future<void> Function(HttpRequest) handler;

  setUp(() async {
    requests.clear();
    headers.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}/');
    server.listen((request) async {
      requests.add(request);
      final h = <String, List<String>>{};
      request.headers.forEach((name, values) => h[name] = values);
      headers.add(h);
      await handler(request);
    });
  });

  tearDown(() => server.close(force: true));

  HttpUpdateFetcher fetcher({Duration timeout = const Duration(seconds: 5)}) =>
      HttpUpdateFetcher.allowingHttpForTesting(timeout: timeout);

  Matcher failsWith(FetchFailure f) => throwsA(
    isA<FetchException>().having((e) => e.failure, 'failure', f),
  );

  test('200: المحتوى كاملاً، وطلب GET بلا معاملات ولا كوكيز ولا معرّفات', () async {
    handler = (r) async {
      r.response
        ..headers.add('set-cookie', 'track=1')
        ..write('{"ok":true}');
      await r.response.close();
    };
    final f = fetcher();
    final bytes = await f.get(base.resolve('v1/manifest.json'), maxBytes: 4096);
    expect(String.fromCharCodes(bytes), '{"ok":true}');

    // طلب ثانٍ: الكوكي التي أرسلها الخادم لا تُعاد.
    await f.get(base.resolve('v1/manifest.json'), maxBytes: 4096);

    expect(requests, hasLength(2));
    for (final (i, r) in requests.indexed) {
      expect(r.method, 'GET');
      expect(r.uri.path, '/v1/manifest.json');
      expect(r.uri.hasQuery, isFalse);
      final h = headers[i];
      expect(h['user-agent'], ['durur']);
      expect(h.containsKey('cookie'), isFalse);
      expect(h.containsKey('authorization'), isFalse);
      expect(h.containsKey('if-none-match'), isFalse);
      // لا ترويسة غير الافتراضية: لا لغة ولا نسخة ولا معرّف جهاز.
      expect(
        h.keys.toSet().difference({
          'user-agent',
          'host',
          'accept-encoding',
          'content-length',
          'connection',
        }),
        isEmpty,
      );
    }
  });

  test('رابط بمعاملات ← يُرفض قبل أي طلب', () async {
    handler = (r) async => r.response.close();
    await expectLater(
      fetcher().get(base.resolve('v1/manifest.json?id=1'), maxBytes: 10),
      failsWith(FetchFailure.network),
    );
    expect(requests, isEmpty);
  });

  test('404 ← فشل', () async {
    handler = (r) async {
      r.response.statusCode = 404;
      await r.response.close();
    };
    await expectLater(
      fetcher().get(base.resolve('x'), maxBytes: 10),
      failsWith(FetchFailure.httpStatus),
    );
  });

  test('304 ← فشل (لا نرسل If-None-Match، فلا ننتظره)', () async {
    handler = (r) async {
      r.response.statusCode = 304;
      await r.response.close();
    };
    await expectLater(
      fetcher().get(base.resolve('x'), maxBytes: 10),
      failsWith(FetchFailure.httpStatus),
    );
  });

  test('مهلة: خادم لا يرد ← فشل بعد المهلة', () async {
    final hold = Completer<void>();
    handler = (r) => hold.future;
    final sw = Stopwatch()..start();
    await expectLater(
      fetcher(timeout: const Duration(milliseconds: 300))
          .get(base.resolve('x'), maxBytes: 10),
      failsWith(FetchFailure.timeout),
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    hold.complete();
  });

  test('حجم زائد (Content-Length) ← فشل', () async {
    handler = (r) async {
      r.response.write('x' * 100);
      await r.response.close();
    };
    await expectLater(
      fetcher().get(base.resolve('x'), maxBytes: 50),
      failsWith(FetchFailure.tooLarge),
    );
  });

  test('حجم زائد بلا Content-Length (مقطّع) ← يُقطع', () async {
    handler = (r) async {
      r.response.bufferOutput = false;
      for (var i = 0; i < 20; i++) {
        r.response.write('y' * 1000);
        await r.response.flush();
      }
      await r.response.close();
    };
    await expectLater(
      fetcher().get(base.resolve('x'), maxBytes: 4096),
      failsWith(FetchFailure.tooLarge),
    );
  });

  test('تحويل إلى المسار نفسه على النطاق نفسه ← مسموح', () async {
    handler = (r) async {
      if (r.uri.path == '/old') {
        await r.response.redirect(Uri.parse('/new'));
        return;
      }
      r.response.write('new');
      await r.response.close();
    };
    final bytes = await fetcher().get(base.resolve('old'), maxBytes: 10);
    expect(String.fromCharCodes(bytes), 'new');
  });

  test('تحويل إلى نطاق آخر ← فشل بلا متابعة', () async {
    handler = (r) async {
      await r.response.redirect(
        Uri.parse('http://localhost:${server.port}/elsewhere'),
      );
    };
    await expectLater(
      fetcher().get(base.resolve('x'), maxBytes: 10),
      failsWith(FetchFailure.redirect),
    );
    expect(requests.map((r) => r.uri.path), ['/x']);
  });

  test('بلا إنترنت (لا خادم) ← فشل شبكة', () async {
    final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = closed.port;
    await closed.close();
    await expectLater(
      fetcher().get(Uri.parse('http://127.0.0.1:$port/x'), maxBytes: 10),
      failsWith(FetchFailure.network),
    );
  });

  test('المنشئ الافتراضي (التطبيق) يرفض http وأي مخطط غير https بلا اتصال', () async {
    handler = (r) async {
      r.response.write('{}');
      await r.response.close();
    };
    for (final uri in [
      base.resolve('v1/manifest.json'), // http على خادم يعمل فعلاً
      Uri.parse('ftp://127.0.0.1:${server.port}/v1/manifest.json'),
      Uri.parse('file:///etc/hosts'),
      Uri.parse('https:///v1/manifest.json'), // بلا نطاق
    ]) {
      await expectLater(
        HttpUpdateFetcher().get(uri, maxBytes: 4096),
        failsWith(FetchFailure.network),
        reason: '$uri',
      );
    }
    expect(requests, isEmpty);
  });

  test('التحويل إلى مخطط آخر (http ← https) مرفوض حتى مع خيار الاختبار', () async {
    // خيار الاختبار يسمح ببدء http فقط؛ التحويل يجب أن يبقى على المخطط نفسه.
    handler = (r) async {
      r.response
        ..statusCode = HttpStatus.found
        ..headers.set(
          HttpHeaders.locationHeader,
          'https://127.0.0.1:${server.port}/y',
        );
      await r.response.close();
    };
    await expectLater(
      fetcher().get(base.resolve('x'), maxBytes: 10),
      failsWith(FetchFailure.redirect),
    );
    expect(requests.map((r) => r.uri.path), ['/x']);
  });
}
