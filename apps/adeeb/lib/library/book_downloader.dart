/// تنزيل ملف كتاب بتقدّم وإلغاء، مع رفض أي ملف يتجاوز الحجم المعلن أو لا
/// يطابق sha256 الفهرس (ARCHITECTURE §11). Dart صافٍ.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../core/network_errors.dart';

enum DownloadFailure {
  /// انقطع الاتصال أو لم يرد الخادم.
  network,

  /// رد الخادم بحالة غير 200.
  server,

  /// الحجم أو sha256 أو محتوى الملف لا يطابق الفهرس.
  integrity,
}

class BookDownloadException implements Exception {
  const BookDownloadException(this.failure, [this.detail]);
  final DownloadFailure failure;
  final String? detail;
  @override
  String toString() => 'BookDownloadException(${failure.name}: $detail)';
}

/// ألغى المستخدم التنزيل.
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();
}

class CancelToken {
  final _completer = Completer<void>();
  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

typedef ProgressCallback = void Function(int received, int total);

class BookDownloader {
  BookDownloader(this._client, {this.timeout = const Duration(seconds: 30)});

  final http.Client _client;

  /// أقصى انتظار لبدء الرد أو بين دفعتين من البيانات.
  final Duration timeout;

  Future<Uint8List> download(
    Uri url, {
    required String expectedSha256,
    required int expectedSize,
    ProgressCallback? onProgress,
    CancelToken? cancel,
  }) async {
    if (url.scheme != 'https') {
      throw const BookDownloadException(DownloadFailure.integrity, 'not https');
    }
    final token = cancel ?? CancelToken();
    if (token.isCancelled) throw const DownloadCancelledException();
    final request = http.AbortableRequest('GET', url, abortTrigger: token.whenCancelled);

    final http.StreamedResponse response;
    try {
      response = await Future.any([
        _client.send(request),
        token.whenCancelled.then<http.StreamedResponse>(
          (_) => throw const DownloadCancelledException(),
        ),
      ]).timeout(timeout);
    } on DownloadCancelledException {
      rethrow;
    } catch (e) {
      throw _mapError(e, token);
    }

    if (response.statusCode != 200) {
      // نستهلك الجسم حتى يُغلق الاتصال.
      unawaited(response.stream.drain<void>().catchError((_) {}));
      throw BookDownloadException(DownloadFailure.server, 'HTTP ${response.statusCode}');
    }
    final declared = response.contentLength;
    if (declared != null && declared > expectedSize) {
      unawaited(response.stream.drain<void>().catchError((_) {}));
      throw const BookDownloadException(DownloadFailure.integrity, 'larger than catalog');
    }

    final builder = BytesBuilder(copy: false);
    final done = Completer<void>();
    void fail(Object error) {
      if (!done.isCompleted) done.completeError(error);
    }

    late final StreamSubscription<List<int>> sub;
    // مهلة خمول تُعاد مع كل دفعة (بدل Stream.timeout).
    Timer? idle;
    void armIdle() {
      idle?.cancel();
      idle = Timer(timeout, () {
        unawaited(sub.cancel());
        fail(BookDownloadException(DownloadFailure.network, 'idle timeout'));
      });
    }

    sub = response.stream.listen(
      (chunk) {
        armIdle();
        builder.add(chunk);
        if (builder.length > expectedSize) {
          unawaited(sub.cancel());
          fail(const BookDownloadException(DownloadFailure.integrity, 'larger than catalog'));
          return;
        }
        onProgress?.call(builder.length, expectedSize);
      },
      onError: (Object e) {
        unawaited(sub.cancel());
        fail(_mapError(e, token));
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    armIdle();
    unawaited(token.whenCancelled.then((_) {
      unawaited(sub.cancel());
      fail(const DownloadCancelledException());
    }));

    try {
      await done.future;
    } finally {
      idle?.cancel();
    }
    final bytes = builder.takeBytes();
    if (bytes.length != expectedSize) {
      throw const BookDownloadException(DownloadFailure.integrity, 'size mismatch');
    }
    if (sha256.convert(bytes).toString() != expectedSha256) {
      throw const BookDownloadException(DownloadFailure.integrity, 'sha256 mismatch');
    }
    return bytes;
  }

  Exception _mapError(Object e, CancelToken token) {
    if (token.isCancelled || e is http.RequestAbortedException) {
      return const DownloadCancelledException();
    }
    if (isNetworkError(e)) {
      return BookDownloadException(DownloadFailure.network, e.toString());
    }
    return BookDownloadException(DownloadFailure.server, e.toString());
  }
}
