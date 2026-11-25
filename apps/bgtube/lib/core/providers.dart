import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ports/incoming_link_source.dart';
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
