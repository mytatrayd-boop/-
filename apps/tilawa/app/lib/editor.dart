// المحرر على طريقة CapCut: المؤشر ثابت في منتصف الخط الزمني والصفوف تتحرك تحته؛
// صف صور الفيديو، وصف النص (المقاطع)، وصف الصوت (قطع تُقسم وتُحذف ويُغلق مكانها). مع تراجع وإعادة.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'media.dart';
import 'quran.dart';
import 'sync.dart';

class EditorModel extends ChangeNotifier {
  List<Segment> segs = [];
  double duration = 0, trimStart = 0, trimEnd = 0, playhead = 0;
  List<(double, double)> cuts = []; // أجزاء محذوفة من الصوت (بوقت الملف)
  List<double> splits = []; // مواضع تقسيم الصوت إلى قطع
  int? selected; // مقطع النص المحدد
  (double, double)? audioSel; // قطعة الصوت المحددة
  Float32List peaks = Float32List(0); // أعلى قيمة لكل 10 ملي ثانية
  double pps = 60; // بكسل لكل ثانية
  final List<String> _undo = [], _redo = [];

  void setAudio(Float32List a16) {
    duration = a16.length / sr;
    trimStart = 0;
    trimEnd = duration;
    playhead = 0;
    cuts = [];
    splits = [];
    selected = null;
    audioSel = null;
    final n = a16.length ~/ 160;
    peaks = Float32List(n);
    for (var i = 0; i < n; i++) {
      var m = 0.0;
      for (var j = i * 160; j < (i + 1) * 160; j++) {
        m = max(m, a16[j].abs());
      }
      peaks[i] = m;
    }
    final top = peaks.isEmpty ? 1.0 : max(peaks.reduce(max), 1e-4);
    for (var i = 0; i < n; i++) {
      peaks[i] /= top;
    }
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }

  // ── التراجع والإعادة ──
  String _snap() => jsonEncode({
        's': segs.map((g) => g.toJson()).toList(),
        'c': [for (final (x, y) in cuts) [x, y]],
        'p': splits,
      });
  void _restore(String j0) {
    final j = jsonDecode(j0) as Map<String, dynamic>;
    segs = [for (final g in j['s'] as List) Segment.fromJson(g as Map<String, dynamic>)];
    cuts = [for (final c in j['c'] as List) ((c[0] as num).toDouble(), (c[1] as num).toDouble())];
    splits = [for (final p in j['p'] as List) (p as num).toDouble()];
    selected = null;
    audioSel = null;
    notifyListeners();
  }

