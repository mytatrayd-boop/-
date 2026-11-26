import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../domain/ports/audio_source_resolver.dart';
import '../domain/ports/position_repository.dart';
import '../domain/ports/speed_store.dart';
import 'bgtube_audio_handler.dart';
import 'playback_diagnostics.dart';

/// يهيّئ جلسة الصوت (مقاطعات المكالمات) وخدمة الخلفية.
Future<BgtubeAudioHandler> initAudioHandler(
  AudioSourceResolver resolver, {
  PositionRepository? positions,
  SpeedStore? speedStore,
}) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  return AudioService.init(
    builder: () => BgtubeAudioHandler(
      resolver: resolver,
      positions: positions,
      speedStore: speedStore,
      probe: httpStreamProbe,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.bgtube.bgtube.playback',
      androidNotificationChannelName: 'BGTube',
      androidNotificationOngoing: false,
    ),
  );
}
