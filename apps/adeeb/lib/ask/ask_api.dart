/// عميل الخادم الوسيط (ARCHITECTURE §8.1، العقد الفعلي في `worker/src/app.ts`)
/// خلف واجهة قابلة للاستبدال [AskApi]. أي رد لا يطابق العقد (ليس JSON، صفحة
/// خطأ Cloudflare، رمز غير معروف) = [AskFailure.unavailable]. Dart صافٍ.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/network_errors.dart';
import 'ask_passages.dart';
import 'quote_verifier.dart';

/// سبب فشل الطلب كما يراه التطبيق.
enum AskFailure {
  /// لا اتصال (فشل الطلب قبل أي رد).
  offline,

  /// تجاوز المهلة (DESIGN §12.3: يُعامل كتعطّل الخادم).
  timeout,

  /// 429 DAILY_LIMIT: انتهت حصة اليوم.
  dailyLimit,

  /// 429 RATE_LIMIT: أسئلة كثيرة متتالية.
  rateLimit,

  /// 503 UNAVAILABLE، أو 403/404/405، أو 5xx، أو رد لا يطابق العقد.
  unavailable,

  /// 426 UPGRADE_REQUIRED.
  upgradeRequired,

  /// 400 BAD_REQUEST (لا يُتوقع من التطبيق السليم).
  badRequest,

  /// رابط الخادم غير مضبوط في `config/app_config.json`.
  notConfigured,

  /// ألغاه المستخدم.
  cancelled,
}

class AskApiException implements Exception {
  const AskApiException(this.failure, {this.remaining, this.retryAfter});

  final AskFailure failure;

  /// `remaining` إن حمله الرد (مثلاً 0 مع DAILY_LIMIT).
  final int? remaining;

  /// `retry_after` بالثواني إن وُجد.
  final int? retryAfter;

  @override
  String toString() => 'AskApiException($failure)';
}

/// `reason` عند `found=false` (D24).
enum NotFoundReason { notFound, unverified }

/// رد 200 من `POST /v1/ask` بعد التحقق من مطابقته للعقد.
class AskReply {
  const AskReply({
    required this.found,
    required this.answer,
    required this.citations,
    required this.remaining,
    this.reason,
  });

  final bool found;
  final String answer;
  final List<RawCitation> citations;
  final int remaining;
  final NotFoundReason? reason;
}

/// رد `GET /v1/quota`.
class QuotaInfo {
  const QuotaInfo({required this.limit, required this.remaining});
  final int limit;
  final int remaining;
}

abstract interface class AskApi {
  /// الرصيد بلا استهلاك (يُطلب عند فتح الشاشة فقط).
  Future<QuotaInfo> quota();

  /// يرسل السؤال والفقرات. يرمي [AskApiException] عند أي فشل.
  /// اكتمال [cancel] يلغي الطلب.
  Future<AskReply> ask({
    required String question,
    required String lang,
    required List<AskPassage> passages,
    Future<void>? cancel,
  });
}

/// الإصدار الحالي لجسم الطلب (`v`).
const askProtocolVersion = 1;

/// المهلة الكلية للطلب (DESIGN §12.3: بعد 30 ثانية يُعامل كتعطّل الخادم).
const askTimeout = Duration(seconds: 30);

class HttpAskApi implements AskApi {
  HttpAskApi({
    required this.client,
    required this.baseUri,
    required this.deviceId,
    required this.clientHeader,
    this.timeout = askTimeout,
  });

  final http.Client client;

  /// جذر الخادم (https) أو null إن لم يُضبط.
  final Uri? baseUri;

  /// معرّف الجهاز العشوائي (UUID v4).
  final Future<String> Function() deviceId;

  /// قيمة `X-Client`، مثل `adeeb-android/1`.
  final String clientHeader;
  final Duration timeout;

  Uri _endpoint(String path) {
    final base = baseUri;
    if (base == null) throw const AskApiException(AskFailure.notConfigured);
    return base.resolve(path);
  }

  @override
  Future<QuotaInfo> quota() async {
    final body = await _send('GET', _endpoint('v1/quota'));
    final json = _decodeObject(body.body);
    final limit = json?['limit'];
    final remaining = json?['remaining'];
    if (body.statusCode != 200 ||
        limit is! int ||
        remaining is! int ||
        limit < 0 ||
        remaining < 0) {
      throw _failureOf(body.statusCode, json);
    }
    return QuotaInfo(limit: limit, remaining: remaining);
  }

