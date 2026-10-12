/// خادم «اسأل الأديب» وهمي بعقد `worker/src/app.ts` (المسارات والترويسات
/// والرموز)، لاختبار العميل والشاشة دون شبكة.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const testAskBaseUrl = 'https://ask.example.test/';

class FakeAskServer {
  final requests = <http.Request>[];
  bool offline = false;
  int limit = 10;
  int remaining = 10;

  /// إن وُضع: رد `/v1/ask` (الحالة، الجسم الخام). وإلا: إجابة تقتبس أول
  /// ست كلمات من أول فقرة مرسلة، وتُخصم من [remaining].
  (int, String) Function(Map<String, Object?> body)? onAsk;

  /// إن وُضع: رد `/v1/quota`.
  (int, String)? quotaReply;

  /// إن وُضع: `/v1/ask` ينتظره قبل الرد (للانتظار والإلغاء والمهلة).
  Completer<void>? gate;

  List<Map<String, Object?>> get askBodies => [
    for (final r in requests)
      if (r.url.path == '/v1/ask') jsonDecode(r.body) as Map<String, Object?>,
  ];

  http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  /// إجابة صحيحة تقتبس من أول فقرة مرسلة.
  (int, String) quoteFirst(Map<String, Object?> body, {String? quote}) {
    final p = (body['passages']! as List).first as Map<String, Object?>;
    final words = (p['text']! as String).split(RegExp(r'\s+'));
    remaining--;
    return (
      200,
      jsonEncode({
        'found': true,
        'answer': 'إجابة اختبار موجزة.',
        'citations': [
          {'paragraph_id': p['id'], 'quote': quote ?? words.take(6).join(' ')},
        ],
        'remaining': remaining,
      }),
    );
  }

  http.Client client() => MockClient((request) async {
    requests.add(request);
    if (offline) throw http.ClientException('offline', request.url);
    switch (request.url.path) {
      case '/v1/quota':
        final reply = quotaReply;
        if (reply != null) {
          return http.Response(reply.$2, reply.$1);
        }
        return _json(200, {
          'limit': limit,
          'remaining': remaining,
          'resets_at': '2026-10-13T00:00:00.000Z',
        });
      case '/v1/ask':
        await gate?.future;
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final (status, raw) = (onAsk ?? quoteFirst)(body);
        return http.Response.bytes(utf8.encode(raw), status);
      default:
        return _json(404, {'code': 'NOT_FOUND'});
    }
  });
}
