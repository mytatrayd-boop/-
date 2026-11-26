import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'range_fetcher.dart';
import 'socket_buffers.dart';

/// الأصل ردّ 206/200 بلا طول معروف (لا Content-Length ولا Content-Range).
/// ليس رفضاً من الخادم: الرابط مقبول لكن لا نستطيع خدمة Range منه بأمان.
class UnknownLengthException implements Exception {
  const UnknownLengthException();
  @override
  String toString() => 'UnknownLengthException';
}

/// الأصل رفض الطلب (403 مثلاً). يُمرَّر رمزه كما هو إلى المشغّل.
class OriginStatusException implements Exception {
  const OriginStatusException(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'OriginStatusException($statusCode)';
}

/// الأصل بدأ بعد البايت المطلوب (لا نستطيع ملء الفجوة).
class OriginRangeMismatchException implements Exception {
  const OriginRangeMismatchException();
  @override
  String toString() => 'OriginRangeMismatchException';
}

/// المصدر البديل (بعد تبديل العميل) بطول كلي مختلف عن الأصلي: بايتات غير متطابقة،
/// فنفشل صراحةً بدل أن نخلط ملفين.
class OriginLengthMismatchException implements Exception {
  const OriginLengthMismatchException();
  @override
  String toString() => 'OriginLengthMismatchException';
}

/// مصدر بديل يعطيه [OriginFailover]: رابط وترويسات عميل آخر لنفس الصيغة.
typedef AlternateOrigin = ({Uri url, Map<String, String> headers, String client});

/// يعيد استخراج الفيديو بعميل ليس في [tried] (أسماء العملاء المجرَّبة). null =
/// لم يبقَ عميل. لا يرمي (الوكيل يلتقط ويعدّه null).
typedef OriginFailover = Future<AlternateOrigin?> Function(Set<String> tried);

/// أقصى عدد تبديلات للعميل لكل مصدر (ثم فشل صريح).
const maxClientSwitches = 3;

/// آخر فشل في جلب الأصل، للتشخيص على الجهاز: بلا روابط ولا رموز.
class ProxyFailure {
  const ProxyFailure({
    required this.client,
    required this.byte,
    required this.status,
    required this.chunkSize,
    required this.switches,
  });

  /// العميل الذي رُفض (معامل `c`).
  final String client;

  /// أول بايت في القطعة التي فشلت.
  final int byte;

  /// رمز الحالة (403...)، أو 0 لخطأ شبكة قبل الرد.
  final int status;
  final int chunkSize;

  /// عدد تبديلات العميل التي جُرّبت قبل هذا الفشل.
  final int switches;

  /// رقم القطعة (من 1) بحجم القطعة وقت الفشل.
  int get chunkNumber => byte ~/ chunkSize + 1;

  @override
  String toString() =>
      'client=$client byte=$byte chunk#$chunkNumber status=${status == 0 ? 'net' : status} switches=$switches';
}

/// عبارات الحالة التي يرسلها الوكيل لكل فشل داخلي (تظهر في رسالة ExoPlayer).
abstract final class ProxyReason {
  static const unreachable = 'Origin unreachable';
  static const unknownLength = 'Origin length unknown';
  static const rangeMismatch = 'Origin range mismatch';
  static const superseded = 'Superseded';
  static const notFound = 'Not found';
  static const lengthChanged = 'Origin length changed';
}

/// وكيل HTTP محلي صغير خاص بنا (D26): يستمع على 127.0.0.1 بمنفذ عشوائي،
/// ولكل مصدر مسار عشوائي غير قابل للتخمين. يخدم طلبات Range من ExoPlayer
/// ويجلب كل طلب عبر [fetchRange] بترويسات العميل، ويكتب الجسم بـ`addStream`
/// فيُوقف الجلب حين يتوقف ExoPlayer عن القراءة (ضغط عكسي حقيقي، ومخازن مقابس
/// صغيرة في الاتجاهين)، ويقطع اتصال الأصل حين ينقطع العميل. لا يرمي إلى الـzone: كل خطأ يُلتقط ويتحول إلى رمز حالة.
class LocalStreamProxy {
  LocalStreamProxy({RangeFetch? fetch, Random? random})
      : _fetch = fetch ?? defaultRangeFetch,
        _random = random ?? Random.secure();

  final RangeFetch _fetch;
  final Random _random;
  final _streams = <String, ProxiedStream>{};
  HttpServer? _server;
  ServerSocket? _socket;
  Future<HttpServer>? _starting;
  bool _closed = false;

