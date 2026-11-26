// StreamAudioSource وStreamAudioResponse موسومتان @experimental في just_audio.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'range_fetcher.dart';

/// رفض الخادم طلب Range (403 مثلاً). just_audio يحوّل أي رمي هنا إلى 500 لـExoPlayer.
class RangeHttpException implements Exception {
  const RangeHttpException(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'RangeHttpException($statusCode)';
}

/// مصدر صوت يجلب كل طلب Range بنفسه عبر Dart (D26).
///
/// على أندرويد يخدمه just_audio من وكيله المحلي (http://127.0.0.1، مسموح في
/// network_security_config): ExoPlayer → الوكيل → [request] (start/end من ترويسة
/// Range) → [fetchRange] بترويسات العميل الصحيحة (User-Agent دون إضافة dart:io).
class YtStreamAudioSource extends StreamAudioSource {
  YtStreamAudioSource(this.url, this.headers, {RangeFetch? fetch, super.tag}) : _fetch = fetch ?? defaultRangeFetch;

  final Uri url;
  final Map<String, String> headers;
  final RangeFetch _fetch;
  final _active = <RangeFetchResult>{};
  bool _closed = false;
  int _seq = 0;

  bool get isClosed => _closed;

  /// للاختبار: دالة الجلب المستعملة (الافتراضية = [defaultRangeFetch]، نفس الفحص).
  RangeFetch get fetcher => _fetch;

  /// ExoPlayer يقرأ الملف التقدّمي من اتصال واحد، فطلب Range جديد يعني أن السابق
  /// تُرك (قفز). just_audio لا يلغي اشتراكنا حين ينقطع عميله، فنقطع السابق هنا
  /// كي لا يبقى اتصاله بالأصل معلّقاً حتى مهلة الخمول.
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (_closed) throw StateError('source closed');
    final seq = ++_seq;
    _cancelActive();
    final r = await _fetch(url, headers, start: start, end: end);
    if (_closed) {
      r.cancel();
      throw StateError('source closed');
    }
    if (seq != _seq) {
      // وصل طلب أحدث أثناء الجلب: هذا متروك.
      r.cancel();
      throw StateError('superseded by a newer request');
    }
    if (!r.ok) {
      r.cancel();
      throw RangeHttpException(r.statusCode);
    }
    // just_audio يفترض contentLength غير null مع Range، وإلا رمى بعد كتابة
    // الترويسات فعلق الطلب؛ نرمي قبلها فيرد 500.
    if (r.contentLength == null) {
      r.cancel();
      throw RangeHttpException(r.statusCode);
    }
    _active.add(r);
    StreamSubscription<List<int>>? sub;
    late final StreamController<List<int>> body;
    body = StreamController<List<int>>(
      onListen: () {
        sub = r.body.listen(
          body.add,
          onDone: () {
            _active.remove(r);
            body.close();
          },
        );
      },
      onPause: () => sub?.pause(),
      onResume: () => sub?.resume(),
      onCancel: () {
        // الإلغاء لا يمر بـonDone: احذفه هنا أيضاً.
        _active.remove(r);
        return sub?.cancel();
      },
    );
    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: r.sourceLength,
      contentLength: r.contentLength,
      offset: r.offset,
      stream: body.stream,
      contentType: r.contentType,
    );
  }

  void _cancelActive() {
    final all = _active.toList();
    _active.clear();
    for (final r in all) {
      try {
        r.cancel();
      } catch (_) {
        // إغلاق طلب لا يمنع إغلاق البقية.
      }
    }
  }

  /// يقطع كل الطلبات الجارية ويرفض الجديدة (عند تبديل المصدر أو الإيقاف). لا يرمي.
  void close() {
    _closed = true;
    _cancelActive();
  }
}
