import 'dart:async';
import 'dart:convert';

import 'package:adeeb/ask/ask_api.dart';
import 'package:adeeb/ask/ask_passages.dart';
import 'package:adeeb/core/device_id.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ask_server.dart';

const _text = 'هذه فقرة اختبار اصطناعية فيها كلمات كافية للاقتباس منها.';

final _passages = [
  const AskPassage(
    paragraph: LocalParagraph(
      id: 'aa-b001-p00001',
      bookId: 'aa',
      bookTitle: 'كتاب',
      chapterTitle: 'باب',
      text: _text,
    ),
    sentText: _text,
  ),
];

void main() {
  late FakeAskServer server;
  final deviceId = generateUuidV4();

  HttpAskApi api({
    Duration timeout = askTimeout,
    String base = testAskBaseUrl,
  }) => HttpAskApi(
    client: server.client(),
    baseUri: Uri.parse(base),
    deviceId: () async => deviceId,
    clientHeader: 'adeeb-android/1',
    timeout: timeout,
  );

  Future<AskReply> ask(HttpAskApi a, {Future<void>? cancel}) => a.ask(
    question: 'سؤال اختبار',
    lang: 'ar',
    passages: _passages,
    cancel: cancel,
  );

  Future<AskFailure> failureOf(Future<Object?> f) async {
    try {
      await f;
    } on AskApiException catch (e) {
      return e.failure;
    }
    fail('لم يفشل الطلب');
  }

  setUp(() => server = FakeAskServer());

  test('الطلب يطابق العقد: المسار والترويسات والجسم', () async {
    final reply = await ask(api());
    expect(reply.found, isTrue);
    expect(reply.remaining, 9);
    final r = server.requests.single;
    expect(r.method, 'POST');
    expect(r.url.toString(), '${testAskBaseUrl}v1/ask');
    expect(r.headers['X-Device-Id'], deviceId);
    expect(r.headers['X-Client'], 'adeeb-android/1');
    expect(r.headers['Content-Type'], startsWith('application/json'));
    expect(r.headers.containsKey('Origin'), isFalse);
    expect(jsonDecode(r.body), {
      'v': 1,
      'lang': 'ar',
      'question': 'سؤال اختبار',
      'passages': [
        {
          'id': 'aa-b001-p00001',
          'book': 'كتاب',
          'chapter': 'باب',
          'text': _text,
        },
      ],
    });
  });

  test('quota: GET على /v1/quota', () async {
    await api().quota();
    expect(server.requests.single.url.toString(), '${testAskBaseUrl}v1/quota');
    expect(server.requests.single.method, 'GET');
  });

  test('quota: limit وremaining', () async {
    server.remaining = 7;
    final q = await api().quota();
    expect((q.limit, q.remaining), (10, 7));
  });

  test('found=false: NOT_FOUND وUNVERIFIED', () async {
    for (final (reason, expected) in [
      ('NOT_FOUND', NotFoundReason.notFound),
      ('UNVERIFIED', NotFoundReason.unverified),
    ]) {
      server.onAsk = (_) => (
        200,
        jsonEncode({
          'found': false,
          'answer': '',
          'citations': [],
          'reason': reason,
          'remaining': 3,
        }),
      );
      final reply = await ask(api());
      expect(reply.found, isFalse);
      expect(reply.reason, expected);
      expect(reply.remaining, 3);
    }
  });

  group('رموز الأخطاء', () {
    final cases = <(int, String, AskFailure)>[
      (
        429,
        '{"code":"DAILY_LIMIT","remaining":0,"retry_after":3600}',
        AskFailure.dailyLimit,
      ),
      (429, '{"code":"RATE_LIMIT","retry_after":60}', AskFailure.rateLimit),
      (426, '{"code":"UPGRADE_REQUIRED"}', AskFailure.upgradeRequired),
      (400, '{"code":"BAD_REQUEST"}', AskFailure.badRequest),
      (503, '{"code":"UNAVAILABLE","remaining":5}', AskFailure.unavailable),
      (403, '{"code":"FORBIDDEN"}', AskFailure.unavailable),
      (404, '{"code":"NOT_FOUND"}', AskFailure.unavailable),
      (405, '{"code":"METHOD_NOT_ALLOWED"}', AskFailure.unavailable),
      (500, '<html>Error 1027</html>', AskFailure.unavailable),
      (502, '', AskFailure.unavailable),
      (429, '<html>Too many</html>', AskFailure.unavailable),
      (429, '{"code":"UNAVAILABLE"}', AskFailure.unavailable),
    ];
    for (final (status, body, expected) in cases) {
      test('$status $body ← $expected', () async {
        server.onAsk = (_) => (status, body);
        expect(await failureOf(ask(api())), expected);
      });
    }

    test('DAILY_LIMIT يحمل remaining=0 وretry_after', () async {
      server.onAsk = (_) =>
          (429, '{"code":"DAILY_LIMIT","remaining":0,"retry_after":120}');
      try {
        await ask(api());
        fail('لم يفشل');
      } on AskApiException catch (e) {
        expect(e.remaining, 0);
        expect(e.retryAfter, 120);
      }
    });
  });

  group('رد 200 لا يطابق العقد = UNAVAILABLE', () {
    final bodies = <String>[
      '<!DOCTYPE html><html>Cloudflare</html>',
      'null',
      '[]',
      '{"found":true,"answer":"x","citations":[],"remaining":1}',
      '{"found":true,"answer":"","citations":[{"paragraph_id":"a","quote":"b"}],"remaining":1}',
      '{"found":true,"answer":"x","citations":[{"paragraph_id":1,"quote":"b"}],"remaining":1}',
      '{"found":true,"answer":"x","citations":[{"paragraph_id":"a","quote":"b"}]}',
      '{"found":false,"answer":"","citations":[],"remaining":1}',
      '{"found":false,"answer":"","citations":[],"reason":"OTHER","remaining":1}',
      '{"found":"yes","answer":"x","citations":[],"remaining":1}',
      '{"found":true,"answer":"x","citations":[{"paragraph_id":"a","quote":"b"}],"remaining":-1}',
    ];
    for (final body in bodies) {
      test(body, () async {
        server.onAsk = (_) => (200, body);
        expect(await failureOf(ask(api())), AskFailure.unavailable);
      });
    }
    test('quota بلا JSON', () async {
      server.quotaReply = (200, '<html></html>');
      expect(await failureOf(api().quota()), AskFailure.unavailable);
    });
  });

  test('انقطاع الشبكة ← offline', () async {
    server.offline = true;
    expect(await failureOf(ask(api())), AskFailure.offline);
  });

  test('المهلة ← timeout', () async {
    server.gate = Completer<void>();
    expect(
      await failureOf(ask(api(timeout: const Duration(milliseconds: 50)))),
      AskFailure.timeout,
    );
    server.gate!.complete();
  });

  test('الإلغاء ← cancelled', () async {
    server.gate = Completer<void>();
    final cancel = Completer<void>();
    final f = failureOf(ask(api(), cancel: cancel.future));
    cancel.complete();
    expect(await f, AskFailure.cancelled);
    server.gate!.complete();
  });

  test('بلا رابط ← notConfigured بلا أي طلب', () async {
    final a = HttpAskApi(
      client: server.client(),
      baseUri: null,
      deviceId: () async => deviceId,
      clientHeader: 'adeeb-android/1',
    );
    expect(await failureOf(ask(a)), AskFailure.notConfigured);
    expect(await failureOf(a.quota()), AskFailure.notConfigured);
    expect(server.requests, isEmpty);
  });
}
