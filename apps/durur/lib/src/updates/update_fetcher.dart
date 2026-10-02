/// طلب ملف ثابت عبر `dart:io HttpClient` (ARCHITECTURE §16.2، D21).
///
/// GET فقط، بلا معاملات ولا كوكيز ولا معرّفات؛ `User-Agent` ثابت للجميع؛
/// مهلة كلية؛ حد للحجم يُقطع الاتصال عند تجاوزه؛ التحويل مسموح فقط إلى
/// المخطط والنطاق والمنفذ نفسها.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

/// سبب فشل الطلب (لا يُعرض للمستخدم).
enum FetchFailure { network, timeout, httpStatus, tooLarge, redirect }

class FetchException implements Exception {
  const FetchException(this.failure, [this.detail = '']);

  final FetchFailure failure;
  final String detail;

  @override
  String toString() => 'FetchException(${failure.name}): $detail';
}

/// يجلب ملفاً كاملاً أو يرمي [FetchException].
abstract interface class UpdateFetcher {
  Future<Uint8List> get(Uri uri, {required int maxBytes});
}

class HttpUpdateFetcher implements UpdateFetcher {
  HttpUpdateFetcher({
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 15),
    this.maxRedirects = 3,
  }) : _clientFactory = clientFactory ?? HttpClient.new,
       _allowHttp = false;

  /// للاختبارات فقط: يقبل `http` أيضاً (خادم محلي بلا شهادة TLS). التطبيق
  /// يستخدم المنشئ الافتراضي الذي يرفض كل مخطط غير `https` قبل أي اتصال.
  @visibleForTesting
  HttpUpdateFetcher.allowingHttpForTesting({
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 15),
    this.maxRedirects = 3,
  }) : _clientFactory = clientFactory ?? HttpClient.new,
       _allowHttp = true;

  /// ثابت لكل المستخدمين (لا نسخة تطبيق ولا نظام ولا لغة).
  static const userAgent = 'durur';

  final HttpClient Function() _clientFactory;
  final Duration timeout;
  final int maxRedirects;
  final bool _allowHttp;

  @override
  Future<Uint8List> get(Uri uri, {required int maxBytes}) async {
    final schemeOk =
        uri.scheme == 'https' || (_allowHttp && uri.scheme == 'http');
    if (!schemeOk || uri.host.isEmpty) {
      // لا اتصال أصلاً: HTTPS فقط (§16.2).
      throw FetchException(FetchFailure.network, 'مخطط غير مسموح: $uri');
    }
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw FetchException(FetchFailure.network, 'رابط غير مسموح: $uri');
    }
    final client = _clientFactory()
      ..userAgent = userAgent
      ..connectionTimeout = timeout
      ..autoUncompress = true;
    try {
      return await _get(client, uri, maxBytes).timeout(
        timeout,
        onTimeout: () => throw const FetchException(FetchFailure.timeout),
      );
    } on FetchException {
      rethrow;
    } on Object catch (e) {
      throw FetchException(FetchFailure.network, '$e');
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> _get(HttpClient client, Uri origin, int maxBytes) async {
    var current = origin;
    for (var hop = 0; ; hop++) {
      final request = await client.getUrl(current);
      request
        ..followRedirects = false
        ..persistentConnection = false;
      // لا كوكيز ولا ترويسات غير الافتراضية (Host، User-Agent، Accept-Encoding).
      request.cookies.clear();
      final response = await request.close();

      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>().catchError((_) {});
        if (location == null || hop >= maxRedirects) {
          throw const FetchException(FetchFailure.redirect);
        }
        final next = current.resolve(location);
        if (next.scheme != origin.scheme ||
            next.host != origin.host ||
            next.port != origin.port ||
            next.hasQuery ||
            next.userInfo.isNotEmpty) {
          throw FetchException(FetchFailure.redirect, '$next');
        }
        current = next.removeFragment();
        continue;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>().catchError((_) {});
        throw FetchException(FetchFailure.httpStatus, '${response.statusCode}');
      }
      if (response.contentLength > maxBytes) {
        throw FetchException(
          FetchFailure.tooLarge,
          '${response.contentLength} > $maxBytes',
        );
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw FetchException(FetchFailure.tooLarge, '> $maxBytes');
        }
      }
      return builder.takeBytes();
    }
  }
}
