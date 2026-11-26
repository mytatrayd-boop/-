// المكتبة في طبقة الواجهة (الميزة 5، D30): قوائم المستخدم وعناصرها والإعجابات
// (قائمة الإعجابات ثم myRating=like) والاشتراكات، مع الكاش والحصة والجيل.
import 'dart:async';

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

import 'youtube_data_api_test.dart' show TokenAuth, FakeServer, ok, apiError, durationsBody, playlistBody;

Map<String, dynamic> playlistsBody({String? next}) => {
      'nextPageToken': ?next,
      'pageInfo': {'totalResults': 2},
      'items': [
        {
          'id': 'PLaaa',
          'snippet': {
            'title': 'Morning &amp; Night',
            'thumbnails': {
              'medium': {'url': 'https://i.ytimg.com/p.jpg'},
            },
          },
          'contentDetails': {'itemCount': 120},
        },
        {
          'id': 'PLbbb',
          'snippet': {'title': 'محاضرات'},
          'contentDetails': {'itemCount': 0},
        },
        // بلا عنوان: يُهمل.
        {'id': 'PLccc', 'snippet': {}},
      ],
    };

Map<String, dynamic> likesChannelBody(String? likes) => {
      'items': [
        if (likes != null)
          {
            'contentDetails': {
              'relatedPlaylists': {'likes': likes},
            },
          },
      ],
    };

Map<String, dynamic> ratedBody({String? next}) => {
      'nextPageToken': ?next,
      'pageInfo': {'totalResults': 75},
      'items': [
        {
          'id': 'RATEDAAAAAA',
          'snippet': {
            'title': 'Liked &#39;one&#39;',
            'channelTitle': 'Chan',
            'thumbnails': {
              'medium': {'url': 'https://i.ytimg.com/r.jpg'},
            },
          },
          'contentDetails': {'duration': 'PT3M10S'},
        },
      ],
    };

