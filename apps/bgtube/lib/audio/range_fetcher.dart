import 'dart:async';
import 'dart:io';

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

/// الجالب الوحيد للبايتات: يستعمله المشغّل (YtStreamAudioSource) والفحص معاً.
const RangeFetch defaultRangeFetch = fetchRange;

typedef RangeFetch = Future<RangeFetchResult> Function(
  Uri url,
  Map<String, String> headers, {
  int? start,
  int? end,
});

/// يجلب [start, end) (end حصري؛ null = حتى النهاية) عبر HttpClient في Dart
/// بترويساتنا كما هي: `userAgent = null` كي لا يضيف dart:io "Dart/x (dart:io)"
/// فوق User-Agent العميل (D26)، وبلا ضغط كي تبقى إزاحات البايتات صحيحة.
/// أخطاء الاتصال قبل الرد تُرمى (SocketException/HandshakeException/TimeoutException).
Future<RangeFetchResult> fetchRange(
  Uri url,
  Map<String, String> headers, {
  int? start,
  int? end,
  HttpClient Function()? clientFactory,
  Duration timeout = const Duration(seconds: 15),
  Duration idleTimeout = const Duration(seconds: 30),
}) async {
  final client = (clientFactory ?? HttpClient.new)()
    ..userAgent = null
    ..autoUncompress = false
    ..connectionTimeout = timeout;
  final from = start ?? 0;
  try {
    final req = await client.getUrl(url).timeout(timeout);
    headers.forEach(req.headers.set);
    req.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-${end == null ? '' : end - 1}');
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
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
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
        if (!out.hasListener) {
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
  } catch (_) {
    client.close(force: true);
    rethrow;
  }
}

/// `bytes 0-99/1000` → (0, 99, 1000). total "*" → null.
({int start, int end, int? total})? parseContentRange(String? v) {
  if (v == null) return null;
  final m = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$').firstMatch(v.trim());
  if (m == null) return null;
  return (start: int.parse(m[1]!), end: int.parse(m[2]!), total: int.tryParse(m[3]!));
}