  @override
  Future<AskReply> ask({
    required String question,
    required String lang,
    required List<AskPassage> passages,
    Future<void>? cancel,
  }) async {
    final payload = jsonEncode({
      'v': askProtocolVersion,
      'lang': lang,
      'question': question,
      'passages': [for (final p in passages) p.toJson()],
    });
    final res = await _send(
      'POST',
      _endpoint('v1/ask'),
      body: payload,
      cancel: cancel,
    );
    final json = _decodeObject(res.body);
    if (res.statusCode != 200) throw _failureOf(res.statusCode, json);
    final reply = json == null ? null : parseAskReply(json);
    if (reply == null) throw const AskApiException(AskFailure.unavailable);
    return reply;
  }

  Future<http.Response> _send(
    String method,
    Uri url, {
    String? body,
    Future<void>? cancel,
  }) async {
    final id = await deviceId();
    final abort = Completer<void>();
    // يكتمل بخطأ عند المهلة أو الإلغاء، فيفوز في السباق أدناه.
    final aborted = Completer<http.Response>();
    void trigger() {
      if (!abort.isCompleted) abort.complete();
      if (!aborted.isCompleted) {
        aborted.completeError(http.RequestAbortedException(url));
      }
    }

    var timedOut = false;
    final timer = Timer(timeout, () {
      timedOut = true;
      trigger();
    });
    var cancelled = false;
    if (cancel != null) {
      unawaited(
        cancel.then((_) {
          cancelled = true;
          trigger();
        }),
      );
    }
    final request = http.AbortableRequest(
      method,
      url,
      abortTrigger: abort.future,
    );
    request.headers['X-Device-Id'] = id;
    request.headers['X-Client'] = clientHeader;
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(body);
    }
    Future<http.Response> run() async =>
        http.Response.fromStream(await client.send(request));
    try {
      // بعض العملاء (مثل MockClient) لا يدعمون الإلغاء؛ السباق يضمن المهلة.
      return await Future.any([run(), aborted.future]);
    } on Object catch (e) {
      if (cancelled) throw const AskApiException(AskFailure.cancelled);
      if (timedOut) throw const AskApiException(AskFailure.timeout);
      if (isNetworkError(e)) throw const AskApiException(AskFailure.offline);
      throw const AskApiException(AskFailure.unavailable);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }
}

Map<String, Object?>? _decodeObject(String body) {
  try {
    final json = jsonDecode(body);
    return json is Map<String, Object?> ? json : null;
  } on FormatException {
    return null;
  }
}

int? _nonNegativeInt(Object? v) => v is int && v >= 0 ? v : null;

/// رد خطأ: `{code, remaining?, retry_after?}` بحالة HTTP مطابقة للرمز، وإلا
/// UNAVAILABLE (D24: 403/404/405 وأي شيء غير متوقع).
AskApiException _failureOf(int status, Map<String, Object?>? json) {
  final code = json?['code'];
  final remaining = _nonNegativeInt(json?['remaining']);
  final retryAfter = _nonNegativeInt(json?['retry_after']);
  final failure = switch ((status, code)) {
    (429, 'DAILY_LIMIT') => AskFailure.dailyLimit,
    (429, 'RATE_LIMIT') => AskFailure.rateLimit,
    (426, 'UPGRADE_REQUIRED') => AskFailure.upgradeRequired,
    (400, 'BAD_REQUEST') => AskFailure.badRequest,
    _ => AskFailure.unavailable,
  };
  return AskApiException(
    failure,
    remaining: failure == AskFailure.dailyLimit ? (remaining ?? 0) : remaining,
    retryAfter: retryAfter,
  );
}

/// يتحقق من شكل رد 200 حرفياً حسب العقد، وإلا null.
AskReply? parseAskReply(Map<String, Object?> json) {
  final found = json['found'];
  final answer = json['answer'];
  final citations = json['citations'];
  final remaining = _nonNegativeInt(json['remaining']);
  if (found is! bool ||
      answer is! String ||
      citations is! List ||
      remaining == null) {
    return null;
  }
  final parsed = <RawCitation>[];
  for (final c in citations) {
    if (c is! Map) return null;
    final id = c['paragraph_id'];
    final quote = c['quote'];
    if (id is! String || quote is! String) return null;
    parsed.add(RawCitation(paragraphId: id, quote: quote));
  }
  if (found) {
    if (answer.trim().isEmpty || parsed.isEmpty) return null;
    return AskReply(
      found: true,
      answer: answer.trim(),
      citations: parsed,
      remaining: remaining,
    );
  }
  final reason = switch (json['reason']) {
    'NOT_FOUND' => NotFoundReason.notFound,
    'UNVERIFIED' => NotFoundReason.unverified,
    _ => null,
  };
  if (reason == null) return null;
  return AskReply(
    found: false,
    answer: '',
    citations: const [],
    remaining: remaining,
    reason: reason,
  );
}
