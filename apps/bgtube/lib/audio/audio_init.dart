import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import '../domain/ports/audio_source_resolver.dart';
import 'bgtube_audio_handler.dart';

/// يهيّئ جلسة الصوت (مقاطعات المكالمات) وخدمة الخلفية.
Future<BgtubeAudioHandler> initAudioHandler(AudioSourceResolver resolver) async {
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  return AudioService.init(
    builder: () => BgtubeAudioHandler(resolver: resolver),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.bgtube.bgtube.playback',
      androidNotificationChannelName: 'BGTube',
      androidNotificationOngoing: false,
    ),
  );
}