  /// دالة الجلب المستعملة (الافتراضية = [defaultRangeFetch]، نفس الفحص).
  RangeFetch get fetcher => _fetch;

  /// المنفذ بعد [start]، وإلا null.
  int? get port => _server?.port;

  @visibleForTesting
  int get registeredCount => _streams.length;

  /// آخر منفذ رُبط (للاختبار: التحقق من إغلاقه).
  @visibleForTesting
  int? debugBoundPort;

  /// يشغّل الخادم مرة واحدة (آمن عند الاستدعاء المتزامن).
  Future<void> start() async {
    if (_closed) throw StateError('proxy closed');
    if (_server != null) return;
    _starting ??= ServerSocket.bind(InternetAddress.loopbackIPv4, 0).then((ss) {
      _socket = ss;
      debugBoundPort = ss.port;
      // listenOn لا يغلق المقبس عند close: نغلقه نحن في [close].
      return HttpServer.listenOn(SendLimitedServerSocket(ss));
    }).then((s) {
      _server = s;
      s.listen(
        (req) => unawaited(_handle(req)),
        onError: (Object _) {},
      );
      return s;
    });
    try {
      await _starting;
    } catch (_) {
      _starting = null; // يُعاد المحاولة لاحقاً
      rethrow;
    }
    if (_closed) {
      // close() استُدعي أثناء الربط: الخادم والمقبس وُلدا بعده فلم يغلقهما.
      await _shutdown();
      throw StateError('proxy closed');
    }
  }

  /// يسجّل مصدراً بعد [start]. الرابط المحلي `http://127.0.0.1:port/<token>`.
  ProxiedStream register(Uri url, Map<String, String> headers, {OriginFailover? failover}) {
    final server = _server;
    if (_closed || server == null) throw StateError('proxy not started');
    String token;
    do {
      token = base64Url.encode(List<int>.generate(24, (_) => _random.nextInt(256)));
    } while (_streams.containsKey(token));
    final s = ProxiedStream._(
      this,
      token,
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: server.port, path: '/$token'),
      url,
      Map<String, String>.unmodifiable(headers),
      failover,
    );
    _streams[token] = s;
    return s;
  }

  /// يغلق كل المصادر والخادم. لا يرمي.
  Future<void> close() async {
    _closed = true;
    for (final s in _streams.values.toList()) {
      s.close();
    }
    await _shutdown();
  }

  Future<void> _shutdown() async {
    final server = _server;
    final socket = _socket;
    _server = null;
    _socket = null;
    try {
      await server?.close(force: true);
    } catch (_) {}
    try {
      await socket?.close();
    } catch (_) {}
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    try {
      final token = req.uri.pathSegments.length == 1 ? req.uri.pathSegments.single : null;
      final s = token == null ? null : _streams[token];
      if (s == null || req.uri.hasQuery) {
        await _reply(res, HttpStatus.notFound, ProxyReason.notFound);
        return;
      }
      if (req.method != 'GET') {
        await _reply(res, HttpStatus.methodNotAllowed, null);
        return;
      }
      await s._serve(req);
    } catch (_) {
      // لا يصل إلى هنا عادةً؛ أي خطأ متبقٍّ يُغلق الرد بصمت.
      try {
        res.statusCode = HttpStatus.internalServerError;
      } catch (_) {}
      await _closeQuietly(res);
    }
  }
}

/// مصدر واحد مسجَّل في الوكيل. **قيد: اتصال واحد لكل مصدر** — طلب Range جديد
/// يقطع السابق (ExoPlayer يقرأ الملف التقدّمي من اتصال واحد ويغلقه قبل القفز).
/// لذلك لا preload ولا تشغيل متزامن لنفس المصدر.
class ProxiedStream {
  ProxiedStream._(this._proxy, this._token, this.localUri, this._url, this._headers, this._failover)
      : _client = _clientOf(_url) {
    _tried.add(_client);
  }

  static String _clientOf(Uri u) => u.queryParameters['c'] ?? '?';

  final LocalStreamProxy _proxy;
  final String _token;

  /// الرابط الذي يُعطى للمشغّل.
  final Uri localUri;
  Uri _url;
  Map<String, String> _headers;
  final OriginFailover? _failover;
  String _client;
  final _tried = <String>{};
  int _switches = 0;
  int _gen = 0;
  int? _knownTotal;
  Future<bool>? _switching;

  /// رابط/ترويسات العميل الحالي (يتغيران بعد التبديل).
  Uri get url => _url;
  Map<String, String> get headers => _headers;