  void checkpoint() {
    _undo.add(_snap());
    _redo.clear();
    if (_undo.length > 80) _undo.removeAt(0);
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snap());
    _restore(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snap());
    _restore(_redo.removeLast());
  }

  void setSegments(List<Segment> s) {
    checkpoint();
    segs = s;
    selected = null;
    notifyListeners();
  }

  void changed() => notifyListeners();
  void select(int? i) {
    selected = i;
    audioSel = null;
    notifyListeners();
  }

  void seek(double t) {
    playhead = t.clamp(0, duration);
    notifyListeners();
  }

  // ── وقت العرض: الأجزاء المحذوفة تُطوى فيُغلق مكانها ──
  List<(double, double)> get kept => keptRanges(0, duration, cuts);
  double get dispDuration => kept.fold(0.0, (s, k) => s + k.$2 - k.$1);
  double toDisp(double t) {
    var acc = 0.0;
    for (final (a, b) in kept) {
      if (t < a) return acc;
      if (t <= b) return acc + t - a;
      acc += b - a;
    }
    return acc;
  }

  double toSrc(double d) {
    var acc = 0.0;
    final k = kept;
    for (final (a, b) in k) {
      if (d <= acc + b - a) return a + max(0.0, d - acc);
      acc += b - a;
    }
    return k.isEmpty ? 0 : k.last.$2;
  }

  /// قطع الصوت الظاهرة (بوقت الملف): الأجزاء الباقية مقسومة عند مواضع التقسيم.
  List<(double, double)> get audioClips {
    final out = <(double, double)>[];
    for (final (a, b) in kept) {
      var s = a;
      for (final p in splits.where((p) => p > a + 0.05 && p < b - 0.05).toList()..sort()) {
        out.add((s, p));
        s = p;
      }
      out.add((s, b));
    }
    return out;
  }

  /// إن وقع t داخل جزء محذوف يرجع نهايته (للتشغيل الذي يقفز فوقه).
  double? skipCut(double t) {
    for (final (a, b) in cuts) {
      if (t >= a && t < b) return b;
    }
    return null;
  }

  Segment? get sel => selected == null ? null : segs[selected!];
  void _sort() {
    final s = sel;
    segs.sort((a, b) => a.start.compareTo(b.start));
    if (s != null) selected = segs.indexOf(s);
  }

  // ── أدوات مقطع النص المحدد ──
  void setStartHere() {
    final g = sel;
    if (g == null || playhead >= g.end - 0.2) return;
    checkpoint();
    g.start = playhead;
    _sort();
    notifyListeners();
  }

  void setEndHere() {
    final g = sel;
    if (g == null || playhead <= g.start + 0.2) return;
    checkpoint();
    g.end = playhead;
    notifyListeners();
  }

  /// يقسم المقطع: الجزء الثاني يبدأ بالكلمة رقم k ومن موضع المؤشر (أو منتصف المقطع إن كان المؤشر خارجه).
  void splitAt(int k) {
    final g = sel;
    if (g == null) return;
    final words = g.text.split(' ');
    if (k <= 0 || k >= words.length) return;
    checkpoint();
    final t = playhead > g.start + 0.3 && playhead < g.end - 0.3 ? playhead : (g.start + g.end) / 2;
    final second = Segment(words.sublist(k).join(' '), t, g.end);
    g.text = words.sublist(0, k).join(' ');
    g.end = t - 0.1;
    segs.insert(selected! + 1, second);
    notifyListeners();
  }

  void mergeNext() {
    final i = selected;
    if (i == null || i + 1 >= segs.length) return;
    checkpoint();
    segs[i].text = '${segs[i].text} ${segs[i + 1].text}';
    segs[i].end = segs[i + 1].end;
    segs.removeAt(i + 1);
    notifyListeners();
  }

  void duplicate() {
    final i = selected;
    if (i == null) return;
    checkpoint();
    final g = segs[i], d = g.end - g.start;
    final nextStart = i + 1 < segs.length ? segs[i + 1].start : duration;
    final c = Segment(g.text, g.end + 0.15, min(g.end + 0.15 + d, max(nextStart - 0.15, g.end + 1.2)));
    segs.insert(i + 1, c);
    selected = i + 1;
    notifyListeners();
  }

  void deleteSeg() {
    final i = selected;
    if (i == null) return;
    checkpoint();
    segs.removeAt(i);
    selected = null;
    notifyListeners();
  }

  void addAt(String text) {
    checkpoint();
    final next = segs.where((g) => g.start > playhead).map((g) => g.start).fold(duration, min);
    final g = Segment(text, playhead, min(playhead + 4, max(next - 0.15, playhead + 1)));
    segs.add(g);
    segs.sort((a, b) => a.start.compareTo(b.start));
    selected = segs.indexOf(g);
    audioSel = null;
    notifyListeners();
  }

  // ── أدوات الصوت ──
  void selectAudioAt(double t) {
    selected = null;
    audioSel = audioClips.where((c) => t >= c.$1 && t <= c.$2).firstOrNull;
    notifyListeners();
  }

  void splitAudio() {
    if (playhead <= 0.1 || playhead >= duration - 0.1 || skipCut(playhead) != null) return;
    checkpoint();
    splits = [...splits, playhead];
    audioSel = audioClips.where((c) => playhead >= c.$1 && playhead <= c.$2).firstOrNull;
    notifyListeners();
  }

  /// يحذف قطعة الصوت المحددة ونص المقاطع التي داخلها، ويقص المقاطع التي تتقاطع معها.
  void deleteAudio() {
    final s = audioSel;
    if (s == null) return;
    final (a, b) = s;
    checkpoint();
    cuts = [...cuts, (a, b)];
    segs = [
      for (final g in segs)
        if (!(g.start >= a - 0.05 && g.end <= b + 0.05))
          g.end > a && g.end <= b ? (g..end = a) : g.start >= a && g.start < b ? (g..start = b) : g
    ];
    audioSel = null;
    selected = null;
    if (skipCut(playhead) != null) playhead = skipCut(playhead)!.clamp(0, duration);
    notifyListeners();
  }

  void restoreAudio() {
    if (cuts.isEmpty) return;
    checkpoint();
    cuts = [];
    notifyListeners();
  }

  // ── المزامنة بالنقر: كل نقرة تنهي المقطع الحالي وتبدأ التالي ──
  int? tapIndex;
  void tapStart() {
    checkpoint();
    final i = segs.indexWhere((g) => g.end > playhead);
    tapIndex = i < 0 ? null : i;
    notifyListeners();
  }

  void tap(double t) {
    final i = tapIndex;
    if (i == null || i >= segs.length) return;
    if (i > 0) segs[i - 1].end = max(segs[i - 1].start + 0.2, t - 0.15);
    final d = segs[i].end - segs[i].start;
    segs[i].start = t;
    segs[i].end = max(segs[i].end, t + min(d, 3));
    selected = i;
    tapIndex = i + 1;
    notifyListeners();
  }

  void tapStop(double t) {
    final i = tapIndex;
    if (i != null && i > 0 && i - 1 < segs.length) segs[i - 1].end = max(segs[i - 1].start + 0.2, t);
    tapIndex = null;
    notifyListeners();
  }

  List<Segment> get valid =>
      segs.where((g) => g.text.trim().isNotEmpty && g.end > g.start).toList()..sort((a, b) => a.start.compareTo(b.start));
}

