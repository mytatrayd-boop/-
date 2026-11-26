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

  bool get isClosed => _closed;

  /// للاختبار: دالة الجلب المستعملة (الافتراضية = [defaultRangeFetch]، نفس الفحص).
  RangeFetch get fetcher => _fetch;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    if (_closed) throw StateError('source closed');
    final r = await _fetch(url, headers, start: start, end: end);
    if (_closed) {
      r.cancel();
      throw StateError('source closed');
    }
    if (!r.ok) {
      r.cancel();
      throw RangeHttpException(r.statusCode);
    }
    _active.add(r);
    final body = r.body.transform<List<int>>(
      StreamTransformer.fromHandlers(handleDone: (sink) {
        _active.remove(r);
        sink.close();
      }),
    );
    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: r.sourceLength,
      contentLength: r.contentLength,
      offset: r.offset,
      stream: body,
      contentType: r.contentType,
    );
  }

  /// يقطع كل الطلبات الجارية ويرفض الجديدة (عند تبديل المصدر أو الإيقاف).
  void close() {
    _closed = true;
    for (final r in _active.toList()) {
      r.cancel();
    }
    _active.clear();
  }
}
