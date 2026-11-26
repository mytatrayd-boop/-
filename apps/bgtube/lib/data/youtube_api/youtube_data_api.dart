import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, HandshakeException;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/app_failure.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/models/youtube_content.dart';
import '../../domain/ports/api_cache_store.dart';
import '../../domain/ports/auth_service.dart';
import '../../domain/ports/youtube_api.dart';
import 'quota_meter.dart';
import 'youtube_json.dart';

/// مدد صلاحية الكاش (ARCHITECTURE: الذاكرة المؤقتة).
abstract final class CacheTtl {
  static const search = Duration(hours: 6);
  static const lists = Duration(minutes: 15);
  static const details = Duration(hours: 24);
}

/// حدود الرئيسية «أحدث فيديوهات اشتراكاتي» (D29).
abstract final class FeedLimits {
  /// عدد القنوات المأخوذة من الاشتراكات (صفحة واحدة، الأنشط أولاً).
  static const channels = 25;

  /// آخر المقاطع من كل قناة.
  static const perChannel = 5;

  /// أقصى ما يُعرض في الرئيسية.
  static const total = 50;

  /// طلبات القوائم المتزامنة.
  static const parallel = 5;
}

/// تنفيذ [YouTubeApi] فوق HTTP (D29). الرمز من [AuthService] عند كل طلب، في
/// ترويسة Authorization فقط؛ لا مفتاح API، ولا رمز في الكاش أو السجلات أو
/// `AppFailure.debugDetail`. لا يُستعمل مع المستخرج أبداً (D4).
class YouTubeDataApi implements YouTubeApi {
  YouTubeDataApi({
    required AuthService auth,
    required http.Client client,
    required ApiCacheStore cache,
    required QuotaMeter quota,
    Clock? clock,
    this.timeout = const Duration(seconds: 20),
  })  : _auth = auth,
        // ignore: prefer_initializing_formals
        _client = client,
        // ignore: prefer_initializing_formals
        _cache = cache,
        // ignore: prefer_initializing_formals
        _quota = quota,
        _clock = clock ?? const Clock() {
    // الكاش كله يخص الحساب (حتى قوائم الرفع والمدد تكشف الاشتراكات والبحث): يُمسح
    // عند الخروج، وعند الدخول بعد انتهاء الجلسة (قد يكون حساباً آخر)، D29.
    _lastStatus = auth.status;
    _authSub = auth.statusChanges.listen(_onStatus);
    unawaited(_safe(() => _cache.deleteOlderThan(_clock.now().subtract(const Duration(days: 7)))));
  }

  late AuthStatus _lastStatus;
  Future<void>? _wiping;

  /// يُستدعى من الحدث ومن كل طلب (الحالة تتغيّر قبل وصول الحدث، فلا يُقرأ كاش
  /// الحساب السابق في الفجوة).
  void _onStatus(AuthStatus s) {
    final prev = _lastStatus;
    if (s == prev) return;
    _lastStatus = s;
    if (s == AuthStatus.signedOut || (s == AuthStatus.signedIn && prev == AuthStatus.expired)) _wipe();
  }

  /// يمسح الكاش؛ الطلبات اللاحقة تنتظر انتهاء المسح فلا تقرأ بيانات الحساب السابق.
  void _wipe() {
    final previous = _wiping ?? Future<void>.value();
    _wiping = previous.then((_) => _safe(_cache.deleteAll));
  }

  /// بعد استعادة الجلسة عند الإقلاع (main): إن لم تكن جلسة يُمسح ما بقي (خروج لم
  /// يكتمل مسحه، أو تثبيت سابق).
  Future<void> clearIfSignedOut() async {
    if (_auth.status == AuthStatus.signedOut) {
      _wipe();
      await _wiping;
    }
  }

  static const host = 'www.googleapis.com';
  static const basePath = '/youtube/v3/';

  final AuthService _auth;
  final http.Client _client;
  final ApiCacheStore _cache;
  final QuotaMeter _quota;
  final Clock _clock;
  final Duration timeout;
  late final StreamSubscription<AuthStatus> _authSub;

  Future<void> dispose() => _authSub.cancel();

  // ───────────────────────── الطلبات العامة ─────────────────────────

