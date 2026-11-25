import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ports/incoming_link_source.dart';
import '../domain/ports/locale_store.dart';
import '../domain/ports/playback_controller.dart';

/// يُستبدل عند الإقلاع (main) بالمعالج الحقيقي، وفي الاختبارات بتنفيذ وهمي.
final playbackControllerProvider = Provider<PlaybackController>(
  (ref) => throw UnimplementedError('playbackControllerProvider must be overridden'),
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