  /// العميل المستعمل الآن، وعدد التبديلات التي جرت.
  String get client => _client;
  int get switches => _switches;

  /// آخر فشل جلب (يبقى بعد توقف المشغّل ما دام المصدر مسجَّلاً).
  ProxyFailure? lastFailure;
  final _active = <RangeFetchResult>{};
  bool _closed = false;
  int _seq = 0;
  Object? _lastError;

  bool get isClosed => _closed;

  /// عدد طلبات الأصل المفتوحة الآن (يفرغ بعد الإلغاء أو اكتمال الجسم).
  @visibleForTesting
  int get activeCount => _active.length;

  /// آخر فشل داخلي (للتشخيص): [RangeFetchNetworkException] أو
  /// [UnknownLengthException] أو [OriginStatusException] أو [OriginRangeMismatchException].
  Object? get lastError => _lastError;

  /// يقطع كل الطلبات ويُزيل المسار (طلبات لاحقة تعطي 404). لا يرمي.
  void close() {
    _closed = true;
    _proxy._streams.remove(_token);
    _cancelActive();
  }

  void _cancelActive() {
    final all = _active.toList();
    _active.clear();
    for (final r in all) {
      try {
        r.cancel();
      } catch (_) {}
    }
  }

  /// حجم قطعة الأصل الحالي (8MiB؛ يهبط إلى 1MiB بعد أول 403، ويبقى لبقية المصدر).
  int _chunkBytes = originChunkBytes;
  bool _downgraded = false;
  int _lastReqEnd = 0;

  /// آخر رأس Range أُرسل إلى الأصل، وحجم القطعة المعتمد (للتشخيص؛ بلا روابط).
  String? lastOriginRange;
  int get chunkBytes => _chunkBytes;

  Future<RangeFetchResult> _originFetch(int pos, int? limitEx) {
    final end = limitEx == null ? pos + _chunkBytes : min(limitEx, pos + _chunkBytes);
    _lastReqEnd = end;
    lastOriginRange = originRangeHeader(pos, end);
    return _proxy._fetch(_url, _headers, start: pos, end: end);
  }

  void _recordFailure(int pos, int status) {
    lastFailure = ProxyFailure(
      client: _client,
      byte: pos,
      status: status,
      chunkSize: _chunkBytes,
      switches: _switches,
    );
  }

  /// قطعة محدودة من الأصل. أول 403 يُعاد مرة واحدة بقطعة 1MiB (googlevideo يرفض
  /// Range الكبير/المفتوح لبعض العملاء)، وأي 403 بعدها (قطعة لاحقة بعد نجاح
  /// الأولى مثلاً) يبدّل العميل عبر [OriginFailover] ويكمل من **البايت نفسه**
  /// حتى [maxClientSwitches] تبديلات، ثم يُمرَّر الـ403 للمشغّل. يرمي
  /// [OriginLengthMismatchException] إن اختلف الطول الكلي بعد التبديل.
  Future<RangeFetchResult> _fetchChunk(int pos, int? limitEx) async {
    RangeFetchResult r;
    try {
      r = await _originFetch(pos, limitEx);
      while (r.statusCode == HttpStatus.forbidden) {
        final gen = _gen;
        r.cancel();
        if (!_downgraded) {
          _downgraded = true;
          _chunkBytes = originRetryChunkBytes;
          r = await _originFetch(pos, limitEx);
          continue;
        }
        _recordFailure(pos, HttpStatus.forbidden);
        if (!await _failoverFrom(gen) || _closed) return r; // 403 يصل للمشغّل
        r = await _originFetch(pos, limitEx);
      }
    } on RangeFetchNetworkException {
      _recordFailure(pos, 0);
      rethrow;
    }
    if (!r.ok) {
      _recordFailure(pos, r.statusCode);
      return r;
    }
    final total = r.sourceLength;
    if (total != null) {
      final known = _knownTotal;
      if (known == null) {
        _knownTotal = total;
      } else if (known != total && _switches > 0) {
        r.cancel();
        _recordFailure(pos, r.statusCode);
        throw const OriginLengthMismatchException();
      }
    }
    return r;
  }

  /// يبدّل العميل بعد 403 رُفض فيه الجيل [gen]. true = جرى تبديل (أو بدّله طلب
  /// آخر قبلنا) فتُعاد المحاولة؛ false = لا بديل.
  Future<bool> _failoverFrom(int gen) {
    if (gen != _gen) return Future.value(true);
    return _switching ??= _switchClient().whenComplete(() => _switching = null);
  }