  @override
  Future<ApiPage<SearchResult>> search(String query, {String? pageToken}) async {
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    final r = await _get(
      'search',
      {
        'part': 'snippet',
        'type': 'video,channel',
        'maxResults': '20',
        'q': q,
        'pageToken': ?pageToken,
        'fields': 'nextPageToken,items(id(kind,videoId,channelId),'
            'snippet(title,channelTitle,thumbnails(default/url,medium/url)))',
      },
      bucket: QuotaBucket.search,
      cost: QuotaCost.search,
      ttl: CacheTtl.search,
      private: true,
    );
    final items = parseSearchItems(r.body);
    final durations = await _durations([
      for (final i in items)
        if (i is VideoResult) i.video.videoId,
    ]);
    return ApiPage(
      [
        for (final i in items)
          if (i is VideoResult) VideoResult(_withDuration(i.video, durations)) else i,
      ],
      nextPageToken: nextTokenOf(r.body),
      stale: r.stale,
    );
  }

  @override
  Future<ApiPage<VideoRef>> channelVideos(String channelId, {String? pageToken, bool refresh = false}) async {
    final uploads = await _uploads([channelId]);
    final playlist = uploads.map[channelId];
    if (playlist == null) return ApiPage(const [], stale: uploads.stale);
    final r = await _playlistPage(playlist, max: 20, pageToken: pageToken, refresh: refresh);
    final videos = parsePlaylistItems(r.body).map((v) => v.ref).toList();
    final durations = await _durations([for (final v in videos) v.videoId]);
    return ApiPage(
      [for (final v in videos) _withDuration(v, durations)],
      nextPageToken: nextTokenOf(r.body),
      stale: r.stale || uploads.stale,
    );
  }

  /// subscriptions.list (وحدة) ← channels.list للرفع (وحدة لكل 50) ← playlistItems
  /// لكل قناة (وحدة لكل قناة) ← videos.list للمدد (وحدة). ≈28 وحدة من الوعاء
  /// العام لتحديث كامل، ولا شيء من وعاء البحث.
  @override
  Future<ApiPage<VideoRef>> subscriptionFeed({bool refresh = false}) async {
    final subs = await _get(
      'subscriptions',
      {
        'part': 'snippet',
        'mine': 'true',
        'order': 'unread',
        'maxResults': '${FeedLimits.channels}',
        'fields': 'items(snippet(resourceId/channelId))',
      },
      cost: QuotaCost.read,
      ttl: CacheTtl.lists,
      private: true,
      refresh: refresh,
    );
    final channelIds = parseSubscriptionChannelIds(subs.body);
    if (channelIds.isEmpty) return ApiPage(const [], stale: subs.stale);
    final uploads = await _uploads(channelIds);
    var stale = subs.stale || uploads.stale;

    final playlists = [for (final id in channelIds) ?uploads.map[id]];
    final collected = <PlaylistVideo>[];
    AppFailure? firstFailure;
    var succeeded = 0;
    var next = 0;
    Future<void> worker() async {
      while (next < playlists.length) {
        final p = playlists[next++];
        try {
          final r = await _playlistPage(p, max: FeedLimits.perChannel, refresh: refresh);
          collected.addAll(parsePlaylistItems(r.body));
          if (r.stale) stale = true;
          succeeded++;
        } on AppFailure catch (f) {
          // الجلسة لا تخص قناة بعينها: توقف الكل.
          if (f.kind == FailureKind.authExpired || f.kind == FailureKind.notSignedIn) rethrow;
          if (f.kind == FailureKind.insufficientPermissions) rethrow;
          // قناة بلا رفع (404) أو نفاد الحصة لقناة غير مخزّنة: نتخطاها.
          if (f.kind == FailureKind.quotaExceeded) stale = true;
          firstFailure ??= f;
        }
      }
    }

    await Future.wait([for (var i = 0; i < FeedLimits.parallel; i++) worker()]);
    if (succeeded == 0 && firstFailure != null) throw firstFailure!;

    final seen = <String>{};
    collected.sort((a, b) {
      final x = a.publishedAt, y = b.publishedAt;
      if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
      return y.compareTo(x);
    });
    final top = [
      for (final v in collected)
        if (seen.add(v.ref.videoId)) v.ref,
    ].take(FeedLimits.total).toList();
    final durations = await _durations([for (final v in top) v.videoId]);
    return ApiPage([for (final v in top) _withDuration(v, durations)], stale: stale);
  }

