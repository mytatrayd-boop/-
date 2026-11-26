import 'dart:async';
import 'dart:io';

import 'socket_buffers.dart';

/// نتيجة طلب Range واحد. [body] لا يرمي أبداً: أي خطأ شبكة أو انقطاع أو خمول
/// يُنهيه (done) فلا يعلَق القارئ. [cancel] يقطع الاتصال فوراً.
class RangeFetchResult {
  RangeFetchResult({
    required this.statusCode,
    required this.offset,
    required this.contentLength,
    required this.sourceLength,
    required this.contentType,
    required this.body,
    required this.cancel,
  });

  final int statusCode;

  /// أول بايت في [body] ضمن الملف كله.
  final int offset;
  final int? contentLength;
  final int? sourceLength;
  final String contentType;
  final Stream<List<int>> body;
  final void Function() cancel;

  bool get ok => statusCode == HttpStatus.ok || statusCode == HttpStatus.partialContent;
}

/// حجم القطعة المطلوبة من الأصل (8MiB ≤ 9MB). googlevideo يرفض (403) Range
/// الكبير أو المفتوح لبعض العملاء، والمكتبات المرجعية تجلب بقطع ~10MB.
const originChunkBytes = 8 * 1024 * 1024;

/// القطعة بعد أول 403 (محاولة واحدة).
const originRetryChunkBytes = 1024 * 1024;

/// رأس Range كما يُرسل إلى الأصل لـ[start, end) (end حصري؛ null = مفتوح).
String originRangeHeader(int start, int? end) => 'bytes=$start-${end == null ? '' : end - 1}';

/// الجالب الوحيد للبايتات: يستعمله المشغّل (عبر LocalStreamProxy) والفحص معاً.
const RangeFetch defaultRangeFetch = fetchRange;

typedef RangeFetch = Future<RangeFetchResult> Function(
  Uri url,
  Map<String, String> headers, {
  int? start,
  int? end,
});

/// خطأ شبكة قبل وصول الرد. لا يحمل الرابط الموقّع ولا رسالة الخطأ الأصلية
/// (HttpException وغيره يضمّنان الرابط في نصّهما)، بل نوع السبب فقط.
class RangeFetchNetworkException implements Exception {
  const RangeFetchNetworkException(this.cause);

  /// نوع الخطأ الأصلي فقط، مثل `SocketException` أو `TimeoutException`.
  final String cause;
  @override
  String toString() => 'RangeFetchNetworkException($cause)';
}