  Future<bool> _switchClient() async {
    final cb = _failover;
    if (cb == null || _switches >= maxClientSwitches || _closed) return false;
    AlternateOrigin? alt;
    try {
      alt = await cb(Set.of(_tried));
    } catch (_) {
      alt = null;
    }
    if (alt == null || _closed) return false;
    _switches++;
    _gen++;
    _url = alt.url;
    _headers = Map<String, String>.unmodifiable(alt.headers);
    _client = alt.client;
    _tried.add(alt.client);
    // الحدّ الأصغر كان خاصاً بالعميل السابق: جرّب القطعة الكبيرة مع الجديد.
    _chunkBytes = originChunkBytes;
    _downgraded = false;
    return true;
  }

  static Object _asOriginError(Object e) =>
      e is RangeFetchNetworkException || e is OriginLengthMismatchException
          ? e
          : RangeFetchNetworkException(e.runtimeType.toString());

  Future<void> _serve(HttpRequest req) async {
    final res = req.response;
    final range = parseRangeHeader(req.headers.value(HttpHeaders.rangeHeader));
    final start = range?.start ?? 0;
    final seq = ++_seq;
    _cancelActive();

    // القطعة الحية الآن من هذا الطلب (تتبدّل مع كل قطعة).
    RangeFetchResult? live;
    var gone = false;
    // انقطاع العميل: dart:io لا يقرأ المقبس أثناء الرد، فيظهر عند أول كتابة فاشلة
    // (تنتهي addStream ثم يُلغى الجلب في finally) أو هنا عبر done. مع أصل صامت لا
    // كتابة ولا تنزيل، فتنظّفه مهلة الخمول (10 ث). onError يمنع وصول الخطأ للـzone.
    unawaited(res.done.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      gone = true;
      final f = live;
      if (f != null) {
        _active.remove(f);
        f.cancel();
      }
    }));
    bool stale() => _closed || seq != _seq || gone;

    RangeFetchResult f;
    try {
      f = await _fetchChunk(start, range?.endEx);
    } catch (e) {
      _lastError = _asOriginError(e);
      await _reply(
          res, HttpStatus.badGateway, e is OriginLengthMismatchException ? ProxyReason.lengthChanged : ProxyReason.unreachable);
      return;
    }
    if (stale()) {
      f.cancel();
      await _reply(res, HttpStatus.serviceUnavailable, ProxyReason.superseded);
      return;
    }
    live = f;
    _active.add(f);
    try {
      if (!f.ok) {
        _lastError = OriginStatusException(f.statusCode);
        // DefaultHttpDataSource يرمي عند 416 بلا `Content-Range: bytes */total`.
        if (f.statusCode == HttpStatus.requestedRangeNotSatisfiable && f.sourceLength != null) {
          res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */${f.sourceLength}');
        }
        await _reply(res, f.statusCode, null);
        return;
      }
      final contentLength = f.contentLength;
      if (contentLength == null) {
        _lastError = const UnknownLengthException();
        await _reply(res, HttpStatus.badGateway, ProxyReason.unknownLength);
        return;
      }
      if (f.offset > start) {
        _lastError = const OriginRangeMismatchException();
        await _reply(res, HttpStatus.badGateway, ProxyReason.rangeMismatch);
        return;
      }
      final skip = start - f.offset;
      final endEx = range?.endEx;
      final avail = contentLength - skip;
      final total = f.sourceLength;
      // نهاية ما سنخدمه لـExoPlayer (حصرية): من الطول الكلي المعروف من أول رد.
      int? want;
      if (f.statusCode == HttpStatus.ok) {
        want = start + avail; // الأصل تجاهل Range: رد واحد بلا تقطيع.
      } else if (total != null) {
        want = total;
      } else if (avail < _lastReqEnd - start) {
        want = start + avail; // أقصر مما طُلب = نهاية الملف.
      }
      if (want == null) {
        _lastError = const UnknownLengthException();
        await _reply(res, HttpStatus.badGateway, ProxyReason.unknownLength);
        return;
      }
      if (endEx != null && want > endEx) want = endEx;
      final length = want - start;
      if (length <= 0) {
        if (total != null) res.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
        await _reply(res, HttpStatus.requestedRangeNotSatisfiable, null);
        return;
      }
      res.headers.contentType = ContentType.parse(f.contentType);
      res.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (range != null) {
        res.statusCode = HttpStatus.partialContent;
        res.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-${want - 1}/${total ?? want}');
      } else {
        res.statusCode = HttpStatus.ok;
      }
      res.contentLength = length;
      // بلا تخزين في Dart: كل قطعة تُكتب فوراً، فيظهر انقطاع العميل مبكراً.
      res.bufferOutput = false;
      final end = want;
      final single = f.statusCode == HttpStatus.ok;
      Stream<List<int>> body() async* {
        var pos = start;
        var cur = f;
        var curSkip = skip;
        var take = min(avail, single ? avail : _lastReqEnd - start);
        take = min(take, end - pos);
        while (true) {
          var got = 0;
          await for (final c in window(cur.body, skip: curSkip, length: take)) {
            got += c.length;
            yield c;
          }
          _active.remove(cur);
          cur.cancel();
          // قطعة أقصر مما وعدنا: نُنهي الجسم قصيراً فيعيد ExoPlayer الطلب.
          if (got < take) return;
          pos += got;
          if (pos >= end || stale()) return;
          RangeFetchResult next;
          try {
            next = await _fetchChunk(pos, end);
          } catch (e) {
            _lastError = _asOriginError(e);
            return;
          }
          if (stale()) {
            next.cancel();
            return;
          }
          live = next;
          _active.add(next);
          final nl = next.contentLength;
          if (!next.ok || nl == null || next.offset > pos) {
            _lastError = next.ok ? const OriginRangeMismatchException() : OriginStatusException(next.statusCode);
            return; // الاستدلال في finally يقطعها.
          }
          cur = next;
          curSkip = pos - next.offset;
          take = min(min(nl - curSkip, _lastReqEnd - pos), end - pos);
          if (take <= 0) return;
        }
      }

      try {
        await res.addStream(body());
      } catch (_) {
        // العميل انقطع أثناء الكتابة.
      }
      // جسم أقصر من Content-Length (انقطع الأصل أو أُلغي) يجعل close يرمي
      // HttpException «Content size below specified contentLength»: نلتقطه هنا
      // فيُقطع اتصال العميل ويعيد ExoPlayer الطلب من موضعه.
      await _closeQuietly(res);
    } finally {
      final l = live;
      if (l != null) _active.remove(l);
      l?.cancel();
      _active.remove(f);
      f.cancel();
    }
  }
}

