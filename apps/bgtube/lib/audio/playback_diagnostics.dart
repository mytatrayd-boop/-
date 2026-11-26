import 'package:just_audio/just_audio.dart' show PlayerException, PlayerInterruptedException;

import 'range_fetcher.dart';

/// فحص سريع لرابط الصوت بعد فشل المشغّل: يعيد نصاً قصيراً مثل `probe HTTP 403`.
/// يفصل بين "الخادم يرفض الرابط" و"المشغّل لا يستطيع فكّ الصوت".
typedef StreamProbe = Future<String> Function(Uri url, Map<String, String> headers);

/// يطلب أول بايتين بدالة الجلب نفسها التي يستعملها المشغّل ([fetchRange]) وبنفس
/// الترويسات، فيطابق الفحص ما يرسله المشغّل فعلاً (D26). لا يرمي أبداً.
Future<String> httpStreamProbe(
  Uri url,
  Map<String, String> headers, {
  RangeFetch fetch = defaultRangeFetch,
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    final r = await fetch(url, headers, start: 0, end: 2).timeout(timeout);
    r.cancel();
    return 'probe HTTP ${r.statusCode}';
  } on RangeFetchNetworkException catch (e) {
    return 'probe ${e.cause}';
  } catch (e) {
    return 'probe ${e.runtimeType}';
  }
}

/// وصف قصير لخطأ المشغّل. على أندرويد `code` هو نوع ExoPlaybackException:
/// 0 = مصدر (شبكة/HTTP/تنسيق)، 1 = مُفكّك (ترميز)، 2 = غير متوقع.
String playerErrorDetail(Object e) => switch (e) {
      PlayerException(:final code, :final message) =>
        sanitizeDetail('PlayerException($code)${message == null ? '' : ' $message'}'),
      PlayerInterruptedException() => 'PlayerInterrupted',
      _ => e.runtimeType.toString(),
    };

const maxDetailLength = 140;

/// يزيل أي رابط ويضغط المسافات ويقصّ الطول: لا روابط موقّعة ولا رموز في الواجهة.
String sanitizeDetail(String raw) {
  final s = raw
      .replaceAll(RegExp(r'[a-zA-Z][a-zA-Z0-9+.-]*://\S*'), '<url>')
      .replaceAll(RegExp(r'\S*googlevideo\S*'), '<url>')
      // قيم موقّعة/معرّفة حتى بلا مضيف: ip= وsig= وsignature= وما شابه.
      .replaceAllMapped(
        RegExp(r'\b(ip|sig|lsig|signature|pot|key|token|access_token)=[^\s&]*', caseSensitive: false),
        (m) => '${m[1]}=<redacted>',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s.length <= maxDetailLength ? s : '${s.substring(0, maxDetailLength - 1)}…';
}