/// يجلب [start, end) (end حصري؛ null = حتى النهاية) عبر HttpClient في Dart
/// بترويساتنا كما هي: `userAgent = null` كي لا يضيف dart:io "Dart/x (dart:io)"
/// فوق User-Agent العميل (D26)، وبلا ضغط كي تبقى إزاحات البايتات صحيحة.
/// أخطاء الاتصال قبل الرد تُرمى [RangeFetchNetworkException] (بلا رابط).
///
/// الجسم يحترم الضغط العكسي: إيقاف القارئ مؤقتاً يوقف القراءة من المقبس فيتوقف
/// الأصل عن الإرسال، ومهلة الخمول لا تُحسب أثناء الإيقاف (القارئ هو البطيء لا الأصل).
Future<RangeFetchResult> fetchRange(
  Uri url,
  Map<String, String> headers, {
  int? start,
  int? end,
  HttpClient Function()? clientFactory,
  Duration timeout = const Duration(seconds: 15),
  Duration idleTimeout = const Duration(seconds: 10),
  int? receiveBufferBytes = socketBufferBytes,
}) async {
  final client = (clientFactory ?? HttpClient.new)();
  // مخزن استقبال صغير: إيقاف القارئ يوقف الأصل بعد بضع مئات KB لا عشرات MB.
  if (receiveBufferBytes != null) {
    client.connectionFactory = limitedConnectionFactory(receiveBytes: receiveBufferBytes);
  }
  client
    ..userAgent = null
    ..autoUncompress = false
    ..connectionTimeout = timeout;
  final from = start ?? 0;
  try {
    final req = await client.getUrl(url).timeout(timeout);
    headers.forEach(req.headers.set);
    req.headers.set(HttpHeaders.rangeHeader, originRangeHeader(from, end));
    req.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    final res = await req.close().timeout(timeout);
    final type = res.headers.contentType?.mimeType ?? 'audio/mp4';
    final length = res.contentLength < 0 ? null : res.contentLength;

    var offset = from;
    int? contentLength = length;
    int? sourceLength;
    var skip = 0;
    if (res.statusCode == HttpStatus.partialContent) {
      final cr = parseContentRange(res.headers.value(HttpHeaders.contentRangeHeader));
      if (cr != null) {
        offset = cr.start;
        contentLength = cr.end - cr.start + 1;
        sourceLength = cr.total;
      }
    } else if (res.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
      // `bytes */1000`: الطول الكلي يلزم ExoPlayer ليفهم أن الموضع بعد النهاية.
      sourceLength = parseUnsatisfiedRange(res.headers.value(HttpHeaders.contentRangeHeader));
      contentLength = null;
    } else if (res.statusCode == HttpStatus.ok) {
      // الخادم تجاهل Range: الجسم من البداية؛ نتخطى حتى from.
      sourceLength = length;
      skip = from;
      contentLength = length == null ? null : length - from;
    }

    late final StreamController<List<int>> out;
    StreamSubscription<List<int>>? sub;
    Timer? idle;
    var closed = false;
    // لا نعتمد على out.hasListener: يصير false بعد إلغاء الاشتراك أيضاً، فيُظن
    // أن الجسم لم يُستمع إليه ونستمع إلى res مرة ثانية (Bad state).
    var listened = false;
    void finish() {
      if (closed) return;
      closed = true;
      idle?.cancel();
      sub?.cancel();
      client.close(force: true);
      out.close();
    }

    void armIdle() {
      idle?.cancel();
      idle = Timer(idleTimeout, finish);
    }

    out = StreamController<List<int>>(
      onListen: () {
        listened = true;
        // أُلغي قبل الاستماع: res سبق أن استُمع إليه لإغلاقه، والتيار مغلق.
        if (closed) return;
        armIdle();
        sub = res.listen(
          (chunk) {
            armIdle();
            if (skip > 0) {
              if (chunk.length <= skip) {
                skip -= chunk.length;
                return;
              }
              chunk = chunk.sublist(skip);
              skip = 0;
            }
            out.add(chunk);
          },
          onError: (Object _) => finish(),
          onDone: finish,
          cancelOnError: true,
        );
      },
      onPause: () {
        idle?.cancel();
        sub?.pause();
      },
      onResume: () {
        if (closed) return;
        armIdle();
        sub?.resume();
      },
      onCancel: finish,
    );

    return RangeFetchResult(
      statusCode: res.statusCode,
      offset: offset,
      contentLength: contentLength,
      sourceLength: sourceLength,
      contentType: type,
      body: out.stream,
      cancel: () {
        if (closed) return;
        if (!listened) {
          // لم يُستمع للجسم: أغلق الاتصال دون انتظار.
          closed = true;
          client.close(force: true);
          out.close();
          res.listen(null).cancel();
        } else {
          finish();
        }
      },
    );
  } catch (e) {
    client.close(force: true);
    throw RangeFetchNetworkException(e.runtimeType.toString());
  }
}

/// `bytes 0-99/1000` → (0, 99, 1000). total "*" → null.
({int start, int end, int? total})? parseContentRange(String? v) {
  if (v == null) return null;
  final m = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(v.trim());
  if (m == null) return null;
  return (start: int.parse(m[1]!), end: int.parse(m[2]!), total: int.tryParse(m[3]!));
}

/// `bytes */1000` (رد 416) → 1000؛ غير ذلك null.
int? parseUnsatisfiedRange(String? v) {
  if (v == null) return null;
  final m = RegExp(r'^bytes\s+\*/(\d+)$').firstMatch(v.trim());
  return m == null ? null : int.parse(m[1]!);
}
