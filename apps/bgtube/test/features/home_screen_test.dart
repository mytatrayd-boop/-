import 'dart:async';

import 'package:bgtube/app.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/models/now_playing.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/models/youtube_content.dart';
import 'package:bgtube/domain/ports/auth_service.dart';
import 'package:bgtube/domain/ports/playback_queue.dart';
import 'package:bgtube/domain/ports/youtube_api.dart';
import 'package:bgtube/features/player/player_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes/fake_auth_service.dart';
import 'player_screen_test.dart' show FakeController;
import 'queue_screen_test.dart' show FakePlaylists;

/// واجهة وهمية: ردود مبرمجة لكل استدعاء، وسجل بالاستدعاءات.
class FakeApi implements YouTubeApi {
  final searches = <({String query, String? token})>[];
  final channelCalls = <({String id, String? token, bool refresh})>[];
  final feedCalls = <bool>[];
  int titleCalls = 0;

  FutureOr<ApiPage<SearchResult>> Function(String q, String? token) onSearch =
      (_, _) => const ApiPage([]);
  FutureOr<ApiPage<VideoRef>> Function(String id, String? token) onChannel = (_, _) => const ApiPage([]);
  FutureOr<ApiPage<VideoRef>> Function(bool refresh) onFeed = (_) => const ApiPage([]);
  String? channelTitle = 'قناتي';
  QuotaUsage quota = const QuotaUsage(used: 320, limit: 10000, exhausted: false, searchesLeft: 91);

  @override
  Future<ApiPage<SearchResult>> search(String query, {String? pageToken}) async {
    searches.add((query: query, token: pageToken));
    return onSearch(query, pageToken);
  }

  @override
  Future<ApiPage<VideoRef>> channelVideos(String channelId, {String? pageToken, bool refresh = false}) async {
    channelCalls.add((id: channelId, token: pageToken, refresh: refresh));
    return onChannel(channelId, pageToken);
  }

  @override
  Future<ApiPage<VideoRef>> subscriptionFeed({bool refresh = false}) async {
    feedCalls.add(refresh);
    return onFeed(refresh);
  }

  @override
  Future<String?> myChannelTitle() async {
    titleCalls++;
    return channelTitle;
  }

  @override
  Future<QuotaUsage> quotaToday() async => quota;
}

VideoRef vid(int i, {String? author = 'Chan'}) => VideoRef(
      videoId: 'VID${i.toString().padLeft(8, '0')}',
      title: 'Video $i',
      author: author,
      duration: const Duration(minutes: 4, seconds: 5),
    );

Future<void> pumpHome(
  WidgetTester t, {
  required FakeController c,
  required FakeApi api,
  AuthStatus status = AuthStatus.signedIn,
  FakePlaylists? playlists,
  Locale locale = const Locale('ar'),
}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [
      playbackControllerProvider.overrideWithValue(c),
      youTubeApiProvider.overrideWithValue(api),
      authServiceProvider.overrideWithValue(FakeAuthService(status)),
      riskAckStoreProvider.overrideWithValue(MemRiskAckStore(true)),
      localPlaylistRepositoryProvider.overrideWithValue(playlists ?? FakePlaylists()),
    ],
    child: BgtubeApp(locale: locale),
  ));
  await t.pumpAndSettle();
}

Future<void> search(WidgetTester t, String q) async {
  await t.enterText(find.byKey(const Key('searchField')), q);
  await t.testTextInput.receiveAction(TextInputAction.search);
  await t.pumpAndSettle();
}