// ── الخط الزمني ──
const _rulerH = 22.0, _filmTop = 26.0, _filmH = 64.0, _segTop = 96.0, _segH = 40.0, _waveTop = 142.0, _waveH = 40.0;
const tlHeight = 188.0;

class Timeline extends StatefulWidget {
  final EditorModel m;
  final ui.Image? Function(double t)? thumb; // صورة مصغّرة من الفيديو النهائي عند t (وقت الملف)
  final VoidCallback? onScrub; // بدأ المستخدم بسحب الخط الزمني (يوقف التشغيل)
  const Timeline(this.m, {super.key, this.thumb, this.onScrub});
  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  String _mode = '';
  double _x0 = 0, _ph0 = 0, _pps0 = 0, _a0 = 0, _b0 = 0, _w = 1;
  bool _moved = false;

  EditorModel get m => widget.m;
  // المؤشر في منتصف العرض: x = w/2 + (disp(t) - disp(playhead)) * pps
  double t2x(double t) => _w / 2 + (m.toDisp(t) - m.toDisp(m.playhead)) * m.pps;
  double x2t(double x) => m.toSrc(m.toDisp(m.playhead) + (x - _w / 2) / m.pps);

  int? _segAt(double x) {
    final t = x2t(x);
    for (var i = 0; i < m.segs.length; i++) {
      if (t >= m.segs[i].start && t <= m.segs[i].end) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      _w = box.maxWidth;
      return GestureDetector(
        onTapUp: (d) {
          final p = d.localPosition;
          if (p.dy >= _segTop && p.dy < _segTop + _segH) {
            m.select(_segAt(p.dx));
          } else if (p.dy >= _waveTop) {
            m.selectAudioAt(x2t(p.dx));
          } else {
            m.select(null);
          }
        },
        onScaleStart: (d) {
          final p = d.localFocalPoint;
          _x0 = p.dx;
          _ph0 = m.toDisp(m.playhead);
          _pps0 = m.pps;
          _moved = false;
          _mode = 'scrub';
          final g = m.sel;
          if (d.pointerCount == 1 && g != null && p.dy >= _segTop && p.dy < _segTop + _segH) {
            final xs = t2x(g.start), xe = t2x(g.end);
            if ((p.dx - xs).abs() < 20) {
              _mode = 'start';
            } else if ((p.dx - xe).abs() < 20) {
              _mode = 'end';
            }
            _a0 = g.start;
            _b0 = g.end;
          }
        },
        onScaleUpdate: (d) {
          if (d.pointerCount >= 2) {
            m.pps = (_pps0 * d.horizontalScale).clamp(8.0, 400.0);
            m.changed();
            return;
          }
          final dx = d.localFocalPoint.dx - _x0, dt = dx / m.pps;
          if (!_moved && dx.abs() > 3) {
            _moved = true;
            widget.onScrub?.call();
            if (_mode != 'scrub') m.checkpoint();
          }
          if (!_moved) return;
          final g = m.sel, i = m.selected;
          if (_mode == 'scrub' || g == null || i == null) {
            // سحب الخط الزمني يحرّك الوقت تحت المؤشر الثابت
            m.playhead = m.toSrc((_ph0 - dt).clamp(0, m.dispDuration));
          } else {
            final lo = i > 0 ? m.segs[i - 1].end + 0.05 : 0.0;
            final hi = i + 1 < m.segs.length ? m.segs[i + 1].start - 0.05 : m.duration;
            if (_mode == 'start') {
              g.start = (_a0 + dt).clamp(lo, g.end - 0.2);
            } else {
              g.end = (_b0 + dt).clamp(g.start + 0.2, hi);
            }
          }
          m.changed();
        },
        child: CustomPaint(size: Size(_w, tlHeight), painter: _TimelinePainter(this)),
      );
    });
  }
}

