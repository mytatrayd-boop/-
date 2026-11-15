import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../engine/adhan.dart';

/// مشغّل الأذان الكامل داخل التطبيق (آيفون): آبل تحدّ صوت الإشعار بـ٣٠ ثانية، فيصل مقطع الأذان في الإشعار،
/// وعند ضغط الإشعار (أو «تجربة» الأذان) يفتح لمحة ويكمل الأذان كاملاً من هذا المشغّل (DECISIONS ٣٧).
abstract class AdhanPlayer {
  /// هل الأذان يُشغَّل الآن (يظهر شريط الإيقاف).
  ValueListenable<bool> get playing;

  /// يبدأ الأذان الكامل من أوله (لا شيء إن كان يعمل).
  Future<void> start();

  /// يوقفه.
  Future<void> stop();

  /// يُبقي التطبيق حياً في الخلفية بصوت صامت متكرر (UIBackgroundModes: audio)، ويشغّل الأذان الكامل تلقائياً
  /// عند وقت كل حدث في [events]. [onPrepare] يُستدعى قبل الوقت بنحو ٢٠ ثانية ليلغي المستدعي إشعار ذلك الحدث
  /// فلا يتداخل صوته مع الأذان الكامل (التطبيق حيّ فيشغّله بنفسه).
  Future<void> arm(List<AdhanEvent> events, {void Function(AdhanEvent event)? onPrepare});

  /// يوقف الصوت الصامت والمؤقتات (الأذان معطّل، أو الصوت ليس «أذان»).
  Future<void> disarm();

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
  Future<void> arm(List<AdhanEvent> events, {void Function(AdhanEvent event)? onPrepare}) async {}

  @override
  Future<void> disarm() async {}

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

  /// ثانية صمت تتكرر في الخلفية لإبقاء التطبيق حياً بعد خروجه من الشاشة.
  static const silenceAsset = 'audio/silence.wav';

  /// قبل الوقت بهذه المدة يُستدعى onPrepare.
  static const prepareLead = Duration(seconds: 20);

  /// حدث فات وقته بأكثر من هذا يُهمل (لا يُشغَّل الأذان متأخراً جداً).
  static const lateTolerance = Duration(seconds: 90);

  final _player = AudioPlayer();
  final _keeper = AudioPlayer();
  var _keeperOn = false;
  var _events = <AdhanEvent>[];
  void Function(AdhanEvent event)? _onPrepare;
  Timer? _prepareTimer;
  Timer? _playTimer;
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
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: {AVAudioSessionOptions.mixWithOthers}),
        ),
      );
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(AssetSource(asset));
    } catch (e) {
      debugPrint('adhan player: $e');
      _playing.value = false;
    }
  }

  Future<void> _startKeeper() async {
    if (_keeperOn) return;
    try {
      // mixWithOthers: الصوت الصامت لا يقطع موسيقى المستخدم.
      await _keeper.setAudioContext(AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: {AVAudioSessionOptions.mixWithOthers}),
      ));
      await _keeper.setReleaseMode(ReleaseMode.loop);
      await _keeper.play(AssetSource(silenceAsset));
      _keeperOn = true;
    } catch (e) {
      debugPrint('adhan keeper: $e');
    }
  }

  void _scheduleNext() {
    _prepareTimer?.cancel();
    _playTimer?.cancel();
    final now = DateTime.now();
    _events.removeWhere((e) => e.time.isBefore(now.subtract(lateTolerance)));
    if (_events.isEmpty) return;
    final next = _events.first;
    final wait = next.time.difference(now);
    final lead = wait - prepareLead;
    _prepareTimer = Timer(lead.isNegative ? Duration.zero : lead, () => _onPrepare?.call(next));
    _playTimer = Timer(wait.isNegative ? Duration.zero : wait, () async {
      _events.remove(next);
      await start();
      _scheduleNext();
    });
  }

  @override
  Future<void> arm(List<AdhanEvent> events, {void Function(AdhanEvent event)? onPrepare}) async {
    _events = [...events]..sort((a, b) => a.time.compareTo(b.time));
    _onPrepare = onPrepare;
    await _startKeeper();
    _scheduleNext();
  }

  @override
  Future<void> disarm() async {
    _prepareTimer?.cancel();
    _playTimer?.cancel();
    _events = [];
    if (_keeperOn) {
      _keeperOn = false;
      try {
        await _keeper.stop();
      } catch (e) {
        debugPrint('adhan keeper stop: $e');
      }
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
    _prepareTimer?.cancel();
    _playTimer?.cancel();
    _complete.cancel();
    _state.cancel();
    _keeper.dispose();
    _player.dispose();
    _playing.dispose();
  }
}