  @override
  Future<String?> myChannelTitle() async {
    final r = await _get(
      'channels',
      {'part': 'snippet', 'mine': 'true', 'fields': 'items(snippet/title)'},
      cost: QuotaCost.read,
      ttl: CacheTtl.details,
      private: true,
    );
    return parseMyChannelTitle(r.body);
  }

  @override
  Future<QuotaUsage> quotaToday() => _quota.today();

  // ───────────────────────── مساعدات مركّبة ─────────────────────────

  Future<_Fetched> _playlistPage(String playlistId, {required int max, String? pageToken, bool refresh = false}) =>
      _get(
        'playlistItems',
        {
          'part': 'snippet,contentDetails',
          'playlistId': playlistId,
          'maxResults': '$max',
          'pageToken': ?pageToken,
          'fields': 'nextPageToken,items(snippet(title,videoOwnerChannelTitle,resourceId/videoId,'
              'thumbnails(default/url,medium/url)),contentDetails/videoPublishedAt)',
        },
        cost: QuotaCost.read,
        ttl: CacheTtl.lists,
        private: false,
        refresh: refresh,
      );

  /// قوائم الرفع للقنوات (وحدة لكل 50 قناة، كاش 24 ساعة).
  Future<({Map<String, String> map, bool stale})> _uploads(List<String> channelIds) async {
    final map = <String, String>{};
    var stale = false;
    for (var i = 0; i < channelIds.length; i += 50) {
      final batch = channelIds.sublist(i, i + 50 > channelIds.length ? channelIds.length : i + 50);
      final r = await _get(
        'channels',
        {
          'part': 'contentDetails',
          'id': batch.join(','),
          'maxResults': '50',
          'fields': 'items(id,contentDetails/relatedPlaylists/uploads)',
        },
        cost: QuotaCost.read,
        ttl: CacheTtl.details,
        private: false,
      );
      map.addAll(parseUploads(r.body));
      stale = stale || r.stale;
    }
    return (map: map, stale: stale);
  }

  /// المدد دفعة واحدة (حتى 50 معرّفاً لكل وحدة). تحسين لا يُفشل القائمة: أي خطأ
  /// هنا يعيد ما توفّر بلا مدد.
  Future<Map<String, Duration>> _durations(List<String> ids) async {
    final unique = ids.toSet().toList();
    final out = <String, Duration>{};
    for (var i = 0; i < unique.length; i += 50) {
      final batch = unique.sublist(i, i + 50 > unique.length ? unique.length : i + 50);
      try {
        final r = await _get(
          'videos',
          {'part': 'contentDetails', 'id': batch.join(','), 'fields': 'items(id,contentDetails/duration)'},
          cost: QuotaCost.read,
          ttl: CacheTtl.details,
          private: false,
        );
        out.addAll(parseDurations(r.body));
      } on AppFailure catch (f) {
        debugPrint('durations skipped: ${f.kind.name}');
        return out;
      }
    }
    return out;
  }

  static VideoRef _withDuration(VideoRef v, Map<String, Duration> d) =>
      d[v.videoId] == null ? v : v.copyWith(duration: d[v.videoId]);

  // ───────────────────────── الطلب الواحد ─────────────────────────

  /// مفتاح الكاش: المسار + المعاملات مرتبة. لا رمز فيه.
  @visibleForTesting
  static String cacheKey(String endpoint, Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    return '$endpoint?${keys.map((k) => '$k=${Uri.encodeQueryComponent(params[k]!)}').join('&')}';
  }

