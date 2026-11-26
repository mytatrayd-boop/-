import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart' show PlayerException, PlayerInterruptedException;

/// فحص سريع لرابط الصوت بعد فشل المشغّل: يعيد نصاً قصيراً مثل `probe HTTP 403`.
/// يفصل بين "الخادم يرفض الرابط" و"المشغّل لا يستطيع فكّ الصوت".
typedef StreamProbe = Future<String> Function(Uri url, Map<String, String> headers);

/// يطلب أول بايتين فقط بنفس ترويسات المشغّل. لا يرمي أبداً.
Future<String> httpStreamProbe(
  Uri url,
  Map<String, String> headers, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final c = client ?? http.Client();
  try {
    final req = http.Request('GET', url)
      ..headers.addAll(headers)
      ..headers['Range'] = 'bytes=0-1';
    final res = await c.send(req).timeout(timeout);
    unawaited(res.stream.drain<void>().catchError((Object _) {}));
    return 'probe HTTP ${res.statusCode}';
  } catch (e) {
    return 'probe ${e.runtimeType}';
  } finally {
    if (client == null) c.close();
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
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return s.length <= maxDetailLength ? s : '${s.substring(0, maxDetailLength - 1)}…';
}
