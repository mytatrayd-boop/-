// معاينة قبل التصدير: تشغيل الفيديو بشكله النهائي مع الصوت (الظهور والاختفاء، تبدّل الخلفيات،
// التقريب، والقفز فوق الأجزاء المحذوفة). خلفيات الفيديو تظهر بصورتها المصغّرة.
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';

import 'editor.dart';
import 'look.dart';
import 'mixer.dart';
import 'media.dart';
import 'sync.dart';

/// يرسم إطار الفيديو النهائي في لحظة t من الصوت (يُستعمل في معاينة المحرر وفي ملء الشاشة).
class Composer {
  final EditorModel m;
  final Look look;
  final List<Bg> bgs;
  final Map<String, ui.Image> images; // صور الخلفيات المحمّلة
  final List<String> texts; // نصوص m.valid مرمّزة لخط المجمع
  final String? name, basmala;
  final List<String> trs; // ترجمة كل مقطع (فارغة إن لم تُختر ترجمة)
  final bool forceReciter; // إظهار اسم القارئ دائماً (أثناء تحريره)
  final List<int> segSurahs; // سورة كل مقطع (للترويسة)
  final (String?, String?) Function(int surah)? headerOf;
  late final List<Segment> segs = m.valid;
  late final double end = m.trimEnd < m.duration || segs.isEmpty ? m.trimEnd : min(segs.last.end + 0.8, m.duration);
  late final kept = keptRanges(m.trimStart, end, m.cuts);
  late final double outDuration = kept.fold(0.0, (s, k) => s + k.$2 - k.$1);
  late final List<double> points = bgSchedule(bgs.length, outDuration, [
    for (final g in segs) Segment(g.text, outTime(g.start, kept) ?? 0, outTime(g.end, kept) ?? 0)
  ], look);

  Composer(this.m, this.look, this.bgs, this.images, this.texts, this.name, this.basmala, {this.trs = const [], this.forceReciter = false, this.segSurahs = const [], this.headerOf});

  void _bg(Canvas c, int k, double local, double len, double alpha) {
    final b = bgs[k % bgs.length], img = (b.video ? videoFrameAt(b, local) : null) ?? images[b.preview];
    if (img == null) return;
    var sc = max(vw / img.width, vh / img.height);
    if (look.zoom && !b.video) sc *= 1 + 0.08 * (local / max(len, 0.1)).clamp(0, 1);
    final w = img.width * sc, h = img.height * sc;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..filterQuality = FilterQuality.medium;
    if (look.brightness != 0 || look.contrast != 1 || look.saturation != 1) paint.colorFilter = ColorFilter.matrix(_grade(look));
    if (look.blur > 0) paint.imageFilter = ui.ImageFilter.blur(sigmaX: look.blur, sigmaY: look.blur);
    c.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
        Rect.fromLTWH((vw - w) / 2, (vh - h) / 2, w, h), paint);
  }

  void paint(Canvas c, double t) {
    c.drawRect(Offset.zero & const Size(vw, vh), Paint()..color = Colors.black);
    if (bgs.isNotEmpty) {
      final o = outTime(t, kept) ?? 0, pts = points;
      final td = look.transition != 'none' && pts.length > 1 ? min(look.transDur, 1.5) : 0.0;
      var k = 0;
      for (var i = 0; i < pts.length; i++) {
        if (pts[i] <= o) k = i;
      }
      double len(int i) => (i + 1 < pts.length ? pts[i + 1] + td : outDuration) - pts[i];
      final u = td > 0 ? (o - pts[k]) / td : 1.0;
      if (k > 0 && u < 1) {
        _bg(c, k - 1, o - pts[k - 1], len(k - 1), 1);
        _bg(c, k, o - pts[k], len(k), u.clamp(0, 1));
      } else {
        _bg(c, k, o - pts[k], len(k), 1);
      }
    }
    c.drawRect(Offset.zero & const Size(vw, vh), Paint()..color = Colors.black.withValues(alpha: look.dim));
    var hn = name, hb = basmala;
    if (headerOf != null && segSurahs.length == segs.length && segs.isNotEmpty) {
      var k = 0; // المقطع الجاري (أو آخر مقطع بدأ)
      while (k + 1 < segs.length && segs[k + 1].start <= t) {
        k++;
      }
      (hn, hb) = headerOf!(segSurahs[k]);
    }
    c.drawPicture(headerPicture(hn, hb, look));
    for (var i = 0; i < segs.length; i++) {
      final g = segs[i];
      if (t < g.start || t > g.end || m.skipCut(t) != null) continue;
      final f = max(look.textFx == 'none' ? 0.04 : min(look.fade, (g.end - g.start) / 3), 0.04);
      final a = min(1.0, min((t - g.start) / f, (g.end - t) / f));
      c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: a.clamp(0, 1)));
      if (look.textFx == 'slide') c.translate(0, 50 * (1 - ((t - g.start) / f).clamp(0.0, 1.0)));
      c.drawPicture(segmentPicture(texts[i], i < trs.length ? trs[i] : '', look));
      c.restore();
    }
    if (look.reciter.trim().isNotEmpty) {
      final o = outTime(t, kept) ?? 0, d = look.reciterAll ? outDuration : look.reciterSecs, f = min(0.5, d / 3);
      if (forceReciter) {
        c.drawPicture(reciterPicture(look));
      } else if (o <= d) {
        c.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: min(1.0, min(o / f, (d - o) / f)).clamp(0, 1)));
        c.drawPicture(reciterPicture(look));
        c.restore();
      }
    }
  }
}

