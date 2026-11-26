import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_failure.dart';
import '../domain/ports/auth_service.dart';
import '../domain/ports/incoming_link_source.dart';
import '../domain/ports/local_playlist_repository.dart';
import '../domain/ports/locale_store.dart';
import '../domain/ports/playback_controller.dart';
import '../domain/ports/playback_queue.dart';
import '../domain/ports/risk_ack_store.dart';

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
