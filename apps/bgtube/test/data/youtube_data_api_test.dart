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

  Future<int> used() async => (await api.quotaToday()).used;

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
      // search 100 + videos 1
      expect(await used(), 101);
    });

    test('load more sends the page token as a separate cached request', () async {
      serveSearch(next: 'P2');
      await api.search('rock');
      await api.search('rock', pageToken: 'P2');
      expect(server.requests.where((r) => r.url.path.endsWith('search')).last.url.queryParameters['pageToken'], 'P2');
      // المدد للمعرّف نفسه من الكاش (24 ساعة).
      expect(await used(), 201);
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

    test('signing out deletes the private cache (search, mine) and keeps public data', () async {
      serveSearch();
      await api.search('rock'); // خاص (البحث) + مدد (عامة)
      expect(await db.select(db.apiCache).get(), hasLength(2));
      auth.changes.add(AuthStatus.signedOut);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final left = await db.select(db.apiCache).get();
      expect(left.map((r) => r.key.split('?').first), ['videos']);
    });
  });

  group('quota', () {
    test('near the daily limit search is refused locally with quotaExceeded (no request)', () async {
      await quotaStore.add('2026-11-26', 9401); // 9401 + 100 > 9500 (95%)
      serveSearch();
      await expectLater(
          api.search('rock'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.quotaExceeded)));
      expect(server.requests, isEmpty);
      expect((await api.quotaToday()).exhausted, isFalse);
      expect((await api.quotaToday()).searchesLeft, 0);
    });

    test('quota exhausted: cached results (even expired) are still served', () async {
      serveSearch();
      await api.search('rock');
      now = now.add(const Duration(hours: 7));
      await quotaStore.raiseTo('2026-11-26', 10000);
      final n = server.requests.length;
      final page = await api.search('rock');
      expect(server.requests.length, n);
      expect(page.stale, isTrue);
    });

    test('server 403 quotaExceeded marks the day exhausted; later reads are refused locally', () async {
      server.handlers['search'] = (_) => apiError(403, 'quotaExceeded');
      await expectLater(
          api.search('rock'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.quotaExceeded)));
      final q = await api.quotaToday();
      expect(q.exhausted, isTrue);
      expect(q.used, 10000);
      final n = server.requests.length;
      await expectLater(api.myChannelTitle(), throwsA(isA<AppFailure>()));
      expect(server.requests.length, n, reason: 'no request after exhaustion');
    });

    test('the counter resets at midnight Pacific time, not UTC or device midnight', () async {
      serveSearch();
      now = DateTime.utc(2026, 11, 27, 7, 59); // 23:59 PST في 26
      await api.search('a');
      expect(await used(), 101);
      now = DateTime.utc(2026, 11, 27, 8, 0); // 00:00 PST في 27
      expect(await used(), 0);
      expect(await quotaStore.unitsFor('2026-11-26'), 101);
    });

    test('a 1-unit read is counted as 1', () async {
      server.handlers['channels'] = (_) => ok({
            'items': [
              {
                'snippet': {'title': 'قناتي'},
              },
            ],
          });
      expect(await api.myChannelTitle(), 'قناتي');
      expect(await used(), 1);
      expect(server.requests.single.url.queryParameters['mine'], 'true');
    });

    test('rate limit is not quota exhaustion', () async {
      server.handlers['search'] = (_) => apiError(403, 'rateLimitExceeded');
      await expectLater(
          api.search('x'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.rateLimited)));
      expect((await api.quotaToday()).exhausted, isFalse);
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
      expect(await used(), 101, reason: 'the retry is not counted twice');
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
      final pl = server.requests.firstWhere((r) => r.url.path.endsWith('playlistItems'));
      expect(pl.url.queryParameters['maxResults'], '${FeedLimits.perChannel}');
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