/// مصفوفة ألوان تقارب مرشح eq في FFmpeg: تشبّع ثم تباين حول الرمادي المتوسط ثم سطوع.
List<double> _grade(Look l) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = l.saturation, c = l.contrast, o = (0.5 - 0.5 * c + l.brightness) * 255;
  final a = (1 - s) * lr, b = (1 - s) * lg, d = (1 - s) * lb;
  return [
    c * (a + s), c * b, c * d, 0, o, //
    c * a, c * (b + s), c * d, 0, o,
    c * a, c * b, c * (d + s), 0, o,
    0, 0, 0, 1, 0,
  ];
}

/// لوحة الإطار بمقاس 9:16.
class FrameView extends StatelessWidget {
  final Composer composer;
  final double t;
  const FrameView(this.composer, this.t, {super.key});
  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FittedBox(child: SizedBox(width: vw, height: vh, child: CustomPaint(painter: _FramePainter(composer, t)))),
        ),
      );
}

class _FramePainter extends CustomPainter {
  final Composer composer;
  final double t;
  _FramePainter(this.composer, this.t);
  @override
  void paint(Canvas c, Size size) => composer.paint(c, t);
  @override
  bool shouldRepaint(covariant _FramePainter old) => true;
}

/// ملء الشاشة: يشغّل من بداية المقطع إلى نهايته بالشكل النهائي، ويقفز فوق الأجزاء المحذوفة.
class PreviewPage extends StatefulWidget {
  final String audio;
  final Composer composer;
  final double start; // وقت البدء بالثواني (موضع المؤشر)
  const PreviewPage({super.key, required this.audio, required this.composer, this.start = 0});
  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> with SingleTickerProviderStateMixin {
  final player = AudioPlayer();
  late final OverlayMixer mixer = OverlayMixer(widget.audio);
  Stopwatch? tailSw; // بعد نهاية المسار الأول يكمل الثاني وحده
  double tail = 0;
  bool _muteOn = false;
  late final Ticker ticker = createTicker((_) => _tick());
  Composer get c => widget.composer;
  double t = 0;
  bool done = false;

  @override
  void initState() {
    super.initState();
    final s = widget.start;
    t = c.kept.any((k) => s >= k.$1 && s < k.$2 - 0.05) ? s : c.kept.first.$1;
    player.setFilePath(widget.audio).then((_) => _play(t)).then((_) => ticker.start());
  }

  Future<void> _play([double? from]) async {
    done = false;
    tail = 0;
    tailSw = null;
    await player.seek(Duration(milliseconds: ((from ?? c.kept.first.$1) * 1000).round()));
    player.play();
  }

  // الطول الكلي: الأطول من المسارين (الصورة والفيديو يمتدان معه)
  double get total => max(c.outDuration, c.m.overlayEnd);
  bool get playing => player.playing || (tailSw?.isRunning ?? false);
  double get disp => (outTime(min(t, c.end), c.kept) ?? (t >= c.end ? c.outDuration : 0)) + tail;

  void _toggle() {
    if (done) {
      _play();
    } else if (playing) {
      player.pause();
      tailSw?.stop();
    } else if (tailSw != null) {
      tailSw!.start();
    } else {
      player.play();
    }
    setState(() {});
  }

  void _tick() {
    if (!mounted) return;
    final now = player.position.inMilliseconds / 1000;
    final sw = tailSw;
    if (sw != null) {
      tail = sw.elapsedMilliseconds / 1000;
      if (c.outDuration + tail >= total) {
        tail = total - c.outDuration;
        tailSw = null;
        done = true;
      }
    }
    mixer.update(c.m.overlays, (outTime(min(now, c.end), c.kept) ?? (now >= c.end ? c.outDuration : 0)) + tail, playing);
    final mute = c.m.isMuted(now);
    if (mute != _muteOn) {
      _muteOn = mute;
      player.setVolume(mute ? 0 : 1);
    }
    final skip = c.m.skipCut(now);
    if (skip != null) player.seek(Duration(milliseconds: (skip * 1000).round()));
    if (now >= c.end && !done && tailSw == null && player.playing) {
      player.pause();
      // المسار الثاني أطول: يكمل وحده والصورة ثابتة على آخر إطار
      if (total > c.outDuration + 0.05) {
        tailSw = Stopwatch()..start();
      } else {
        done = true;
      }
    }
    setState(() => t = min(now, c.end));
  }

  @override
  void dispose() {
    ticker.dispose();
    mixer.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        // عند الرجوع نُرجع الوقت الذي وصلت إليه المعاينة ليتابع الشريط من هناك
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(t);
        },
        child: _scaffold(),
      );

  Widget _scaffold() => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: const Text('معاينة')),
        body: Column(children: [
          Expanded(child: Center(child: FrameView(c, t))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconButton.filled(
                onPressed: _toggle,
                icon: Icon(done ? Icons.replay : playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 12),
              Text('${fmtTime(disp)} / ${fmtTime(total)}',
                  textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white)),
            ]),
          ),
        ]),
      );
}
