import 'package:flutter/foundation.dart';

import '../../core/app_failure.dart';
import '../models/now_playing.dart';

/// ما تحتاجه الواجهة من التشغيل (ينفّذه معالج الصوت).
abstract interface class PlaybackController {
  ValueListenable<AppFailure?> get failure;
  ValueListenable<bool> get resolving;
  ValueListenable<bool> get playing;
  ValueListenable<NowPlaying?> get nowPlaying;
  Stream<Duration> get positionStream;

  /// السرعة الحالية (تبقى للفيديو التالي).
  ValueListenable<double> get speed;

  Future<void> playVideo(String videoId);
  Future<void> retry();
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
}