class _TimelinePainter extends CustomPainter {
  final _TimelineState s;
  _TimelinePainter(this.s) : super(repaint: s.m);

  @override
  void paint(Canvas c, Size size) {
    final m = s.m, w = size.width;
    final p0 = m.toDisp(m.playhead);
    double dx(double d) => w / 2 + (d - p0) * m.pps; // وقت العرض ← x
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF161616));
    final dd = m.dispDuration;
    // المسطرة بوقت العرض
    final step = m.pps > 120 ? 1 : m.pps > 40 ? 2 : m.pps > 15 ? 5 : 15;
    final label = TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55));
    for (var t = max(0, ((p0 - w / 2 / m.pps) / step).floor() * step); t <= p0 + w / 2 / m.pps && t <= dd; t += step) {
      final px = dx(t.toDouble());
      final tp = TextPainter(text: TextSpan(text: '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}', style: label),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(c, Offset(px - tp.width / 2, 3));
      c.drawCircle(Offset(px + step * m.pps / 2, 11), 1.5, Paint()..color = Colors.white24);
    }
    // صور الفيديو: خانة كل عرض صورة
    const tileW = _filmH * 9 / 16;
    final first = max(0, ((p0 - w / 2 / m.pps) * m.pps / tileW).floor());
    for (var k = first; k * tileW / m.pps < dd && dx(k * tileW / m.pps) < w; k++) {
      final d0 = k * tileW / m.pps;
      final dst = Rect.fromLTWH(dx(d0), _filmTop, min(tileW, (dd - d0) * m.pps) + 0.5, _filmH);
      final img = s.widget.thumb?.call(m.toSrc(d0 + tileW / m.pps / 2));
      if (img != null) {
        c.save();
        c.clipRect(dst);
        c.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()),
            Rect.fromLTWH(dst.left, dst.top, tileW, _filmH), Paint()..filterQuality = FilterQuality.low);
        c.restore();
      } else {
        c.drawRect(dst.deflate(0.5), Paint()..color = const Color(0xFF2A2A2A));
      }
    }
    final filmR = RRect.fromRectAndRadius(Rect.fromLTRB(dx(0), _filmTop, dx(dd), _filmTop + _filmH), const Radius.circular(4));
    c.drawRRect(filmR, Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white24);
    // صف النص
    for (var i = 0; i < m.segs.length; i++) {
      final g = m.segs[i];
      final l = dx(m.toDisp(g.start)), r = dx(m.toDisp(g.end));
      if (r < 0 || l > w || r - l < 1) continue;
      final selected = i == m.selected;
      final rect = RRect.fromRectAndRadius(Rect.fromLTRB(l + 1, _segTop, r - 1, _segTop + _segH), const Radius.circular(5));
      c.drawRRect(rect, Paint()..color = selected ? const Color(0xFFE8B931) : const Color(0xFF7A5BD6));
      if (selected) {
        final h = Paint()..color = Colors.white;
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(l + 1, _segTop, 10, _segH), const Radius.circular(4)), h);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r - 11, _segTop, 10, _segH), const Radius.circular(4)), h);
      }
      if (r - l > 28) {
        c.save();
        c.clipRect(Rect.fromLTRB(l + 12, _segTop, r - 12, _segTop + _segH));
        final tp = TextPainter(
            text: TextSpan(text: 'T  ${g.text.replaceAll(marks, '')}', style: TextStyle(fontSize: 12.5, color: selected ? Colors.black : Colors.white)),
            textDirection: TextDirection.rtl,
            maxLines: 1)
          ..layout(maxWidth: max(10, r - l - 24));
        tp.paint(c, Offset(r - 12 - tp.width, _segTop + (_segH - tp.height) / 2));
        c.restore();
      }
    }
    // صف الصوت: قطع بموجتها
    for (final (a, b) in m.audioClips) {
      final l = dx(m.toDisp(a)), r = dx(m.toDisp(b));
      if (r < 0 || l > w) continue;
      final selected = m.audioSel != null && (m.audioSel!.$1 - a).abs() < 1e-6 && (m.audioSel!.$2 - b).abs() < 1e-6;
      final rect = RRect.fromRectAndRadius(Rect.fromLTRB(l + 1, _waveTop, r - 1, _waveTop + _waveH), const Radius.circular(5));
      c.drawRRect(rect, Paint()..color = selected ? const Color(0xFF1E6E8C) : const Color(0xFF15434F));
      final wave = Paint()..color = const Color(0xFF5FD3F3).withValues(alpha: selected ? 0.95 : 0.7);
      final mid = _waveTop + _waveH / 2;
      for (var px = max(l + 2, 0.0); px < min(r - 2, w); px += 2) {
        final t = m.toSrc(p0 + (px - w / 2) / m.pps);
        final i0 = (t * 100).floor(), i1 = ((t + 2 / m.pps) * 100).ceil();
        var v = 0.0;
        for (var i = max(0, i0); i < min(m.peaks.length, i1); i++) {
          v = max(v, m.peaks[i]);
        }
        c.drawRect(Rect.fromLTWH(px, mid - v * (_waveH - 8) / 2, 1.4, max(1, v * (_waveH - 8))), wave);
      }
      if (selected) {
        c.drawRRect(rect, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white);
      }
    }
    // المؤشر الثابت في المنتصف
    c.drawLine(Offset(w / 2, _rulerH), Offset(w / 2, size.height), Paint()
      ..color = Colors.white
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}

String fmtTime(double t) => '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).floor().toString().padLeft(2, '0')}';

/// كلمات المقطع بلا رقم الآية (لاختيار موضع التقسيم).
List<String> splitWords(String text) => text.split(' ').where((w) => w.isNotEmpty && !isNum(w)).toList();
