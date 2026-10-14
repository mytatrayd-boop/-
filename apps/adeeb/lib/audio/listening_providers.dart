import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../library/library_providers.dart';
import '../reader/reader_providers.dart';
import '../reader/reader_settings.dart';
import 'audio_service_session.dart';
import 'flutter_tts_engine.dart';
import 'listening_player.dart';
import 'tts_engine.dart';

/// محرك النطق؛ يُستبدل بمحاكاة في الاختبارات.
final ttsEngineProvider = Provider<TtsEngine>((ref) => FlutterTtsEngine());

/// جلسة الوسائط (الإشعار وشاشة القفل والتركيز الصوتي)؛ تُستبدل في الاختبارات.
/// تُنشأ مرة واحدة (`AudioService.init` لا يُستدعى مرتين)، فاللغة تُقرأ ولا تُراقب.
final mediaSessionProvider = Provider<MediaSession>((ref) {
  final l10n = lookupAppLocalizations(ref.read(appLocaleProvider));
  return AudioServiceSession(
    channelName: l10n.audioChannelName,
    subtitle: l10n.audioNowPlayingSubtitle,
    controlLabels: (
      previous: l10n.audioPrevious,
      play: l10n.audioPlay,
      pause: l10n.audioPause,
      next: l10n.audioNext,
    ),
  );
});

final listeningPlayerProvider = Provider<ListeningPlayer>((ref) {
  final actions = ref.read(readingActionsProvider);
  final player = ListeningPlayer(
    engine: ref.read(ttsEngineProvider),
    session: ref.read(mediaSessionProvider),
    // كتابة الموضع عبر المستودع (طابور الكتابة المشترك enqueueWrite)، فآخر
    // موضع استماع هو آخر موضع قراءة (SPEC الميزة 5).
    savePosition: actions.savePosition,
  );
  ref.onDispose(player.dispose);
  return player;
});

/// حالة الاستماع الحالية للواجهة.
final listeningStateProvider =
    NotifierProvider<ListeningStateNotifier, ListeningState>(
      ListeningStateNotifier.new,
    );

class ListeningStateNotifier extends Notifier<ListeningState> {
  @override
  ListeningState build() {
    final player = ref.watch(listeningPlayerProvider);
    final sub = player.states.listen((s) {
      if (ref.mounted) state = s;
    });
    ref.onDispose(sub.cancel);
    return player.state;
  }
}

/// طلب من المشغّل الكامل («اذهب إلى النص») للقارئ المفتوح على الكتاب نفسه بأن
/// يعود لتتبّع الفقرة المقروءة بدل فتح قارئ جديد.
final followListeningRequestProvider =
    NotifierProvider<FollowListeningRequest, int>(FollowListeningRequest.new);

class FollowListeningRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

/// الأصوات العربية على الجهاز.
final arabicVoicesProvider = FutureProvider.autoDispose<List<TtsVoice>>(
  (ref) => ref.watch(ttsEngineProvider).arabicVoices(),
);

/// إعدادات الاستماع المحفوظة (ARCHITECTURE §5: shared_preferences).
class AudioSettings {
  const AudioSettings({this.speed = defaultListeningSpeed, this.voiceName});

  final double speed;

  /// اسم الصوت المختار، أو null = أول صوت عربي.
  final String? voiceName;
}

final audioSettingsProvider =
    AsyncNotifierProvider<AudioSettingsController, AudioSettings>(
      AudioSettingsController.new,
    );

class AudioSettingsController extends AsyncNotifier<AudioSettings> {
  static const speedKey = 'audio.speed';
  static const voiceKey = 'audio.voice';
  static const screenReaderWarnedKey = 'audio.screen_reader_warned';

  @override
  Future<AudioSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final speed = prefs.getDouble(speedKey);
    return AudioSettings(
      speed: listeningSpeeds.contains(speed) ? speed! : defaultListeningSpeed,
      voiceName: prefs.getString(voiceKey),
    );
  }

  AudioSettings get _current => state.value ?? const AudioSettings();

  Future<void> setSpeed(double speed) async {
    state = AsyncData(
      AudioSettings(speed: speed, voiceName: _current.voiceName),
    );
    final player = ref.read(listeningPlayerProvider);
    if (player.state.active) await player.setSpeed(speed);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setDouble(speedKey, speed);
  }

  Future<void> setVoice(TtsVoice voice) async {
    state = AsyncData(
      AudioSettings(speed: _current.speed, voiceName: voice.name),
    );
    final player = ref.read(listeningPlayerProvider);
    if (player.state.active) await player.setVoice(voice);
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(voiceKey, voice.name);
  }

  /// true مرة واحدة فقط: تنبيه تداخل الصوت مع قارئ الشاشة (DESIGN §10.5).
  Future<bool> takeScreenReaderWarning() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (prefs.getBool(screenReaderWarnedKey) ?? false) return false;
    await prefs.setBool(screenReaderWarnedKey, true);
    return true;
  }
}