void main() {
  late FakeController c;
  late FakeApi api;
  setUp(() {
    c = FakeController();
    api = FakeApi();
  });

  group('bottom navigation and layout', () {
    testWidgets('three destinations; Home is first, on the right in RTL', (t) async {
      await pumpHome(t, c: c, api: api);
      expect(find.byKey(const Key('bottomNav')), findsOneWidget);
      final home = t.getCenter(find.byKey(const Key('navHome')));
      final library = t.getCenter(find.byKey(const Key('navLibrary')));
      final settings = t.getCenter(find.byKey(const Key('navSettings')));
      expect(home.dx, greaterThan(library.dx));
      expect(library.dx, greaterThan(settings.dx));
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('المكتبة'), findsOneWidget);
    });

    testWidgets('English is LTR: Home on the left', (t) async {
      await pumpHome(t, c: c, api: api, locale: const Locale('en'));
      expect(t.getCenter(find.byKey(const Key('navHome'))).dx,
          lessThan(t.getCenter(find.byKey(const Key('navSettings'))).dx));
      expect(find.text('Latest from your subscriptions'), findsOneWidget);
    });

    testWidgets('the search field is in the bottom third, above the bottom bar', (t) async {
      await pumpHome(t, c: c, api: api);
      final h = t.view.physicalSize.height / t.view.devicePixelRatio;
      final field = t.getRect(find.byKey(const Key('searchField')));
      expect(field.center.dy, greaterThan(h * 2 / 3));
      expect(field.bottom, lessThanOrEqualTo(t.getRect(find.byKey(const Key('bottomNav'))).top));
    });

    testWidgets('Library is a placeholder that opens My local playlists; Settings tab works', (t) async {
      await pumpHome(t, c: c, api: api);
      await t.tap(find.byKey(const Key('navLibrary')));
      await t.pumpAndSettle();
      expect(find.text('قوائمي المحلية'), findsOneWidget);
      await t.tap(find.byKey(const Key('navSettings')));
      await t.pumpAndSettle();
      expect(find.text('اللغة'), findsOneWidget);
    });

    testWidgets('system back goes to Home from another tab', (t) async {
      await pumpHome(t, c: c, api: api);
      await t.tap(find.byKey(const Key('navSettings')));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('أحدث فيديوهات اشتراكاتك'), findsOneWidget);
    });
  });

  group('home feed (signed in)', () {
    testWidgets('loads once, shows rows with title, channel and duration; no automatic refresh', (t) async {
      api.onFeed = (_) => ApiPage([vid(1), vid(2)]);
      await pumpHome(t, c: c, api: api);
      expect(find.text('أحدث فيديوهات اشتراكاتك'), findsOneWidget);
      expect(find.text('Video 1'), findsOneWidget);
      expect(find.text('Chan · 4:05'), findsNWidgets(2));
      // التنقل بين الوجهات لا يعيد الطلب.
      await t.tap(find.byKey(const Key('navSettings')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('navHome')));
      await t.pumpAndSettle();
      expect(api.feedCalls, [false]);
      expect(t.takeException(), isNull);
    });

    testWidgets('pull to refresh asks for fresh data', (t) async {
      api.onFeed = (_) => ApiPage([vid(1), vid(2)]);
      await pumpHome(t, c: c, api: api);
      await t.fling(find.text('Video 1'), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(api.feedCalls, [false, true]);
    });

    testWidgets('empty feed shows a friendly text', (t) async {
      await pumpHome(t, c: c, api: api);
      expect(find.textContaining('لا شيء هنا بعد'), findsOneWidget);
    });

    testWidgets('a saved copy is marked', (t) async {
      api.onFeed = (_) => ApiPage([vid(1)], stale: true);
      await pumpHome(t, c: c, api: api);
      expect(find.text('هذه نسخة محفوظة'), findsOneWidget);
    });

    testWidgets('no internet: message and retry that works', (t) async {
      var fail = true;
      api.onFeed = (_) => fail ? throw const AppFailure(FailureKind.network) : ApiPage([vid(1)]);
      await pumpHome(t, c: c, api: api);
      expect(find.textContaining('تعذّر الاتصال بالإنترنت'), findsOneWidget);
      fail = false;
      await t.tap(find.byKey(const Key('apiErrorRetry')));
      await t.pumpAndSettle();
      expect(find.text('Video 1'), findsOneWidget);
    });

    testWidgets('expired session from the API shows the sign-in button', (t) async {
      api.onFeed = (_) => throw const AuthExpired();
      await pumpHome(t, c: c, api: api);
      expect(find.text('انتهت جلستك، سجّل الدخول من جديد'), findsOneWidget);
      expect(find.byKey(const Key('apiErrorSignIn')), findsOneWidget);
    });
  });

  group('video row actions', () {
    testWidgets('tap plays now', (t) async {
      api.onFeed = (_) => ApiPage([vid(1), vid(2)]);
      await pumpHome(t, c: c, api: api);
      await t.tap(find.text('Video 2'));
      await t.pumpAndSettle();
      expect(c.played, [vid(2).videoId]);
      expect(c.enqueued.single.placement, QueuePlacement.playNow);
      // تمرّر البيانات الوصفية جاهزة (لا استخراج للعرض).
      expect(c.queueState.value.current!.ref, vid(2));
    });

    testWidgets('⋮ shows play next, add to end, add to local playlist (in that order)', (t) async {
      api.onFeed = (_) => ApiPage([vid(1)]);
      c.seed([vid(9)]);
      await pumpHome(t, c: c, api: api);
      await t.tap(find.byKey(Key('videoMore_${vid(1).videoId}')));
      await t.pumpAndSettle();
      final y = [
        t.getCenter(find.byKey(const Key('videoAction_playNext'))).dy,
        t.getCenter(find.byKey(const Key('videoAction_addToEnd'))).dy,
        t.getCenter(find.byKey(const Key('videoAction_addToLocal'))).dy,
      ];
      expect(y[0], lessThan(y[1]));
      expect(y[1], lessThan(y[2]));
      await t.tap(find.byKey(const Key('videoAction_playNext')));
      await t.pumpAndSettle();
      expect(c.enqueued.last.placement, QueuePlacement.playNext);
      expect(find.text('سيُشغَّل التالي: Video 1'), findsOneWidget);
    });

    testWidgets('long press opens the same menu; add to end; add to a local playlist', (t) async {
      final p = FakePlaylists();
      await p.create('أ', []);
      api.onFeed = (_) => ApiPage([vid(1)]);
      c.seed([vid(9)]);
      await pumpHome(t, c: c, api: api, playlists: p);
      await t.longPress(find.text('Video 1'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('videoAction_addToEnd')));
      await t.pumpAndSettle();
      expect(c.enqueued.last.placement, QueuePlacement.addToEnd);
      expect(c.queueState.value.entries.last.ref.videoId, vid(1).videoId);
      await t.longPress(find.text('Video 1'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('videoAction_addToLocal')));
      await t.pumpAndSettle();
      await t.tap(find.text('أ'));
      await t.pumpAndSettle();
      expect(p.items_.values.single.single.videoId, vid(1).videoId);
    });
  });

  group('search', () {
    testWidgets('typing a query searches once and shows videos and channels', (t) async {
      api.onSearch = (q, _) => ApiPage([
            VideoResult(vid(1)),
            const ChannelResult(ChannelSummary(id: 'UC1', title: 'Some Channel')),
          ]);
      await pumpHome(t, c: c, api: api);
      await search(t, 'محاضرة');
      expect(api.searches.single.query, 'محاضرة');
      expect(find.text('نتائج «محاضرة»'), findsOneWidget);
      expect(find.text('Video 1'), findsOneWidget);
      expect(find.text('Some Channel'), findsOneWidget);
      expect(find.text('قناة'), findsOneWidget);
      // الإغلاق يعود للرئيسية بلا طلب جديد.
      await t.tap(find.byKey(const Key('closeSearch')));
      await t.pumpAndSettle();
      expect(find.text('أحدث فيديوهات اشتراكاتك'), findsOneWidget);
      expect(api.searches, hasLength(1));
    });

    testWidgets('scrolling to the end loads more with the page token', (t) async {
      api.onSearch = (q, token) => token == null
          ? ApiPage([for (var i = 0; i < 12; i++) VideoResult(vid(i))], nextPageToken: 'P2')
          : ApiPage([VideoResult(vid(99))]);
      await pumpHome(t, c: c, api: api);
      await search(t, 'x');
      await t.scrollUntilVisible(find.text('Video 99'), 300, scrollable: find.byType(Scrollable).first);
      await t.pumpAndSettle();
      expect(api.searches.map((s) => s.token), [null, 'P2']);
      expect(find.text('Video 99'), findsOneWidget);
    });

    testWidgets('no results', (t) async {
      await pumpHome(t, c: c, api: api);
      await search(t, 'zzz');
      expect(find.text('لا نتائج لـ «zzz». جرّب كلمات أخرى'), findsOneWidget);
    });

    testWidgets('quota exhausted: the DESIGN message and a paste-link action, no crash', (t) async {
      api.onSearch = (_, _) => throw const AppFailure(FailureKind.quotaExceeded);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') return {'text': 'https://youtu.be/dQw4w9WgXcQ'};
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpHome(t, c: c, api: api);
      await search(t, 'x');
      expect(find.textContaining('انتهت حصة البحث اليوم'), findsOneWidget);
      expect(find.byKey(const Key('apiErrorRetry')), findsNothing);
      await t.tap(find.byKey(const Key('apiErrorPaste')));
      await t.pumpAndSettle();
      expect(c.played, ['dQw4w9WgXcQ']);
      expect(t.takeException(), isNull);
    });

    testWidgets('a link typed in the search field plays instead of searching', (t) async {
      await pumpHome(t, c: c, api: api);
      await search(t, 'https://youtu.be/dQw4w9WgXcQ');
      expect(c.played, ['dQw4w9WgXcQ']);
      expect(api.searches, isEmpty);
    });

    testWidgets('a channel result opens its videos (uploads), with pull to refresh', (t) async {
      api.onSearch = (_, _) => const ApiPage([ChannelResult(ChannelSummary(id: 'UC1', title: 'Some Channel'))]);
      api.onChannel = (_, _) => ApiPage([vid(5)]);
      await pumpHome(t, c: c, api: api);
      await search(t, 'x');
      await t.tap(find.text('Some Channel'));
      await t.pumpAndSettle();
      expect(find.text('Video 5'), findsOneWidget);
      expect(api.channelCalls.single.id, 'UC1');
      // المصغّر والشريط السفلي يبقيان ظاهرين داخل القناة.
      expect(find.byKey(const Key('bottomNav')), findsOneWidget);
      await t.fling(find.text('Video 5'), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(api.channelCalls.map((x) => x.refresh), [false, true]);
      await t.tap(find.text('Video 5'));
      await t.pumpAndSettle();
      expect(c.played, [vid(5).videoId]);
      // رجوع النظام داخل الوجهة يعود للنتائج.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('Some Channel'), findsOneWidget);
    });
  });

  group('signed out', () {
    testWidgets('home invites to sign in and does not call the API', (t) async {
      await pumpHome(t, c: c, api: api, status: AuthStatus.signedOut);
      expect(find.textContaining('ابدأ بالبحث أو الصق رابطاً'), findsOneWidget);
      expect(find.byKey(const Key('homeSignIn')), findsOneWidget);
      expect(api.feedCalls, isEmpty);
    });

    testWidgets('searching without an account explains that sign-in is needed', (t) async {
      api.onSearch = (_, _) => throw const AppFailure(FailureKind.notSignedIn);
      await pumpHome(t, c: c, api: api, status: AuthStatus.signedOut);
      await search(t, 'x');
      expect(find.text('سجّل الدخول للبحث في يوتيوب. يمكنك لصق رابط دون دخول.'), findsOneWidget);
      expect(find.byKey(const Key('apiErrorSignIn')), findsOneWidget);
    });
  });

  group('mini player', () {
    testWidgets('hidden with nothing playing', (t) async {
      await pumpHome(t, c: c, api: api);
      expect(find.byKey(const Key('miniPlayer')), findsNothing);
    });

    testWidgets('title, remaining count, play/pause and next; tap opens the full player', (t) async {
      await pumpHome(t, c: c, api: api);
      c.seed([vid(1), vid(2), vid(3)]);
      c.nowPlaying.value = NowPlaying(videoId: vid(1).videoId, title: 'Video 1', author: 'Chan');
      c.playing.value = true;
      await t.pumpAndSettle();
      expect(find.byKey(const Key('miniPlayer')), findsOneWidget);
      expect(find.byKey(const Key('miniTitle')), findsOneWidget);
      expect(find.text(' · اثنان متبقيان'), findsOneWidget);
      // فوق الشريط السفلي مباشرة.
      expect(t.getRect(find.byKey(const Key('miniPlayer'))).bottom,
          lessThanOrEqualTo(t.getRect(find.byKey(const Key('bottomNav'))).top + 0.5));
      await t.tap(find.byKey(const Key('miniPlayPause')));
      expect(c.pauses, 1);
      await t.tap(find.byKey(const Key('miniNext')));
      expect(c.nexts, 1);
      await t.tap(find.byKey(const Key('miniRemaining')));
      await t.pumpAndSettle();
      expect(find.text('الطابور'), findsWidgets);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('miniTitle')));
      await t.pumpAndSettle();
      expect(find.byType(PlayerScreen), findsOneWidget);
      expect(find.byKey(const Key('speedButton')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('next is disabled at the end of the queue', (t) async {
      await pumpHome(t, c: c, api: api);
      c.seed([vid(1)]);
      await t.pumpAndSettle();
      expect(t.widget<IconButton>(find.byKey(const Key('miniNext'))).onPressed, isNull);
      expect(find.byKey(const Key('miniRemaining')), findsNothing);
    });

    testWidgets('failure: "Couldn\'t play" in error color with a retry button', (t) async {
      await pumpHome(t, c: c, api: api);
      c.seed([vid(1)]);
      c.failure.value = const AppFailure(FailureKind.extractionFailed);
      await t.pumpAndSettle();
      expect(find.text('تعذّر التشغيل'), findsOneWidget);
      await t.tap(find.byKey(const Key('miniRetry')));
      expect(c.retries, 1);
    });

    testWidgets('loading shows a small spinner instead of play', (t) async {
      await pumpHome(t, c: c, api: api);
      c.seed([vid(1)]);
      c.resolving.value = true;
      await t.pump();
      expect(find.byKey(const Key('miniPlayPause')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('settings', () {
    testWidgets('account shows the channel name; quota line', (t) async {
      await pumpHome(t, c: c, api: api);
      await t.tap(find.byKey(const Key('navSettings')));
      await t.pumpAndSettle();
      expect(find.text('متصل: قناتي'), findsOneWidget);
      expect(find.text('حصة البحث'), findsOneWidget);
      expect(find.text('91 عملية بحث متبقية اليوم'), findsOneWidget);
      expect(find.textContaining('320 من 10,000 وحدة'), findsOneWidget);
    });

    testWidgets('exhausted quota is stated in settings', (t) async {
      api.quota = const QuotaUsage(used: 10000, limit: 10000, exhausted: true, searchesLeft: 0);
      await pumpHome(t, c: c, api: api);
      await t.tap(find.byKey(const Key('navSettings')));
      await t.pumpAndSettle();
      expect(find.textContaining('انتهت حصة البحث اليوم'), findsOneWidget);
    });

    testWidgets('without a channel name the generic text stays', (t) async {
      api.channelTitle = null;
      await pumpHome(t, c: c, api: api);
      await t.tap(find.byKey(const Key('navSettings')));
      await t.pumpAndSettle();
      expect(find.text('متصل بحساب جوجل'), findsOneWidget);
    });
  });

  for (final loc in ['ar', 'en']) {
    testWidgets('home with results and mini player has no overflow at 1.3x font ($loc)', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      api.onFeed = (_) => ApiPage([
            for (var i = 0; i < 5; i++)
              VideoRef(
                videoId: 'VID${i.toString().padLeft(8, '0')}',
                title: 'A very long English title that keeps going and going so it needs two lines $i',
                author: 'قناة باسم طويل جداً جداً',
                duration: const Duration(hours: 1, minutes: 2, seconds: 3),
              ),
          ]);
      await pumpHome(t, c: c, api: api, locale: Locale(loc));
      c.seed([vid(1), vid(2)]);
      c.nowPlaying.value = NowPlaying(videoId: vid(1).videoId, title: 'عنوان طويل جداً للمقطع الذي يعمل الآن', author: 'Chan');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