  Future<_Fetched> _get(
    String endpoint,
    Map<String, String> params, {
    QuotaBucket bucket = QuotaBucket.general,
    required int cost,
    required Duration ttl,
    required bool private,
    bool refresh = false,
  }) async {
    final key = cacheKey(endpoint, params);
    _onStatus(_auth.status);
    final wiping = _wiping;
    if (wiping != null) await wiping;
    final cached = await _safeRead(key);
    final now = _clock.now();
    if (!refresh && cached != null && cached.isFresh(now)) {
      final body = _decode(cached.json);
      if (body != null) return _Fetched(body, stale: false);
    }

    _Fetched fallback(AppFailure f) {
      final body = cached == null ? null : _decode(cached.json);
      if (body == null) throw f;
      return _Fetched(body, stale: true);
    }

    final exhaustedKind =
        bucket == QuotaBucket.search ? FailureKind.searchQuotaExceeded : FailureKind.quotaExceeded;
    if (!await _quota.canSpend(bucket, cost)) {
      return fallback(AppFailure(exhaustedKind));
    }

    final uri = Uri.https(host, '$basePath$endpoint', params);
    http.Response? res;
    for (var attempt = 0; attempt < 2; attempt++) {
      // notSignedIn وAuthExpired من المنفذ تمر كما هي (ولا تُحسب من الحصة).
      final token = await _auth.accessToken();
      // يُحسب مرة واحدة لكل طلب يُرسل (إعادة 401 لا تُحسب مرتين).
      if (attempt == 0) await _quota.spend(bucket, cost);
      try {
        res = await _client
            .get(uri, headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'})
            .timeout(timeout);
      } on TimeoutException {
        return fallback(AppFailure(FailureKind.network, '$endpoint timeout'));
      } on SocketException {
        return fallback(AppFailure(FailureKind.network, '$endpoint socket'));
      } on HandshakeException {
        return fallback(AppFailure(FailureKind.network, '$endpoint tls'));
      } on http.ClientException {
        return fallback(AppFailure(FailureKind.network, '$endpoint client'));
      }
      if (res.statusCode != 401) break;
      // رمز مرفوض: يُبطَل ويُطلب جديد مرة واحدة؛ رفض ثانٍ = انتهت الجلسة.
      await _auth.invalidateAccessToken(token);
      if (attempt == 1) throw const AuthExpired();
    }
    final response = res!;

    if (response.statusCode == 200) {
      final body = _decode(response.body);
      if (body == null) return fallback(AppFailure(FailureKind.apiFailed, '$endpoint bad json'));
      await _safe(() => _cache.write(
            key,
            CachedResponse(json: response.body, fetchedAt: _clock.now(), ttl: ttl),
            private: private,
          ));
      return _Fetched(body, stale: false);
    }

    Object? errorBody;
    try {
      errorBody = jsonDecode(response.body);
    } catch (_) {}
    final reasons = errorReasons(errorBody);
    final detail = '$endpoint HTTP ${response.statusCode}${reasons.isEmpty ? '' : ' ${reasons.join(',')}'}';
    if (reasons.contains('quotaExceeded') || reasons.contains('dailyLimitExceeded')) {
      // وعاء نقطة النهاية التي ردّت وحدها (نفاد البحث لا يوقف الرئيسية).
      await _quota.markExhausted(bucket);
      return fallback(AppFailure(exhaustedKind, detail));
    }
    // الإذن الممنوح لا يغطي النطاق (رُفض مربع youtube.readonly أو سُحب): يلزم منحه.
    if (reasons.contains('insufficientPermissions') ||
        response.headers['www-authenticate']?.contains('insufficient_scope') == true) {
      throw AppFailure(FailureKind.insufficientPermissions, detail);
    }
    if (response.statusCode == 429 ||
        reasons.contains('rateLimitExceeded') ||
        reasons.contains('userRateLimitExceeded')) {
      return fallback(AppFailure(FailureKind.rateLimited, detail));
    }
    return fallback(AppFailure(FailureKind.apiFailed, detail));
  }

  static Json? _decode(String s) {
    try {
      final v = jsonDecode(s);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<CachedResponse?> _safeRead(String key) async {
    try {
      return await _cache.read(key);
    } catch (e) {
      debugPrint('api cache read failed: ${e.runtimeType}');
      return null;
    }
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      debugPrint('api cache write failed: ${e.runtimeType}');
    }
  }
}

class _Fetched {
  const _Fetched(this.body, {required this.stale});
  final Json body;
  final bool stale;
}
