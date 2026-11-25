import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ports/playback_controller.dart';

/// يُستبدل عند الإقلاع (main) بالمعالج الحقيقي، وفي الاختبارات بتنفيذ وهمي.
final playbackControllerProvider = Provider<PlaybackController>(
  (ref) => throw UnimplementedError('playbackControllerProvider must be overridden'),
);