Future<void> _reply(HttpResponse res, int status, String? reason) async {
  try {
    res.statusCode = status;
    if (reason != null) res.reasonPhrase = reason;
    res.contentLength = 0;
  } catch (_) {}
  await _closeQuietly(res);
}

Future<void> _closeQuietly(HttpResponse res) async {
  try {
    await res.close();
  } catch (_) {}
}

/// `bytes=100-` → (100, null)؛ `bytes=100-199` → (100, 200 حصري). غير ذلك null
/// (يُخدم الملف كاملاً بـ200).
({int start, int? endEx})? parseRangeHeader(String? v) {
  if (v == null) return null;
  final m = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(v.trim());
  if (m == null) return null;
  final start = int.parse(m[1]!);
  final end = m[2]!.isEmpty ? null : int.parse(m[2]!);
  if (end != null && end < start) return null;
  return (start: start, endEx: end == null ? null : end + 1);
}

/// يتخطى [skip] بايتاً ثم يمرّر [length] بايتاً بالضبط ويقطع المصدر بعدها، مع
/// تمرير الإيقاف/الاستئناف/الإلغاء. أخطاء المصدر تُنهي التيار (لا ترمي).
@visibleForTesting
Stream<List<int>> window(Stream<List<int>> source, {required int skip, required int length}) {
  late final StreamController<List<int>> out;
  StreamSubscription<List<int>>? sub;
  var toSkip = skip;
  var remaining = length;
  void end() {
    unawaited(sub?.cancel());
    if (!out.isClosed) out.close();
  }

  out = StreamController<List<int>>(
    onListen: () {
      if (remaining <= 0) {
        end();
        return;
      }
      sub = source.listen(
        (chunk) {
          if (out.isClosed) return;
          if (toSkip > 0) {
            if (chunk.length <= toSkip) {
              toSkip -= chunk.length;
              return;
            }
            chunk = chunk.sublist(toSkip);
            toSkip = 0;
          }
          if (chunk.length >= remaining) {
            out.add(chunk.length == remaining ? chunk : chunk.sublist(0, remaining));
            remaining = 0;
            end();
            return;
          }
          remaining -= chunk.length;
          out.add(chunk);
        },
        onError: (Object _) => end(),
        onDone: () {
          if (!out.isClosed) out.close();
        },
        cancelOnError: true,
      );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}
