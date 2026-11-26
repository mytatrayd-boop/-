import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_failure.dart';
import '../domain/ports/auth_service.dart';
import '../domain/ports/favorites_repository.dart';
import '../domain/ports/play_history.dart';
import '../domain/ports/incoming_link_source.dart';
import '../domain/ports/local_playlist_repository.dart';
import '../domain/ports/locale_store.dart';
import '../domain/ports/playback_controller.dart';
import '../domain/ports/playback_queue.dart';
import '../domain/ports/risk_ack_store.dart';
import '../domain/ports/youtube_api.dart';
import '../domain/models/video_ref.dart';
import '../domain/models/youtube_content.dart';
import '../domain/models/library_entries.dart';

/// يُستبدل عند الإقلاع (main) بالمعالج الحقيقي، وفي الاختبارات بتنفيذ وهمي.
final playbackControllerProvider = Provider<PlaybackController>(
  (ref) => throw UnimplementedError('playbackControllerProvider must be overridden'),
);

/// منفذ الطابور الوحيد (D27). يُربط في main بالمعالج نفسه؛ الافتراضي يأخذه من
/// المتحكم إن كان ينفّذه (المعالج والمتحكم الوهمي في الاختبارات).
final playbackQueueProvider = Provider<PlaybackQueue>((ref) {
  final c = ref.watch(playbackControllerProvider);
  if (c is PlaybackQueue) return c as PlaybackQueue;
  throw UnimplementedError('playbackQueueProvider must be overridden');
});

/// القوائم المحلية. تُستبدل في main بتنفيذ drift.
final localPlaylistRepositoryProvider = Provider<LocalPlaylistRepository>(
  (ref) => throw UnimplementedError('localPlaylistRepositoryProvider must be overridden'),
);

/// المفضلة المحلية (الميزة 5). تُستبدل في main بتنفيذ drift؛ الافتراضي في الذاكرة.
final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) => MemoryFavoritesRepository());

/// سجل التشغيل المحلي (الميزة 5). يُستبدل في main بتنفيذ drift (المعالج يكتب
/// فيه عبر `PlayHistoryRecorder`)؛ الافتراضي في الذاكرة.
final historyRepositoryProvider = Provider<HistoryRepository>((ref) => MemoryHistoryRepository());

/// يُستبدل عند الإقلاع بالمصدر الحقيقي؛ الافتراضي لا يرد منه شيء.
final incomingLinkSourceProvider = Provider<IncomingLinkSource>(
  (ref) => const _NoIncomingLinks(),
);

class _NoIncomingLinks implements IncomingLinkSource {
  const _NoIncomingLinks();
  @override
  Future<String?> initialText() async => null;
  @override
  Stream<String> get texts => const Stream.empty();
}

/// رمز اللغة المحفوظ وقت الإقلاع (null = لا اختيار محفوظ). يُستبدل في main.
final initialLanguageCodeProvider = Provider<String?>((ref) => null);

/// تخزين اللغة. يُستبدل في main بتنفيذ shared_preferences؛ الافتراضي لا يحفظ شيئاً.
final localeStoreProvider = Provider<LocaleStore>((ref) => const _NoLocaleStore());

/// إصدار التطبيق لشاشة الإعدادات. يُستبدل في main.
final appVersionProvider = Provider<String>((ref) => '');

class _NoLocaleStore implements LocaleStore {
  const _NoLocaleStore();
  @override
  Future<String?> load() async => null;
  @override
  Future<void> save(String languageCode) async {}
}

/// الحساب. يُستبدل في main بتنفيذ google_sign_in؛ الافتراضي: غير مسجّل والدخول
/// غير متاح.
final authServiceProvider = Provider<AuthService>((ref) => const _NoAuthService());

/// إقرار الخطر (D10). يُستبدل في main؛ الافتراضي في الذاكرة.
final riskAckStoreProvider = Provider<RiskAckStore>((ref) => _MemoryRiskAckStore());

class _NoAuthService implements AuthService {
  const _NoAuthService();
  @override
  AuthStatus get status => AuthStatus.signedOut;
  @override
  Stream<AuthStatus> get statusChanges => const Stream.empty();
  @override
  Future<void> restore() async {}
  @override
  Future<SignInOutcome> signIn() async => throw const AppFailure(FailureKind.signInUnavailable);
  @override
  Future<String> accessToken() async => throw const AppFailure(FailureKind.notSignedIn);
  @override
  Future<void> invalidateAccessToken(String token) async {}
  @override
  Future<void> signOut() async {}
}

