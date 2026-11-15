import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// مشغّل الأذان الكامل داخل التطبيق (آيفون): آبل تحدّ صوت الإشعار بـ٣٠ ثانية، فيصل مقطع الأذان في الإشعار،
/// وعند ضغط الإشعار (أو «تجربة» الأذان) يفتح لمحة ويكمل الأذان كاملاً من هذا المشغّل (DECISIONS ٣٧).
abstract class AdhanPlayer {
  /// هل الأذان يُشغَّل الآن (يظهر شريط الإيقاف).
  ValueListenable<bool> get playing;

  /// يبدأ الأذان الكامل من أوله (لا شيء إن كان يعمل).
  Future<void> start();

  /// يوقفه.
  Future<void> stop();

  void dispose();
}

/// لا يفعل شيئاً (أندرويد: الأذان الكامل في الإشعار نفسه، والاختبارات والمنصات الأخرى).
class NoopAdhanPlayer implements AdhanPlayer {
  final _playing = ValueNotifier(false);

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() => _playing.dispose();
}

/// الأذان الكامل `assets/audio/adhan.mp3` (نحو ٣ دقائق) بفئة الجلسة playback: يعمل رغم مفتاح الصامت.
class AudioAdhanPlayer implements AdhanPlayer {
  AudioAdhanPlayer() {
    _complete = _player.onPlayerComplete.listen((_) => _playing.value = false);
    _state = _player.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.stopped || s == PlayerState.completed) _playing.value = false;
    });
  }

  static const asset = 'audio/adhan.mp3';

  final _player = AudioPlayer();
  final _playing = ValueNotifier(false);
  late final StreamSubscription<void> _complete;
  late final StreamSubscription<PlayerState> _state;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  Future<void> start() async {
    if (_playing.value) return;
    _playing.value = true;
    try {
      await _player.setAudioContext(
        AudioContext(iOS: AudioContextIOS(category: AVAudioSessionCategory.playback)),
      );
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('adhan player: $e');
      _playing.value = false;
    }
  }

  @override
  Future<void> stop() async {
    _playing.value = false;
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('adhan player stop: $e');
    }
  }

  @override
  void dispose() {
    _complete.cancel();
    _state.cancel();
    _player.dispose();
    _playing.dispose();
  }
}
