// المكتبة (الميزة 5): الشرائح، أقسام الحساب وحالاتها، قوائم يوتيوب و«تشغيل
// الكل» و«أضف القائمة كلها» مع التقدّم و«أُضيف n من m»، المفضلة والسجل، وروابط
// القوائم الملصقة.
import 'dart:async';

import 'package:bgtube/app.dart';
import 'package:bgtube/core/app_failure.dart';
import 'package:bgtube/core/providers.dart';
import 'package:bgtube/domain/models/library_entries.dart';
import 'package:bgtube/domain/models/now_playing.dart';
import 'package:bgtube/domain/models/video_ref.dart';
import 'package:bgtube/domain/models/youtube_content.dart';
import 'package:bgtube/domain/ports/auth_service.dart';
import 'package:bgtube/domain/ports/playback_queue.dart';
import 'package:bgtube/features/player/player_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../fakes/fake_auth_service.dart';
import 'home_screen_test.dart' show FakeApi, vid;
import 'player_screen_test.dart' show FakeController;
import 'queue_screen_test.dart' show FakePlaylists;

/// قائمة يوتيوب من [n] مقطعاً بصفحات من 50؛ [failAt] صفحة تفشل بالشبكة.
ApiPage<VideoRef> ytPage(String? token, int n, {int? failAt}) {
  final page = token == null ? 0 : int.parse(token);
  if (failAt == page) throw const AppFailure(FailureKind.network);
  final start = page * 50;
  final end = (start + 50).clamp(0, n);
  return ApiPage([for (var i = start; i < end; i++) vid(i)], nextPageToken: end < n ? '${page + 1}' : null, total: n);
}