Map<String, dynamic> subscriptionsBody({String? next}) => {
      'nextPageToken': ?next,
      'items': [
        {
          'snippet': {
            'title': 'قناة أ',
            'resourceId': {'channelId': 'UCa'},
            'thumbnails': {
              'default': {'url': 'https://yt3/a.jpg'},
            },
          },
        },
        {
          'snippet': {
            'title': 'B &amp; C',
            'resourceId': {'channelId': 'UCb'},
          },
        },
      ],
    };

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late FakeServer server;
  late TokenAuth auth;
  late DateTime now;
  late DriftQuotaStore quotaStore;
  late YouTubeDataApi api;

  YouTubeDataApi build({BucketLimit general = const BucketLimit(10000, stopFraction: 0.95)}) {
    final c = Clock(() => now);
    return YouTubeDataApi(
      auth: auth,
      client: server.client,
      cache: DriftApiCacheStore(db),
      quota: QuotaMeter(quotaStore, clock: c, general: general),
      clock: c,
    );
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    server = FakeServer();
    auth = TokenAuth();
    now = DateTime.utc(2026, 11, 26, 12);
    quotaStore = DriftQuotaStore(db);
    api = build();
  });
  tearDown(() async {
    await api.dispose();
    await db.close();
  });

  Future<int> general() async => (await api.quotaToday()).general.used;
  Map<String, String> params(int i) => server.requests[i].url.queryParameters;

  /// videos: myRating=like أو المدد.
  void serveVideos({FutureOr<http.Response> Function(http.Request)? rated}) {
    server.handlers['videos'] = (req) {
      if (req.url.queryParameters['myRating'] == 'like') {
        return rated == null ? ok(ratedBody()) : rated(req);
      }
      final ids = req.url.queryParameters['id']!.split(',');
      return ok(durationsBody({for (final id in ids) id: 'PT2M'}));
    };
  }

  group('myPlaylists', () {
    test('playlists.list mine=true, one unit, parses title/count/thumbnail and total; cached 15 min', () async {
      server.handlers['playlists'] = (_) => ok(playlistsBody(next: 'N2'));
      final page = await api.myPlaylists();
      expect(server.endpoints, ['playlists']);
      expect(params(0)['mine'], 'true');
      expect(params(0)['part'], 'snippet,contentDetails');
      expect(params(0)['maxResults'], '50');
      expect(params(0)['fields'], contains('contentDetails/itemCount'));
      expect(server.requests[0].headers['Authorization'], startsWith('Bearer '));
      expect(page.items, const [
        PlaylistSummary(id: 'PLaaa', title: 'Morning & Night', itemCount: 120, thumbUrl: 'https://i.ytimg.com/p.jpg'),
        PlaylistSummary(id: 'PLbbb', title: 'محاضرات', itemCount: 0),
      ]);
      expect(page.nextPageToken, 'N2');
      expect(page.total, 2);
      expect(await general(), 1);

      await api.myPlaylists();
      expect(server.requests, hasLength(1), reason: 'served from the cache');
      now = now.add(const Duration(minutes: 16));
      await api.myPlaylists();
      expect(server.requests, hasLength(2), reason: 'TTL 15 min');
      await api.myPlaylists(refresh: true);
      expect(server.requests, hasLength(3), reason: 'pull to refresh bypasses the cache');
    });

    test('signed out: no request and no quota', () async {
      auth.status = AuthStatus.signedOut;
      await expectLater(
          api.myPlaylists(), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.notSignedIn)));
      expect(server.requests, isEmpty);
      expect(await general(), 0);
    });

    test('general quota used up: quotaExceeded, or the saved copy marked stale', () async {
      api = build(general: const BucketLimit(2));
      server.handlers['playlists'] = (_) => ok(playlistsBody());
      await api.myPlaylists();
      await api.myPlaylists(refresh: true);
      final stale = await api.myPlaylists(refresh: true);
      expect(stale.stale, isTrue);
      expect(stale.items, hasLength(2));
      expect(server.requests, hasLength(2));
      await expectLater(api.mySubscriptions(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.quotaExceeded)));
    });
  });

  group('playlistVideos', () {
    test('playlistItems with 50 per page and the total, then one durations call; private items dropped', () async {
      server.handlers['playlistItems'] = (req) => ok({
            ...playlistBody([('VIDAAAAAAAA', '2026-01-01T00:00:00Z'), ('VIDBBBBBBBB', '2026-01-02T00:00:00Z')],
                next: 'NEXT'),
            'pageInfo': {'totalResults': 120},
          });
      serveVideos();
      final page = await api.playlistVideos('PLaaa');
      expect(server.endpoints, ['playlistItems', 'videos']);
      expect(params(0)['playlistId'], 'PLaaa');
      expect(params(0)['maxResults'], '50');
      expect(params(0)['fields'], startsWith('pageInfo/totalResults,'));
      expect(page.items.map((v) => v.videoId), ['VIDAAAAAAAA', 'VIDBBBBBBBB']);
      expect(page.items.first.duration, const Duration(minutes: 2));
      expect(page.total, 120);
      expect(page.nextPageToken, 'NEXT');
      expect(await general(), 2);

      await api.playlistVideos('PLaaa', pageToken: 'NEXT');
      expect(server.requests[2].url.queryParameters['pageToken'], 'NEXT');
    });

    test('a 404 playlist is apiFailed with retry (not a crash)', () async {
      server.handlers['playlistItems'] = (_) => apiError(404, 'playlistNotFound');
      await expectLater(
          api.playlistVideos('PLgone'), throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.apiFailed)));
    });
  });

  group('likedVideos (D30)', () {
    test('uses the likes playlist from channels.list (relatedPlaylists.likes) and keeps its pages', () async {
      server.handlers['channels'] = (_) => ok(likesChannelBody('LL'));
      server.handlers['playlistItems'] =
          (req) => ok(playlistBody([('LIKEDAAAAAA', '2026-01-01T00:00:00Z')], next: 'L2'));
      serveVideos();
      final page = await api.likedVideos();
      expect(server.endpoints, ['channels', 'playlistItems', 'videos']);
      expect(params(0)['mine'], 'true');
      expect(params(0)['part'], 'contentDetails');
      expect(params(1)['playlistId'], 'LL');
      expect(page.items.single.videoId, 'LIKEDAAAAAA');
      expect(page.nextPageToken, '${YouTubeDataApi.likesPlaylistPrefix}L2');
      expect(server.requests.any((r) => r.url.queryParameters['myRating'] != null), isFalse);

      await api.likedVideos(pageToken: page.nextPageToken);
      final second = server.requests.lastWhere((r) => r.url.path.endsWith('playlistItems'));
      expect(second.url.queryParameters['pageToken'], 'L2');
      // معرّف قائمة الإعجابات من الكاش (24 ساعة): طلب channels واحد فقط.
      expect(server.endpoints.where((e) => e == 'channels'), hasLength(1));
    });

    test('no channel: falls back to videos.list?myRating=like (durations in the same call)', () async {
      server.handlers['channels'] = (_) => ok(likesChannelBody(null));
      serveVideos();
      final page = await api.likedVideos();
      expect(server.endpoints, ['channels', 'videos']);
      final rated = params(1);
      expect(rated['myRating'], 'like');
      expect(rated['part'], 'snippet,contentDetails');
      expect(rated['maxResults'], '50');
      expect(page.items.single.title, "Liked 'one'");
      expect(page.items.single.duration, const Duration(minutes: 3, seconds: 10));
      expect(page.total, 75);
      expect(await general(), 2);
    });

    test('likes playlist answering 404 or 403 falls back; rating pages keep their source', () async {
      for (final (code, reason) in [(404, 'playlistNotFound'), (403, 'playlistItemsNotAccessible')]) {
        await api.dispose();
        await db.close();
        db = AppDatabase(NativeDatabase.memory());
        quotaStore = DriftQuotaStore(db);
        server = FakeServer();
        api = build();
        server.handlers['channels'] = (_) => ok(likesChannelBody('LL'));
        server.handlers['playlistItems'] = (_) => apiError(code, reason);
        serveVideos(rated: (req) => ok(ratedBody(next: 'R2')));
        final page = await api.likedVideos();
        expect(page.items.single.videoId, 'RATEDAAAAAA', reason: '$code');
        expect(page.nextPageToken, '${YouTubeDataApi.likesRatingPrefix}R2');
        await api.likedVideos(pageToken: page.nextPageToken);
        final last = server.requests.last.url.queryParameters;
        expect(last['myRating'], 'like');
        expect(last['pageToken'], 'R2');
        expect(server.endpoints.where((e) => e == 'playlistItems'), hasLength(1), reason: 'no retry of the playlist');
      }
    });

    test('an empty likes playlist falls back to myRating', () async {
      server.handlers['channels'] = (_) => ok(likesChannelBody('LL'));
      server.handlers['playlistItems'] = (_) => ok({'items': []});
      serveVideos();
      final page = await api.likedVideos();
      expect(page.items.single.videoId, 'RATEDAAAAAA');
    });

    test('missing permission is not hidden by the fallback', () async {
      server.handlers['channels'] = (_) => ok(likesChannelBody('LL'));
      server.handlers['playlistItems'] = (_) => apiError(403, 'insufficientPermissions');
      serveVideos();
      await expectLater(api.likedVideos(),
          throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.insufficientPermissions)));
      expect(server.requests.any((r) => r.url.queryParameters['myRating'] != null), isFalse);
    });
  });

  group('mySubscriptions', () {
    test('subscriptions.list mine=true alphabetical, 50 per page; parses channels', () async {
      server.handlers['subscriptions'] = (_) => ok(subscriptionsBody(next: 'S2'));
      final page = await api.mySubscriptions();
      expect(params(0)['mine'], 'true');
      expect(params(0)['order'], 'alphabetical');
      expect(params(0)['maxResults'], '50');
      expect(page.items, const [
        ChannelSummary(id: 'UCa', title: 'قناة أ', thumbUrl: 'https://yt3/a.jpg'),
        ChannelSummary(id: 'UCb', title: 'B & C'),
      ]);
      expect(page.nextPageToken, 'S2');
      expect(await general(), 1);
    });
  });

  group('account isolation', () {
    test('sign-out wipes playlists, likes and subscriptions from the cache', () async {
      server.handlers['playlists'] = (_) => ok(playlistsBody());
      server.handlers['subscriptions'] = (_) => ok(subscriptionsBody());
      server.handlers['channels'] = (_) => ok(likesChannelBody(null));
      serveVideos();
      await api.myPlaylists();
      await api.mySubscriptions();
      await api.likedVideos();
      expect(await db.select(db.apiCache).get(), isNotEmpty);
      auth.status = AuthStatus.signedOut;
      auth.changes.add(AuthStatus.signedOut);
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), isEmpty);
      // حساب جديد: يُطلب من الخادم لا من الكاش.
      auth.status = AuthStatus.signedIn;
      auth.changes.add(AuthStatus.signedIn);
      final before = server.requests.length;
      await api.myPlaylists();
      expect(server.requests.length, before + 1);
    });

    test('a playlists response arriving after sign-out is neither cached nor returned', () async {
      final gate = Completer<http.Response>();
      server.handlers['playlists'] = (_) => gate.future;
      final pending = api.myPlaylists();
      await pumpEventQueue();
      auth.status = AuthStatus.signedOut;
      auth.changes.add(AuthStatus.signedOut);
      await pumpEventQueue();
      gate.complete(ok(playlistsBody()));
      await expectLater(
          pending, throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', FailureKind.notSignedIn)));
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), isEmpty);
    });

    test('likes fallback started before sign-out is not returned after it', () async {
      server.handlers['channels'] = (_) => ok(likesChannelBody(null));
      final gate = Completer<http.Response>();
      serveVideos(rated: (_) => gate.future);
      final pending = api.likedVideos();
      await pumpEventQueue();
      auth.status = AuthStatus.signedOut;
      auth.changes.add(AuthStatus.signedOut);
      await pumpEventQueue();
      gate.complete(ok(ratedBody()));
      await expectLater(pending, throwsA(isA<AppFailure>()));
      await pumpEventQueue();
      expect(await db.select(db.apiCache).get(), isEmpty);
    });
  });
}
