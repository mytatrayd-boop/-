import 'dart:async';

import 'package:adeeb/audio/tts_engine.dart';

const voiceEg1 = TtsVoice(name: 'ar-eg-1', locale: 'ar-EG');
const voiceEg2 = TtsVoice(name: 'ar-eg-2', locale: 'ar-EG');
const voiceSa = TtsVoice(name: 'ar-sa-1', locale: 'ar-SA');

/// محرك نطق مُحاكى: كل [speak] يبقى معلّقاً حتى [finish] أو [stop].
class FakeTtsEngine implements TtsEngine {
  List<TtsVoice> voices = [voiceEg1, voiceEg2, voiceSa];
  final spoken = <String>[];
  final configured = <({TtsVoice? voice, double speed})>[];
  Completer<SpeakResult>? _current;
  int stops = 0;
  int settingsOpened = 0;
  int storeOpened = 0;
  bool storeResult = true;
  bool settingsResult = false;
  bool failConfigure = false;

  bool get speaking => _current != null;

  String? get currentText => speaking ? spoken.last : null;

  @override
  Future<List<TtsVoice>> arabicVoices() async => List.of(voices);

  @override
  Future<void> configure({TtsVoice? voice, required double speed}) async {
    if (failConfigure) throw StateError('محاكاة فشل المحرك');
    configured.add((voice: voice, speed: speed));
  }

  @override
  Future<SpeakResult> speak(String text) {
    spoken.add(text);
    final c = Completer<SpeakResult>();
    _current = c;
    return c.future;
  }

  /// ينهي المقطع الجاري بـ [result].
  void finish([SpeakResult result = SpeakResult.done]) {
    final c = _current;
    _current = null;
    c?.complete(result);
  }

  @override
  Future<void> stop() async {
    stops++;
    final c = _current;
    _current = null;
    c?.complete(SpeakResult.cancelled);
  }

  @override
  Future<bool> openInstallSettings() async {
    settingsOpened++;
    return settingsResult;
  }

  @override
  Future<bool> openVoiceStore() async {
    storeOpened++;
    return storeResult;
  }
}

/// جلسة وسائط مُحاكاة: تسجّل التحديثات وترسل أوامر كأنها من الإشعار.
class FakeMediaSession implements MediaSession {
  final updates = <MediaSessionState>[];
  int activations = 0;
  int deactivations = 0;
  bool failActivate = false;
  bool active = false;
  final _commands = StreamController<MediaCommand>.broadcast();

  MediaSessionState? get last => updates.isEmpty ? null : updates.last;

  void send(MediaCommand command) => _commands.add(command);

  @override
  Stream<MediaCommand> get commands => _commands.stream;

  /// قيمة طلب التركيز الصوتي (false = مرفوض، مثلاً مكالمة جارية).
  bool grantFocus = true;

  /// إن وُضع: activate ينتظره (لمحاكاة بطء بدء الخدمة).
  Completer<void>? activateGate;

  @override
  Future<bool> activate() async {
    if (failActivate) throw StateError('محاكاة فشل الخدمة');
    activations++;
    await activateGate?.future;
    active = true;
    return grantFocus;
  }

  @override
  void update(MediaSessionState state) => updates.add(state);

  @override
  Future<void> deactivate() async {
    deactivations++;
    active = false;
  }
}
