import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/data/local/app_database.dart';
import 'package:bgtube/data/local/drift_api_cache_store.dart';
import 'package:bgtube/data/youtube_api/quota_meter.dart';
import 'package:bgtube/data/youtube_api/youtube_data_api.dart';
import 'package:bgtube/domain/models/youtube_content.dart';
import 'package:bgtube/domain/ports/auth_service.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// منفذ دخول وهمي برموز متتالية، يسجّل الإبطال.
class TokenAuth implements AuthService {
  TokenAuth({this.status = AuthStatus.signedIn});
  @override
  AuthStatus status;
  final changes = StreamController<AuthStatus>.broadcast();
  int _n = 0;
  final invalidated = <String>[];
  Object? tokenError;

  String get lastToken => 'secret-token-$_n';

  @override
  Stream<AuthStatus> get statusChanges => changes.stream;
  @override
  Future<void> restore() async {}
  @override
  Future<SignInOutcome> signIn() async => SignInOutcome.signedIn;
  @override
  Future<String> accessToken() async {
    if (status == AuthStatus.signedOut) throw const AppFailure(FailureKind.notSignedIn);
    if (tokenError != null) throw tokenError!;
    _n++;
    return lastToken;
  }

  @override
  Future<void> invalidateAccessToken(String token) async => invalidated.add(token);
  @override
  Future<void> signOut() async {}
}

/// خادم وهمي: يوجّه حسب نقطة النهاية ويسجّل الطلبات.
class FakeServer {
  final requests = <http.Request>[];
  final handlers = <String, FutureOr<http.Response> Function(http.Request)>{};

  List<String> get endpoints => [for (final r in requests) r.url.pathSegments.last];

  late final client = MockClient((req) async {
    requests.add(req);
    final h = handlers[req.url.pathSegments.last];
    if (h == null) return http.Response('{"error":{"code":404}}', 404);
    return h(req);
  });
}