class _MemoryRiskAckStore implements RiskAckStore {
  bool _ack = false;
  @override
  Future<bool> isAcknowledged() async => _ack;
  @override
  Future<void> acknowledge() async => _ack = true;
}

/// YouTube Data API (الميزة 3، D29). يُستبدل في main؛ الافتراضي: كل طلب يحتاج
/// دخولاً والحصة غير مستعملة.
final youTubeApiProvider = Provider<YouTubeApi>((ref) => const _NoYouTubeApi());

class _NoYouTubeApi implements YouTubeApi {
  const _NoYouTubeApi();
  static const _f = AppFailure(FailureKind.notSignedIn);
  @override
  Future<ApiPage<SearchResult>> search(String query, {String? pageToken}) async => throw _f;
  @override
  Future<ApiPage<VideoRef>> channelVideos(String channelId, {String? pageToken, bool refresh = false}) async =>
      throw _f;
  @override
  Future<ApiPage<VideoRef>> subscriptionFeed({bool refresh = false}) async => throw _f;
  @override
  Future<ApiPage<PlaylistSummary>> myPlaylists({String? pageToken, bool refresh = false}) async => throw _f;
  @override
  Future<ApiPage<VideoRef>> playlistVideos(String playlistId, {String? pageToken, bool refresh = false}) async =>
      throw _f;
  @override
  Future<ApiPage<VideoRef>> likedVideos({String? pageToken, bool refresh = false}) async => throw _f;
  @override
  Future<ApiPage<ChannelSummary>> mySubscriptions({String? pageToken, bool refresh = false}) async => throw _f;
  @override
  Future<String?> myChannelTitle() async => throw _f;
  @override
  Future<QuotaUsage> quotaToday() async => const QuotaUsage(
        general: BucketUsage(used: 0, limit: 10000, stopAt: 9500),
        search: BucketUsage(used: 0, limit: 100, stopAt: 100),
      );
}

/// مفضلة في الذاكرة (الافتراضي والاختبارات).
class MemoryFavoritesRepository implements FavoritesRepository {
  MemoryFavoritesRepository([List<VideoRef> initial = const []]) : _items = [...initial];
  final List<VideoRef> _items;
  final _changes = StreamController<void>.broadcast();

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<VideoRef>> watchAll() => _watch(() => List.unmodifiable(_items));
  @override
  Future<List<VideoRef>> list() async => List.unmodifiable(_items);
  @override
  Stream<bool> watchContains(String videoId) => _watch(() => _items.any((r) => r.videoId == videoId));
  @override
  Future<bool> contains(String videoId) async => _items.any((r) => r.videoId == videoId);
  @override
  Future<void> add(VideoRef ref) async {
    final i = _items.indexWhere((r) => r.videoId == ref.videoId);
    if (i >= 0) {
      _items[i] = ref;
    } else {
      _items.insert(0, ref);
    }
    _changes.add(null);
  }

  @override
  Future<void> remove(String videoId) async {
    _items.removeWhere((r) => r.videoId == videoId);
    _changes.add(null);
  }
}

/// سجل في الذاكرة (الافتراضي والاختبارات)، بالقواعد نفسها: صف لكل مقطع وبحد.
class MemoryHistoryRepository implements HistoryRepository {
  MemoryHistoryRepository({List<HistoryEntry> initial = const [], DateTime Function()? now})
      : _items = [...initial],
        _now = now ?? DateTime.now,
        _id = initial.fold(0, (m, e) => e.id > m ? e.id : m);
  final List<HistoryEntry> _items;
  final DateTime Function() _now;
  int _id;
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<List<HistoryEntry>> watchAll() async* {
    yield List.unmodifiable(_items);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_items);
    }
  }

  @override
  Future<List<HistoryEntry>> list() async => List.unmodifiable(_items);

  @override
  Future<void> record(VideoRef ref) async {
    _items.removeWhere((e) => e.ref.videoId == ref.videoId);
    _items.insert(0, HistoryEntry(id: ++_id, ref: ref, playedAt: _now()));
    if (_items.length > HistoryRepository.maxEntries) _items.removeRange(HistoryRepository.maxEntries, _items.length);
    _changes.add(null);
  }

  @override
  Future<void> remove(int id) async {
    _items.removeWhere((e) => e.id == id);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _items.clear();
    _changes.add(null);
  }
}
