import 'dart:typed_data';

import 'dual_compositor.dart';
import 'rgba_frame.dart';
import 'synthetic_audio.dart';
import 'synthetic_camera.dart';

/// خط الدمج على ساعة افتراضية حتمية: لكل إطار كاميرا i عند i/fps يُستخدم آخر
/// إطار خريطة طابعه الزمني <= وقت الإطار (يُكرَّر حتى يصل الجديد).
class DualPipeline {
  DualPipeline({
    required this.camera,
    required this.compositor,
    this.audio = const SyntheticAudioSource(),
  });

  final SyntheticCameraSource camera;
  final DualCompositor compositor;
  final SyntheticAudioSource audio;

  /// يولّد الإطارات المركّبة لمدة [duration]. [mapFrames] مرتّبة بالزمن.
  Iterable<RgbaFrame> run(Duration duration, List<RgbaFrame> mapFrames) sync* {
    final total = duration.inMicroseconds * camera.fps ~/ 1000000;
    var next = 0;
    for (var i = 0; i < total; i++) {
      final t = Duration(microseconds: i * 1000000 ~/ camera.fps);
      RgbaFrame? fresh;
      while (next < mapFrames.length && mapFrames[next].timestamp <= t) {
        fresh = mapFrames[next++];
      }
      yield compositor.compose(camera.frame(i), map: fresh, timestamp: t);
    }
  }

  Int16List audioFor(Duration duration) => audio.samples(duration);
}