http.Response ok(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

http.Response apiError(int code, String reason) => http.Response(
      jsonEncode({
        'error': {
          'code': code,
          'message': 'x',
          'errors': [
            {'reason': reason, 'domain': 'youtube.quota'},
          ],
        },
      }),
      code,
    );

Map<String, dynamic> searchBody({String? next, String prefix = 'v'}) => {
      'nextPageToken': ?next,
      'items': [
        {
          'id': {'kind': 'youtube#video', 'videoId': '${prefix}AAAAAAAAAA'},
          'snippet': {
            'title': 'Rock &amp; Roll &#39;live&#39;',
            'channelTitle': 'قناة',
            'thumbnails': {
              'medium': {'url': 'https://i.ytimg.com/a.jpg'},
            },
          },
        },
        {
          'id': {'kind': 'youtube#channel', 'channelId': 'UCchan'},
          'snippet': {
            'title': 'A Channel',
            'thumbnails': {
              'default': {'url': 'https://yt3/c.jpg'},
            },
          },
        },
        {
          'id': {'kind': 'youtube#playlist', 'playlistId': 'PL1'},
          'snippet': {'title': 'ignored'},
        },
      ],
    };

Map<String, dynamic> durationsBody(Map<String, String> d) => {
      'items': [
        for (final e in d.entries)
          {
            'id': e.key,
            'contentDetails': {'duration': e.value},
          },
      ],
    };

Map<String, dynamic> playlistBody(List<(String id, String date)> items, {String? next}) => {
      'nextPageToken': ?next,
      'items': [
        for (final (id, date) in items)
          {
            'snippet': {
              'title': 'T $id',
              'videoOwnerChannelTitle': 'Owner',
              'resourceId': {'videoId': id},
            },
            'contentDetails': {'videoPublishedAt': date},
          },
        // فيديو خاص/محذوف: بلا مالك ولا تاريخ نشر.
        {
          'snippet': {
            'title': 'Private video',
            'resourceId': {'videoId': 'PRIVATEXXXX'},
          },
          'contentDetails': {},
        },
      ],
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late FakeServer server;
  late TokenAuth auth;
  late DateTime now;
  late DriftApiCacheStore cache;
  late DriftQuotaStore quotaStore;
  late YouTubeDataApi api;

  YouTubeDataApi build() {
    final c = Clock(() => now);
    return YouTubeDataApi(
      auth: auth,
      client: server.client,
      cache: cache,
      quota: QuotaMeter(quotaStore, clock: c),
      clock: c,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    auth = TokenAuth();
    now = DateTime.utc(2026, 11, 26, 12); // 04:00 بتوقيت المحيط الهادئ (PST)
    cache = DriftApiCacheStore(db);
    quotaStore = DriftQuotaStore(db);
    api = build();
  });
  tearDown(() async {
    await api.dispose();
    await db.close();
  });

  /// مجموع الوعاءين (لاختبارات «لا حصة مستهلكة»).
  Future<int> used() async {
    final q = await api.quotaToday();
    return q.general.used + q.search.used;
  }

  Future<int> searches() async => (await api.quotaToday()).search.used;
  Future<int> general() async => (await api.quotaToday()).general.used;

  void serveSearch({String? next}) {
    server.handlers['search'] = (_) => ok(searchBody(next: next));
    server.handlers['videos'] = (_) => ok(durationsBody({'vAAAAAAAAAA': 'PT1H2M3S'}));
  }

  group('search', () {
    test('sends the bearer token only in the header, no API key; parses videos and channels', () async {
      serveSearch(next: 'P2');
      final page = await api.search('  rock   roll ');
      expect(server.endpoints, ['search', 'videos']);
      final req = server.requests.first;
      expect(req.url.host, 'www.googleapis.com');
      expect(req.url.scheme, 'https');
      expect(req.url.path, '/youtube/v3/search');
      expect(req.headers['Authorization'], 'Bearer secret-token-1');
      expect(req.url.queryParameters.containsKey('key'), isFalse);
      expect(req.url.toString(), isNot(contains('secret')));
      expect(req.url.queryParameters['q'], 'rock roll');
      expect(req.url.queryParameters['fields'], isNotEmpty);
      expect(req.url.queryParameters['type'], 'video,channel');
      expect(req.url.queryParameters['maxResults'], '20');
      expect(req.url.queryParameters['part'], 'snippet');
      final details = server.requests[1].url.queryParameters;
      expect(details['part'], 'contentDetails');
      expect(details['id'], 'vAAAAAAAAAA');
      expect(details.containsKey('maxResults'), isFalse, reason: 'not allowed with id in videos.list');
      expect(page.nextPageToken, 'P2');
      expect(page.stale, isFalse);
      expect(page.items, hasLength(2)); // القائمة (playlist) أُهملت
      final video = (page.items[0] as VideoResult).video;
      expect(video.videoId, 'vAAAAAAAAAA');
      expect(video.title, "Rock & Roll 'live'");
      expect(video.author, 'قناة');
      expect(video.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(video.thumbUrl, 'https://i.ytimg.com/a.jpg');
      final ch = (page.items[1] as ChannelResult).channel;
      expect(ch.id, 'UCchan');
      expect(ch.thumbUrl, 'https://yt3/c.jpg');
      // search: طلب من وعاء البحث؛ videos: وحدة من الوعاء العام.
      expect(await searches(), 1);
      expect(await general(), 1);
    });

    test('load more sends the page token as a separate cached request', () async {
      serveSearch(next: 'P2');
      await api.search('rock');
      await api.search('rock', pageToken: 'P2');
      expect(server.requests.where((r) => r.url.path.endsWith('search')).last.url.queryParameters['pageToken'], 'P2');
      // كل صفحة طلب من وعاء البحث؛ المدد للمعرّف نفسه من الكاش (24 ساعة).
      expect(await searches(), 2);
      expect(await general(), 1);
    });
  });

  group('cache', () {
    test('a repeated search is served from the cache: no request, no quota', () async {
      serveSearch();
      final first = await api.search('rock');
      final n = server.requests.length;
      final q = await used();
      final again = await api.search(' rock '); // المسافات تُطبَّع
      expect(server.requests.length, n);
      expect(await used(), q);
      expect((again.items.first as VideoResult).video, (first.items.first as VideoResult).video);
    });

    test('search cache lives 6 hours, then it is fetched again', () async {
      serveSearch();
      await api.search('rock');
      now = now.add(const Duration(hours: 5, minutes: 59));
      await api.search('rock');
      expect(server.endpoints.where((e) => e == 'search'), hasLength(1));
      now = now.add(const Duration(minutes: 2));
      await api.search('rock');
      expect(server.endpoints.where((e) => e == 'search'), hasLength(2));
    });

    test('the cache survives a new API instance (stored in drift) and keeps no token', () async {
      serveSearch();
      await api.search('rock');
      await api.dispose();
      api = build();
      await api.search('rock');
      expect(server.endpoints.where((e) => e == 'search'), hasLength(1));
      final rows = await db.select(db.apiCache).get();
      expect(rows, isNotEmpty);
      for (final r in rows) {
        expect(r.key, isNot(contains('secret')));
        expect(r.json, isNot(contains('secret')));
      }
    });

    test('expired cache + no network: the saved copy is shown as stale', () async {
      serveSearch();
      await api.search('rock');
      now = now.add(const Duration(hours: 7));
      server.handlers['search'] = (_) => throw const SocketException('down');
      final page = await api.search('rock');
      expect(page.stale, isTrue);
      expect(page.items, hasLength(2));
    });

    test('no cache + no network: network failure, without the token in the detail', () async {
      server.handlers['search'] = (_) => throw http.ClientException('down');
      await expectLater(
        api.search('rock'),
        throwsA(isA<AppFailure>()
            .having((f) => f.kind, 'kind', FailureKind.network)
            .having((f) => f.toString(), 'text', isNot(contains('secret')))),
      );
    });

    test('a timeout is a network failure', () async {
      final slow = YouTubeDataApi(
        auth: auth,
        client: MockClient((_) => Completer<http.Response>().future),
        cache: cache,
        quota: QuotaMeter(quotaStore, clock: Clock(() => now)),
        clock: Clock(() => now),
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(slow.search('x'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.network)));
      await slow.dispose();
    });

    test('signing out deletes the whole cache (uploads and durations reveal the account too)', () async {
      serveSearch();
      await api.search('rock');
      expect(await db.select(db.apiCache).get(), hasLength(2));
      auth.changes.add(AuthStatus.signedOut);
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), isEmpty);
    });

    test('signing in again after an expired session wipes the cache (maybe another account)', () async {
      var title = 'القديمة';
      server.handlers['channels'] = (_) => ok({
            'items': [
              {
                'snippet': {'title': title},
              },
            ],
          });
      expect(await api.myChannelTitle(), 'القديمة');
      auth.changes.add(AuthStatus.expired);
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), hasLength(1), reason: 'expired alone keeps it');
      title = 'الجديدة';
      auth.changes.add(AuthStatus.signedIn);
      // يُطلب فوراً كما يفعل مزوّد الإعدادات: ينتظر المسح فلا يقرأ القديم.
      expect(await api.myChannelTitle(), 'الجديدة');
    });

    test('a response sent before sign-out and arriving after it is neither cached nor returned', () async {
      final gate = Completer<http.Response>();
      server.handlers['channels'] = (_) => gate.future;
      final pending = api.myChannelTitle();
      await pumpEventQueue();
      expect(server.requests, hasLength(1));
      auth.status = AuthStatus.signedOut;
      auth.changes.add(AuthStatus.signedOut);
      await pumpEventQueue();
      gate.complete(ok({
        'items': [
          {
            'snippet': {'title': 'old'},
          },
        ],
      }));
      await expectLater(
          pending, throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.notSignedIn)));
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), isEmpty);
    });

    test('same after expired -> signed in (maybe another account)', () async {
      final gate = Completer<http.Response>();
      server.handlers['channels'] = (_) => gate.future;
      final pending = api.myChannelTitle();
      await pumpEventQueue();
      auth.status = AuthStatus.expired;
      auth.changes.add(AuthStatus.expired);
      await pumpEventQueue();
      auth.status = AuthStatus.signedIn;
      auth.changes.add(AuthStatus.signedIn);
      await pumpEventQueue();
      gate.complete(ok({
        'items': [
          {
            'snippet': {'title': 'old'},
          },
        ],
      }));
      await expectLater(pending, throwsA(isA<AppFailure>()));
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), isEmpty);
      // الطلب الجديد يجلب حساب اليوم.
      server.handlers['channels'] = (_) => ok({
            'items': [
              {
                'snippet': {'title': 'new'},
              },
            ],
          });
      expect(await api.myChannelTitle(), 'new');
    });

    test('a saved copy read before sign-out is not returned as a fallback after it', () async {
      serveSearch();
      await api.search('rock');
      now = now.add(const Duration(hours: 7)); // منتهية: سيُطلب من جديد
      final gate = Completer<http.Response>();
      server.handlers['search'] = (_) => gate.future;
      final pending = api.search('rock');
      await pumpEventQueue();
      auth.status = AuthStatus.signedOut;
      auth.changes.add(AuthStatus.signedOut);
      await pumpEventQueue();
      gate.completeError(const SocketException('down'));
      await expectLater(
          pending, throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.notSignedIn)));
      expect(await db.select(db.apiCache).get(), isEmpty);
    });

    test('a composite request that swallowed a failure (durations) is not returned after sign-out', () async {
      server.handlers['search'] = (_) => ok(searchBody());
      final gate = Completer<http.Response>();
      server.handlers['videos'] = (_) => gate.future;
      final pending = api.search('rock');
      await pumpEventQueue();
      auth.status = AuthStatus.signedOut;
      auth.changes.add(AuthStatus.signedOut);
      await pumpEventQueue();
      gate.complete(ok(durationsBody({})));
      await expectLater(pending, throwsA(isA<AppFailure>()));
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), isEmpty);
    });

    test('at startup without a session the leftover cache is wiped', () async {
      serveSearch();
      await api.search('rock');
      auth.status = AuthStatus.signedOut;
      await api.clearIfSignedOut();
      expect(await db.select(db.apiCache).get(), isEmpty);
    });

    test('at startup with a session the cache stays', () async {
      serveSearch();
      await api.search('rock');
      await api.clearIfSignedOut();
      expect(await db.select(db.apiCache).get(), hasLength(2));
    });
  });

  group('quota (two buckets: search 100 calls, general 10,000 units)', () {
    test('search bucket: the 100th search is allowed, the 101st is refused locally (no request)', () async {
      serveSearch();
      await quotaStore.add('2026-11-26', 'search', 99);
      await api.search('a');
      expect(await searches(), 100);
      final n = server.requests.length;
      await expectLater(api.search('b'),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.searchQuotaExceeded)));
      expect(server.requests.length, n);
      final q = await api.quotaToday();
      expect(q.search.exhausted, isTrue);
      expect(q.search.left, 0);
      expect(q.general.exhausted, isFalse);
    });

    test('general bucket stops at exactly 95%: 9,499 + 1 allowed, 9,500 + 1 refused', () async {
      server.handlers['channels'] = (_) => ok({'items': []});
      await quotaStore.add('2026-11-26', 'general', 9499);
      await api.myChannelTitle();
      expect(await general(), 9500);
      await expectLater(
          api.channelVideos('UCx'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.quotaExceeded)));
      expect(server.requests, hasLength(1));
    });

    test('limits are configurable', () async {
      final meter = QuotaMeter(quotaStore,
          general: const BucketLimit(50, stopFraction: 0.5), search: const BucketLimit(3), clock: Clock(() => now));
      expect(await meter.canSpend(QuotaBucket.general, 25), isTrue);
      expect(await meter.canSpend(QuotaBucket.general, 26), isFalse);
      await meter.spend(QuotaBucket.search, 3);
      expect(await meter.canSpend(QuotaBucket.search, 1), isFalse);
      final u = await meter.today();
      expect(u.search.limit, 3);
      expect(u.general.stopAt, 25);
    });

    test('search exhaustion does not stop the home feed or channels', () async {
      await quotaStore.raiseTo('2026-11-26', 'search', 100);
      server.handlers['subscriptions'] = (_) => ok({'items': []});
      final page = await api.subscriptionFeed();
      expect(page.items, isEmpty);
      expect(server.endpoints, ['subscriptions']);
    });

    test('server 403 quotaExceeded on search marks only the search bucket', () async {
      server.handlers['search'] = (_) => apiError(403, 'quotaExceeded');
      await expectLater(api.search('rock'),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.searchQuotaExceeded)));
      final q = await api.quotaToday();
      expect(q.search.exhausted, isTrue);
      expect(q.search.used, 100);
      expect(q.general.exhausted, isFalse);
      expect(q.general.used, 0);
      // القوائم ما زالت تعمل.
      server.handlers['channels'] = (_) => ok({'items': []});
      expect(await api.myChannelTitle(), isNull);
      // والبحث يُرفض محلياً بلا طلب.
      final n = server.requests.length;
      await expectLater(api.search('x'), throwsA(isA<AppFailure>()));
      expect(server.requests.length, n);
    });

    test('server 403 quotaExceeded on a list marks only the general bucket', () async {
      server.handlers['subscriptions'] = (_) => apiError(403, 'quotaExceeded');
      await expectLater(api.subscriptionFeed(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.quotaExceeded)));
      final q = await api.quotaToday();
      expect(q.general.used, 10000);
      expect(q.general.exhausted, isTrue);
      expect(q.search.exhausted, isFalse);
      serveSearch();
      final page = await api.search('rock');
      expect(page.items, isNotEmpty, reason: 'search still works; durations are skipped quietly');
    });

    test('quota exhausted: cached results (even expired) are still served', () async {
      serveSearch();
      await api.search('rock');
      now = now.add(const Duration(hours: 7));
      await quotaStore.raiseTo('2026-11-26', 'search', 100);
      final n = server.requests.length;
      final page = await api.search('rock');
      expect(server.requests.length, n);
      expect(page.stale, isTrue);
    });

    test('both counters reset at midnight Pacific time, not UTC or device midnight', () async {
      serveSearch();
      now = DateTime.utc(2026, 11, 27, 7, 59); // 23:59 PST في 26
      await api.search('a');
      expect(await searches(), 1);
      expect(await general(), 1);
      now = DateTime.utc(2026, 11, 27, 8, 0); // 00:00 PST في 27
      expect(await used(), 0);
      expect(await quotaStore.unitsFor('2026-11-26', 'search'), 1);
      expect(await quotaStore.unitsFor('2026-11-26', 'general'), 1);
    });

    test('a 1-unit read is counted as 1 in the general bucket', () async {
      server.handlers['channels'] = (_) => ok({
            'items': [
              {
                'snippet': {'title': 'قناتي'},
              },
            ],
          });
      expect(await api.myChannelTitle(), 'قناتي');
      expect(await general(), 1);
      expect(await searches(), 0);
      expect(server.requests.single.url.queryParameters['mine'], 'true');
    });

    test('rate limit is not quota exhaustion', () async {
      server.handlers['search'] = (_) => apiError(403, 'rateLimitExceeded');
      await expectLater(
          api.search('x'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.rateLimited)));
      final q = await api.quotaToday();
      expect(q.search.exhausted, isFalse);
      expect(q.general.exhausted, isFalse);
    });

    test('a WWW-Authenticate insufficient_scope header alone means insufficientPermissions', () async {
      server.handlers['subscriptions'] = (_) => http.Response('', 403, headers: {
            'www-authenticate': 'Bearer realm="https://accounts.google.com/", error="insufficient_scope", '
                'scope="https://www.googleapis.com/auth/youtube.readonly"',
          });
      await expectLater(api.subscriptionFeed(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.insufficientPermissions)));
    });

    test('403 insufficientPermissions is its own failure (grant permission), not a retry', () async {
      server.handlers['subscriptions'] = (_) => apiError(403, 'insufficientPermissions');
      await expectLater(api.subscriptionFeed(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.insufficientPermissions)));
      expect((await api.quotaToday()).general.exhausted, isFalse);
    });
  });

  group('auth', () {
    test('401 invalidates the token and retries once with a new one', () async {
      var calls = 0;
      server.handlers['search'] = (r) {
        calls++;
        return calls == 1 ? http.Response('{"error":{"code":401}}', 401) : ok(searchBody());
      };
      server.handlers['videos'] = (_) => ok(durationsBody({}));
      final page = await api.search('rock');
      expect(page.items, isNotEmpty);
      expect(auth.invalidated, ['secret-token-1']);
      expect(server.requests[1].headers['Authorization'], 'Bearer secret-token-2');
      expect(await searches(), 1, reason: 'the retry is not counted twice');
    });

    test('401 twice becomes AuthExpired', () async {
      server.handlers['search'] = (_) => http.Response('{"error":{"code":401}}', 401);
      await expectLater(api.search('rock'), throwsA(isA<AuthExpired>()));
      expect(auth.invalidated, ['secret-token-1', 'secret-token-2']);
    });

    test('an expired session from the auth port passes through as AuthExpired', () async {
      auth.tokenError = const AuthExpired();
      await expectLater(api.search('rock'), throwsA(isA<AuthExpired>()));
      expect(server.requests, isEmpty);
      expect(await used(), 0);
    });

    test('not signed in: notSignedIn, no request and no quota spent', () async {
      auth.status = AuthStatus.signedOut;
      await expectLater(
          api.search('rock'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.notSignedIn)));
      expect(server.requests, isEmpty);
      expect(await used(), 0);
    });

    test('server errors carry endpoint and status only, never the token', () async {
      server.handlers['search'] = (_) => http.Response('{"error":{"code":500}}', 500);
      try {
        await api.search('rock');
        fail('should throw');
      } on AppFailure catch (f) {
        expect(f.kind, FailureKind.apiFailed);
        expect(f.debugDetail, 'search HTTP 500');
        expect(f.toString(), isNot(contains('secret')));
      }
    });
  });

  group('channel videos', () {
    test('uses the uploads playlist (1 unit each), never search.list', () async {
      server.handlers['channels'] = (_) => ok({
            'items': [
              {
                'id': 'UCchan',
                'contentDetails': {
                  'relatedPlaylists': {'uploads': 'UUchan'},
                },
              },
            ],
          });
      server.handlers['playlistItems'] = (r) {
        expect(r.url.queryParameters['playlistId'], 'UUchan');
        return ok(playlistBody([('AAAAAAAAAAA', '2026-11-20T00:00:00Z')], next: 'N'));
      };
      server.handlers['videos'] = (_) => ok(durationsBody({'AAAAAAAAAAA': 'PT3M'}));
      final page = await api.channelVideos('UCchan');
      expect(server.endpoints, ['channels', 'playlistItems', 'videos']);
      expect(server.endpoints, isNot(contains('search')));
      expect(page.items.single.videoId, 'AAAAAAAAAAA'); // الخاص أُهمل
      expect(page.items.single.duration, const Duration(minutes: 3));
      expect(page.nextPageToken, 'N');
      expect(await used(), 3);
      // صفحة ثانية: القناة من الكاش.
      await api.channelVideos('UCchan', pageToken: 'N');
      expect(server.endpoints.where((e) => e == 'channels'), hasLength(1));
    });

    test('pull to refresh refetches the playlist but not the channel mapping', () async {
      server.handlers['channels'] = (_) => ok({
            'items': [
              {
                'id': 'UCchan',
                'contentDetails': {
                  'relatedPlaylists': {'uploads': 'UUchan'},
                },
              },
            ],
          });
      server.handlers['playlistItems'] = (_) => ok(playlistBody([('AAAAAAAAAAA', '2026-11-20T00:00:00Z')]));
      server.handlers['videos'] = (_) => ok(durationsBody({}));
      await api.channelVideos('UCchan');
      await api.channelVideos('UCchan');
      expect(server.endpoints.where((e) => e == 'playlistItems'), hasLength(1));
      await api.channelVideos('UCchan', refresh: true);
      expect(server.endpoints.where((e) => e == 'playlistItems'), hasLength(2));
      expect(server.endpoints.where((e) => e == 'channels'), hasLength(1));
    });
  });

  group('subscription feed', () {
    void serveFeed({int channels = 3, Set<String> broken = const {}}) {
      server.handlers['subscriptions'] = (r) {
        expect(r.url.queryParameters['mine'], 'true');
        return ok({
          'items': [
            for (var i = 0; i < channels; i++)
              {
                'snippet': {
                  'resourceId': {'channelId': 'UC$i'},
                },
              },
          ],
        });
      };
      server.handlers['channels'] = (r) => ok({
            'items': [
              for (final id in r.url.queryParameters['id']!.split(','))
                {
                  'id': id,
                  'contentDetails': {
                    'relatedPlaylists': {'uploads': 'UU${id.substring(2)}'},
                  },
                },
            ],
          });
      server.handlers['playlistItems'] = (r) {
        final p = r.url.queryParameters['playlistId']!;
        if (broken.contains(p)) return apiError(404, 'playlistNotFound');
        final i = int.parse(p.substring(2));
        return ok(playlistBody([
          ('C${i}NEWXXXXXX', '2026-11-2${i + 1}T10:00:00Z'),
          ('C${i}OLDXXXXXX', '2026-10-0${i + 1}T10:00:00Z'),
          if (i == 0) ('SHAREDXXXXX', '2026-11-01T00:00:00Z'),
          if (i == 1) ('SHAREDXXXXX', '2026-11-01T00:00:00Z'),
        ]));
      };
      server.handlers['videos'] = (_) => ok(durationsBody({}));
    }

    test('newest first across channels, de-duplicated; cost = 1 + 1 + channels + 1', () async {
      serveFeed();
      final page = await api.subscriptionFeed();
      expect(page.items.map((v) => v.videoId).take(3), ['C2NEWXXXXXX', 'C1NEWXXXXXX', 'C0NEWXXXXXX']);
      expect(page.items.where((v) => v.videoId == 'SHAREDXXXXX'), hasLength(1));
      expect(page.items.last.videoId, 'C0OLDXXXXXX');
      expect(page.items.map((v) => v.videoId), isNot(contains('PRIVATEXXXX')));
      expect(await used(), 1 + 1 + 3 + 1);
      final sub = server.requests.firstWhere((r) => r.url.path.endsWith('subscriptions'));
      expect(sub.url.queryParameters['maxResults'], '${FeedLimits.channels}');
      expect(sub.url.queryParameters['order'], 'unread');
      final ch = server.requests.firstWhere((r) => r.url.path.endsWith('channels'));
      expect(ch.url.queryParameters['maxResults'], '50');
      expect(ch.url.queryParameters['part'], 'contentDetails');
      expect(ch.url.queryParameters['id'], 'UC0,UC1,UC2');
      final pl = server.requests.firstWhere((r) => r.url.path.endsWith('playlistItems'));
      expect(pl.url.queryParameters['maxResults'], '${FeedLimits.perChannel}');
      expect(pl.url.queryParameters['part'], 'snippet,contentDetails');
      final vd = server.requests.firstWhere((r) => r.url.path.endsWith('videos'));
      expect(vd.url.queryParameters['part'], 'contentDetails');
      expect(await searches(), 0, reason: 'the feed never touches the search bucket');
    });

    test('opening again within 15 minutes costs nothing; pull to refresh refetches', () async {
      serveFeed();
      await api.subscriptionFeed();
      final q = await used();
      now = now.add(const Duration(minutes: 10));
      await api.subscriptionFeed();
      expect(await used(), q);
      await api.subscriptionFeed(refresh: true);
      // الاشتراكات والقوائم من جديد؛ قوائم الرفع والمدد من الكاش.
      expect(await used(), q + 1 + 3);
    });

    test('a channel without uploads is skipped, the rest is shown', () async {
      serveFeed(broken: {'UU1'});
      final page = await api.subscriptionFeed();
      expect(page.items.map((v) => v.videoId), isNot(contains('C1NEWXXXXXX')));
      expect(page.items.map((v) => v.videoId), contains('C2NEWXXXXXX'));
    });

    test('every channel failing is an error, not an empty feed', () async {
      serveFeed(broken: {'UU0', 'UU1', 'UU2'});
      await expectLater(
          api.subscriptionFeed(), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.apiFailed)));
    });

    test('no subscriptions: empty page, nothing else requested', () async {
      server.handlers['subscriptions'] = (_) => ok({'items': []});
      final page = await api.subscriptionFeed();
      expect(page.items, isEmpty);
      expect(server.endpoints, ['subscriptions']);
    });

    test('the feed limit holds with many channels', () async {
      serveFeed(channels: 25);
      server.handlers['playlistItems'] = (r) {
        final p = r.url.queryParameters['playlistId']!;
        return ok(playlistBody([
          for (var k = 0; k < 5; k++) ('${p}V$k'.padRight(11, 'X'), '2026-11-${10 + k}T00:00:00Z'),
        ]));
      };
      final page = await api.subscriptionFeed();
      expect(page.items.length, lessThanOrEqualTo(FeedLimits.total));
      expect(await used(), 1 + 1 + 25 + 1);
    });
  });
}
