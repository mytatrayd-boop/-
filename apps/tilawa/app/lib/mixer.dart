// تشغيل المسار الثاني مع الأول: لكل قطعة صوت مشغّل خاص بها على نفس ملف الصوت،
// يبدأ حين يدخل المؤشر نطاقها، ويتزامن مع زمن العرض (وتُراعى الأجزاء المحذوفة).
import 'package:just_audio/just_audio.dart';

import 'sync.dart';

class _Slot {
  final p = AudioPlayer();
  bool ready = false, on = false;
  double vol = -1;
}

class OverlayMixer {
  final String path;
  final double Function(double srcTime) toDisp; // وقت الملف ← وقت العرض
  final _slots = <AudioLayer, _Slot>{};
  OverlayMixer(this.path, this.toDisp);

  /// يُنادى كل إطار: srcT وقت المسار الأول في الملف، وplaying هل التشغيل جارٍ.
  void update(List<AudioLayer> layers, double srcT, bool playing) {
    _slots.removeWhere((o, s) {
      if (layers.contains(o)) return false;
      s.p.dispose();
      return true;
    });
    final d = toDisp(srcT);
    for (final o in layers) {
      final s = _slots.putIfAbsent(o, () {
        final n = _Slot();
        n.p.setFilePath(path).then((_) => n.ready = true);
        return n;
      });
      if (!s.ready) continue;
      if (s.vol != o.vol) {
        s.vol = o.vol;
        s.p.setVolume(o.vol.clamp(0.0, 1.0));
      }
      final want = o.src0 + (d - o.at);
      if (playing && d >= o.at && d < o.at + o.len) {
        if (!s.on) {
          s.p.seek(Duration(milliseconds: (want * 1000).round()));
          s.p.play();
          s.on = true;
        } else if ((s.p.position.inMilliseconds / 1000 - want).abs() > 0.3) {
          s.p.seek(Duration(milliseconds: (want * 1000).round()));
        }
      } else if (s.on) {
        s.p.pause();
        s.on = false;
      }
    }
  }

  void dispose() {
    for (final s in _slots.values) {
      s.p.dispose();
    }
    _slots.clear();
  }
}
