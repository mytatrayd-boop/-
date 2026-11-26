import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../domain/ports/alternate_source_resolver.dart';
import '../domain/ports/audio_source_resolver.dart';
import '../domain/ports/play_history.dart';
import '../domain/ports/position_repository.dart';
import '../domain/ports/queue_repository.dart';
import '../domain/ports/speed_store.dart';
import 'bgtube_audio_handler.dart';
import 'playback_diagnostics.dart';

/// يهيّئ جلسة الصوت (مقاطعات المكالمات) وخدمة الخلفية.
Future<BgtubeAudioHandler> initAudioHandler(
  AudioSourceResolver resolver, {
  PositionRepository? positions,
  SpeedStore? speedStore,
  QueueRepository? queueRepository,
  PlayHistoryRecorder? history,
}) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  return AudioService.init(
    builder: () => BgtubeAudioHandler(
      resolver: resolver,
      positions: positions,
      speedStore: speedStore,
      queueRepo: queueRepository,
      history: history,
      saveInterval: defaultSaveInterval, // ٣ ث (±٣ ث في SPEC)
      probe: httpStreamProbe,
      // تبديل العميل أثناء التشغيل (D24): المستخرج نفسه إن دعمه.
      alternates: resolver is AlternateSourceResolver ? resolver as AlternateSourceResolver : null,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.bgtube.bgtube.playback',
      androidNotificationChannelName: 'BGTube',
      androidNotificationOngoing: false,
    ),
  );
}