void main() {
  late FakeController c;
  late FakeApi api;
  late FakeAuthService auth;
  late MemoryFavoritesRepository favorites;
  late MemoryHistoryRepository history;

  setUp(() {
    c = FakeController();
    api = FakeApi();
    auth = FakeAuthService(AuthStatus.signedIn);
    favorites = MemoryFavoritesRepository();
    history = MemoryHistoryRepository();
  });

  Future<void> pumpApp(WidgetTester t, {Locale locale = const Locale('ar'), Widget? home}) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWithValue(c),
        youTubeApiProvider.overrideWithValue(api),
        authServiceProvider.overrideWithValue(auth),
        riskAckStoreProvider.overrideWithValue(MemRiskAckStore(true)),
        localPlaylistRepositoryProvider.overrideWithValue(FakePlaylists()),
        favoritesRepositoryProvider.overrideWithValue(favorites),
        historyRepositoryProvider.overrideWithValue(history),
      ],
      child: BgtubeApp(locale: locale, home: home),
    ));
    await t.pumpAndSettle();
  }

  Future<void> openLibrary(WidgetTester t, [String? chip]) async {
    await t.tap(find.byKey(const Key('navLibrary')));
    await t.pumpAndSettle();
    if (chip != null) {
      await t.ensureVisible(find.byKey(Key('libraryChip_$chip')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(Key('libraryChip_$chip')));
      await t.pumpAndSettle();
    }
  }

  const playlist = PlaylistSummary(id: 'PLaaa', title: 'Morning mix', itemCount: 120);

  group('chips and sections', () {
    testWidgets('six chips in DESIGN order, first on the right in RTL; local playlists by default', (t) async {
      await pumpApp(t);
      await openLibrary(t);
      final names = ['local', 'playlists', 'likes', 'subscriptions', 'favorites', 'history'];
      final xs = [for (final n in names) t.getCenter(find.byKey(Key('libraryChip_$n'))).dx];
      // تمرير أفقي: الظاهرة على الأقل مرتبة من اليمين لليسار.
      for (var i = 1; i < 3; i++) {
        expect(xs[i], lessThan(xs[i - 1]));
      }
      expect(find.text('قوائم يوتيوب'), findsOneWidget);
      expect(find.text('لم تنشئ قوائم بعد. احفظ الطابور أو أنشئ قائمة'), findsOneWidget);
      // لا طلب لقسم لم يُفتح.
      expect(api.playlistsCalls, isEmpty);
      expect(api.likedCalls, isEmpty);
      expect(api.subscriptionCalls, isEmpty);
    });

    testWidgets('English is LTR: first chip on the left', (t) async {
      await pumpApp(t, locale: const Locale('en'));
      await openLibrary(t);
      expect(t.getCenter(find.byKey(const Key('libraryChip_local'))).dx,
          lessThan(t.getCenter(find.byKey(const Key('libraryChip_playlists'))).dx));
      expect(find.text('YouTube playlists'), findsOneWidget);
    });

    testWidgets('signed out: account sections show the sign-in card without requests; local ones work', (t) async {
      auth = FakeAuthService(AuthStatus.signedOut);
      await pumpApp(t);
      for (final s in ['playlists', 'likes', 'subscriptions']) {
        await openLibrary(t, s);
        expect(find.text('سجّل الدخول لعرض حسابك'), findsOneWidget, reason: s);
        expect(find.byKey(const Key('librarySignInButton')), findsOneWidget);
      }
      expect(api.playlistsCalls, isEmpty);
      expect(api.likedCalls, isEmpty);
      expect(api.subscriptionCalls, isEmpty);
      await openLibrary(t, 'favorites');
      expect(find.text('لم تضف شيئاً بعد. اضغط ⋮ على أي فيديو'), findsOneWidget);
      await openLibrary(t, 'history');
      expect(find.text('لم تشغّل شيئاً بعد'), findsOneWidget);
    });

    testWidgets('expired session: the sign-in card says sign in again', (t) async {
      await pumpApp(t);
      await openLibrary(t, 'likes');
      auth.emit(AuthStatus.expired);
      await t.pumpAndSettle();
      // الحوار العام (D23) وبطاقة القسم معاً.
      expect(find.byKey(const Key('librarySignIn')), findsOneWidget);
      expect(find.text('انتهت جلستك، سجّل الدخول من جديد'), findsWidgets);
    });

    testWidgets('signing out closes what was shown from the account', (t) async {
      api.onPlaylists = (_) => const ApiPage([playlist]);
      await pumpApp(t);
      await openLibrary(t, 'playlists');
      expect(find.text('Morning mix'), findsOneWidget);
      auth.emit(AuthStatus.signedOut);
      await t.pumpAndSettle();
      expect(find.text('Morning mix'), findsNothing);
      expect(find.text('سجّل الدخول لعرض حسابك'), findsOneWidget);
      // دخول من جديد: يُطلب من جديد (حساب قد يكون آخر).
      auth.emit(AuthStatus.signedIn);
      await t.pumpAndSettle();
      expect(api.playlistsCalls, hasLength(2));
    });
  });

  group('account sections states', () {
    testWidgets('loaded once; switching chips does not refetch; pull to refresh does', (t) async {
      api.onPlaylists = (_) => const ApiPage([playlist]);
      await pumpApp(t);
      await openLibrary(t, 'playlists');
      expect(find.text('Morning mix'), findsOneWidget);
      expect(find.text('120 مقطعاً'), findsOneWidget);
      await openLibrary(t, 'favorites');
      await openLibrary(t, 'playlists');
      expect(api.playlistsCalls, [(token: null, refresh: false)]);
      await t.fling(find.text('Morning mix'), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(api.playlistsCalls.last.refresh, isTrue);
    });

    testWidgets('empty sections show a friendly text', (t) async {
      await pumpApp(t);
      for (final s in ['playlists', 'likes', 'subscriptions']) {
        await openLibrary(t, s);
        expect(find.text('لا شيء هنا بعد'), findsOneWidget, reason: s);
      }
    });

    testWidgets('quota, network (with retry), permission and expired errors in place', (t) async {
      var fail = const AppFailure(FailureKind.quotaExceeded) as AppFailure?;
      api.onLiked = (_) => fail != null ? throw fail : ApiPage([vid(1)]);
      await pumpApp(t);
      await openLibrary(t, 'likes');
      expect(find.textContaining('انتهت حصة يوتيوب اليومية'), findsOneWidget);

      fail = const AppFailure(FailureKind.network);
      await t.fling(find.byKey(const Key('apiErrorMessage')), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect(find.textContaining('تعذّر الاتصال بالإنترنت'), findsOneWidget);
      fail = null;
      await t.tap(find.byKey(const Key('apiErrorRetry')));
      await t.pumpAndSettle();
      expect(find.text('Video 1'), findsOneWidget);

      api.onSubscriptions = (_) => throw const AppFailure(FailureKind.insufficientPermissions);
      await openLibrary(t, 'subscriptions');
      expect(find.byKey(const Key('apiErrorGrant')), findsOneWidget);

      api.onPlaylists = (_) => throw const AuthExpired();
      await openLibrary(t, 'playlists');
      expect(find.byKey(const Key('apiErrorSignIn')), findsOneWidget);
    });

    testWidgets('a saved copy is marked', (t) async {
      api.onLiked = (_) => ApiPage([vid(1)], stale: true);
      await pumpApp(t);
      await openLibrary(t, 'likes');
      expect(find.text('هذه نسخة محفوظة'), findsOneWidget);
    });

    testWidgets('subscriptions: tapping a channel opens its latest videos', (t) async {
      api.onSubscriptions = (_) => const ApiPage([ChannelSummary(id: 'UCa', title: 'قناة أ')]);
      api.onChannel = (_, _) => ApiPage([vid(3)]);
      await pumpApp(t);
      await openLibrary(t, 'subscriptions');
      await t.tap(find.text('قناة أ'));
      await t.pumpAndSettle();
      expect(api.channelCalls.single.id, 'UCa');
      expect(find.text('Video 3'), findsOneWidget);
      // الرجوع يعود للمكتبة.
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.text('قناة أ'), findsOneWidget);
    });

    testWidgets('likes list pages load automatically at the end (general quota bucket)', (t) async {
      api.onLiked = (token) => ytPage(token, 60);
      await pumpApp(t);
      await openLibrary(t, 'likes');
      await t.scrollUntilVisible(find.text('Video 59'), 300,
          scrollable: find.descendant(of: find.byKey(const Key('libraryLikes')), matching: find.byType(Scrollable)).first);
      await t.pumpAndSettle();
      expect(api.likedCalls.map((c) => c.token), [null, '1']);
    });
  });

  group('YouTube playlist: play all and add the whole list', () {
    Future<void> openPlaylist(WidgetTester t) async {
      api.onPlaylists = (_) => const ApiPage([playlist]);
      await pumpApp(t);
      await openLibrary(t, 'playlists');
      await t.tap(find.text('Morning mix'));
      await t.pumpAndSettle();
    }

    testWidgets('opens its items; play all fetches every page and enqueues playNow in order', (t) async {
      api.onPlaylistVideos = (id, token) => ytPage(token, 120);
      await openPlaylist(t);
      expect(find.text('Video 0'), findsOneWidget);
      await t.tap(find.byKey(const Key('playAll')));
      await t.pumpAndSettle();
      expect(c.enqueued.single.placement, QueuePlacement.playNow);
      expect(c.enqueued.single.ids, [for (var i = 0; i < 120; i++) vid(i).videoId]);
      expect(c.played, [vid(0).videoId]);
      expect(api.playlistVideoCalls.every((call) => call.id == 'PLaaa'), isTrue);
    });

    testWidgets('add the whole list: sheet with play next / add to end, then a count with undo', (t) async {
      api.onPlaylistVideos = (id, token) => ytPage(token, 70);
      c.seed([vid(900)]);
      await openPlaylist(t);
      await t.tap(find.byKey(const Key('addWholeList')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('placement_playNow')), findsNothing);
      await t.tap(find.byKey(const Key('placement_addToEnd')));
      await t.pumpAndSettle();
      expect(c.enqueued.single.placement, QueuePlacement.addToEnd);
      expect(c.enqueued.single.ids, hasLength(70));
      expect(find.text('أُضيف 70 مقطعاً إلى الطابور'), findsOneWidget);
      await t.tap(find.text('تراجع'));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries, hasLength(1));
    });

    testWidgets('a progress message shows while pages are fetched', (t) async {
      final gate = Completer<void>();
      api.onPlaylistVideos = (id, token) async {
        if (token == '1') await gate.future;
        return ytPage(token, 120);
      };
      c.seed([vid(900)]);
      await openPlaylist(t);
      await t.tap(find.byKey(const Key('addWholeList')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('placement_addToEnd')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('wholeListProgress')), findsOneWidget);
      expect(find.text('جارٍ إضافة القائمة… 50 من 120'), findsOneWidget);
      expect(c.enqueued, isEmpty, reason: 'added once, after fetching');
      gate.complete();
      await t.pumpAndSettle();
      expect(c.enqueued.single.ids, hasLength(120));
    });

    testWidgets('network cut in the middle: "added n of m" and retry adds the rest right after', (t) async {
      int? failAt = 1;
      api.onPlaylistVideos = (id, token) => ytPage(token, 120, failAt: failAt);
      c.seed([vid(900), vid(901)]);
      await openPlaylist(t);
      await t.tap(find.byKey(const Key('addWholeList')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('placement_playNext')));
      await t.pumpAndSettle();
      expect(c.enqueued.single.ids, hasLength(50));
      expect(find.text('أُضيف 50 من 120. تعذّر جلب الباقي'), findsOneWidget);
      failAt = null;
      await t.tap(find.text('إعادة المحاولة'));
      await t.pumpAndSettle();
      // يكمل من الصفحة الفاشلة ويدرج بعد آخر ما أُضيف (لا بعد الحالي).
      expect(api.playlistVideoCalls.where((call) => call.token == null), hasLength(2)); // الشاشة + الإضافة
      expect(c.enqueuedAfter.single.ids, [for (var i = 50; i < 120; i++) vid(i).videoId]);
      final order = [for (final e in c.queueState.value.entries) e.ref.videoId];
      expect(order, [vid(900).videoId, for (var i = 0; i < 120; i++) vid(i).videoId, vid(901).videoId]);
      expect(find.text('أُضيف 120 مقطعاً إلى الطابور'), findsOneWidget);
    });

    testWidgets('failure on the first page: error message with retry, nothing added', (t) async {
      var fail = true;
      api.onPlaylistVideos = (id, token) => fail && token == null && api.playlistVideoCalls.length > 1
          ? throw const AppFailure(FailureKind.quotaExceeded)
          : ytPage(token, 10);
      c.seed([vid(900)]);
      await openPlaylist(t);
      await t.tap(find.byKey(const Key('playAll')));
      await t.pumpAndSettle();
      expect(c.enqueued, isEmpty);
      expect(find.textContaining('انتهت حصة يوتيوب اليومية'), findsOneWidget);
      fail = false;
      await t.tap(find.text('إعادة المحاولة'));
      await t.pumpAndSettle();
      expect(c.enqueued.single.ids, hasLength(10));
    });

    testWidgets('respects the 500 queue limit and says so', (t) async {
      api.onPlaylistVideos = (id, token) => ytPage(token, 5000);
      c.seed([for (var i = 0; i < 490; i++) vid(1000 + i)]);
      await openPlaylist(t);
      await t.tap(find.byKey(const Key('addWholeList')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('placement_addToEnd')));
      await t.pumpAndSettle();
      expect(c.queueState.value.entries, hasLength(PlaybackQueue.maxLength));
      expect(find.textContaining('الطابور ممتلئ'), findsOneWidget);
      // لا يُجلب أكثر مما يتسع له الطابور (+1): صفحة واحدة من 50.
      expect(api.playlistVideoCalls.where((call) => call.token != null), isEmpty);
    });

    testWidgets('the row menu adds the whole list without opening it', (t) async {
      api.onPlaylists = (_) => const ApiPage([playlist]);
      api.onPlaylistVideos = (id, token) => ytPage(token, 3);
      c.seed([vid(900)]);
      await pumpApp(t);
      await openLibrary(t, 'playlists');
      await t.tap(find.byKey(const Key('ytPlaylistMenu_PLaaa')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('placement_playNext')));
      await t.pumpAndSettle();
      expect(c.enqueued.single.placement, QueuePlacement.playNext);
      expect(c.enqueued.single.ids, hasLength(3));
    });
  });

  group('favorites and history (local)', () {
    testWidgets('⋮ on a video adds it to favorites; the favorites chip lists it; ⋮ removes it', (t) async {
      api.onLiked = (_) => ApiPage([vid(1)]);
      await pumpApp(t);
      await openLibrary(t, 'likes');
      await t.tap(find.byKey(Key('videoMore_${vid(1).videoId}')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('videoAction_favorite')));
      await t.pumpAndSettle();
      expect(find.text('أُضيف إلى المفضلة'), findsOneWidget);
      expect(await favorites.list(), [vid(1)]);
      await openLibrary(t, 'favorites');
      expect(find.text('Video 1'), findsOneWidget);
      await t.tap(find.byKey(Key('videoMore_${vid(1).videoId}')));
      await t.pumpAndSettle();
      expect(find.text('أزل من المفضلة'), findsOneWidget);
      await t.tap(find.byKey(const Key('videoAction_favorite')));
      await t.pumpAndSettle();
      expect(await favorites.list(), isEmpty);
      expect(find.text('لم تضف شيئاً بعد. اضغط ⋮ على أي فيديو'), findsOneWidget);
    });

    testWidgets('favorites: play all enqueues them in order', (t) async {
      favorites = MemoryFavoritesRepository([vid(1), vid(2)]);
      await pumpApp(t);
      await openLibrary(t, 'favorites');
      await t.tap(find.byKey(const Key('playAll')));
      await t.pumpAndSettle();
      expect(c.enqueued.single.ids, [vid(1).videoId, vid(2).videoId]);
      expect(c.enqueued.single.placement, QueuePlacement.playNow);
    });

    testWidgets('history: newest first, remove one from ⋮, clear all with confirmation', (t) async {
      final at = DateTime.utc(2026, 11, 26);
      history = MemoryHistoryRepository(initial: [
        HistoryEntry(id: 2, ref: vid(2), playedAt: at),
        HistoryEntry(id: 1, ref: vid(1), playedAt: at),
      ]);
      await pumpApp(t);
      await openLibrary(t, 'history');
      expect(t.getTopLeft(find.text('Video 2')).dy, lessThan(t.getTopLeft(find.text('Video 1')).dy));
      await t.tap(find.byKey(Key('videoMore_${vid(2).videoId}')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('videoAction_removeFromHistory')));
      await t.pumpAndSettle();
      expect(find.text('حُذف من السجل'), findsOneWidget);
      expect((await history.list()).map((e) => e.id), [1]);

      await t.tap(find.byKey(const Key('clearHistory')));
      await t.pumpAndSettle();
      expect(find.text('مسح السجل؟'), findsOneWidget);
      await t.tap(find.text('إلغاء'));
      await t.pumpAndSettle();
      expect(await history.list(), hasLength(1));
      await t.tap(find.byKey(const Key('clearHistory')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('confirmDestructive')));
      await t.pumpAndSettle();
      expect(await history.list(), isEmpty);
      expect(find.text('لم تشغّل شيئاً بعد'), findsOneWidget);
    });

    testWidgets('favorites and history stay after signing out (local, D30)', (t) async {
      favorites = MemoryFavoritesRepository([vid(1)]);
      await pumpApp(t);
      await openLibrary(t, 'favorites');
      auth.emit(AuthStatus.signedOut);
      await t.pumpAndSettle();
      expect(find.text('Video 1'), findsOneWidget);
    });

    testWidgets('the full player star toggles the current video in favorites', (t) async {
      c.seed([vid(4)]);
      c.nowPlaying.value = NowPlaying(videoId: vid(4).videoId, title: 'Video 4');
      await pumpApp(t, home: const PlayerScreen());
      expect(find.byIcon(Icons.star_border), findsOneWidget);
      await t.tap(find.byKey(const Key('favoriteButton')));
      await t.pumpAndSettle();
      expect(await favorites.list(), [vid(4)]);
      expect(find.byIcon(Icons.star), findsOneWidget);
      // الرسالة القصيرة (4 ث) تُغلق قبل النقرة الثانية.
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('favoriteButton')));
      await t.pumpAndSettle();
      expect(await favorites.list(), isEmpty);
    });
  });

  group('playlist links (paste and share)', () {
    Future<void> submit(WidgetTester t, String text) async {
      await t.enterText(find.byKey(const Key('searchField')), text);
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
    }

    testWidgets('signed in, empty queue: a playlist link plays the whole list in order', (t) async {
      api.onPlaylistVideos = (id, token) => ytPage(token, 60);
      await pumpApp(t);
      await submit(t, 'https://www.youtube.com/playlist?list=PLxyz');
      expect(api.playlistVideoCalls.map((call) => (call.id, call.token)), [('PLxyz', null), ('PLxyz', '1')]);
      expect(c.enqueued.single.placement, QueuePlacement.playNow);
      expect(c.enqueued.single.ids, hasLength(60));
    });

    testWidgets('signed in with a queue: the three choices sheet first', (t) async {
      api.onPlaylistVideos = (id, token) => ytPage(token, 3);
      c.seed([vid(900)]);
      await pumpApp(t);
      await submit(t, 'https://www.youtube.com/playlist?list=PLxyz');
      expect(find.byKey(const Key('placement_playNow')), findsOneWidget);
      await t.tap(find.byKey(const Key('placement_addToEnd')));
      await t.pumpAndSettle();
      expect(c.enqueued.single.placement, QueuePlacement.addToEnd);
      expect(find.text('أُضيف 3 مقاطع إلى الطابور'), findsOneWidget);
    });

    testWidgets('signed out: a clear sign-in message and no request', (t) async {
      auth = FakeAuthService(AuthStatus.signedOut);
      await pumpApp(t);
      await submit(t, 'https://www.youtube.com/playlist?list=PLxyz');
      expect(find.text('سجّل الدخول لإضافة قوائم يوتيوب. روابط الفيديو تعمل دون دخول.'), findsOneWidget);
      expect(api.playlistVideoCalls, isEmpty);
      expect(c.enqueued, isEmpty);
    });
  });

  for (final loc in ['ar', 'en']) {
    testWidgets('library sections have no overflow at 1.3x font ($loc)', (t) async {
      t.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
      const long = 'A very long English playlist title that keeps going and going so it wraps';
      api.onPlaylists = (_) => const ApiPage([PlaylistSummary(id: 'PL1', title: long, itemCount: 1234)]);
      api.onLiked = (_) => ApiPage([vid(1)]);
      favorites = MemoryFavoritesRepository([vid(2)]);
      await pumpApp(t, locale: Locale(loc));
      for (final s in ['playlists', 'likes', 'subscriptions', 'favorites', 'history']) {
        await openLibrary(t, s);
        expect(t.takeException(), isNull, reason: s);
      }
    });
  }
}
