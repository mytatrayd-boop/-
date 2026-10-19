// المحرر: حالة المقاطع والقص والمؤشر مع التراجع، والخط الزمني (موجة الصوت والمقاطع) بالسحب والتكبير.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'quran.dart';
import 'sync.dart';

class EditorModel extends ChangeNotifier {
  List<Segment> segs = [];
  double duration = 0, trimStart = 0, trimEnd = 0, playhead = 0;
  List<(double, double)> cuts = []; // أجزاء محذوفة من وسط الصوت
  double? selA, selB; // التظليل
  int? selected;
  Float32List peaks = Float32List(0); // أعلى قيمة لكل 10 ملي ثانية
  double pps = 60, view = 0; // بكسل لكل ثانية، وبداية النافذة بالثواني
  final List<String> _undo = [];

  void setAudio(Float32List a16) {
    duration = a16.length / sr;
    trimStart = 0;
    trimEnd = duration;
    playhead = 0;
    view = 0;
    cuts = [];
    selA = selB = null;
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
    notifyListeners();
  }

  String _snap() => jsonEncode({
        's': segs.map((g) => g.toJson()).toList(),
        'a': trimStart,
        'b': trimEnd,
        'c': [for (final (x, y) in cuts) [x, y]],
      });
  void checkpoint() {
    _undo.add(_snap());
    if (_undo.length > 60) _undo.removeAt(0);
  }

  bool get canUndo => _undo.isNotEmpty;
  void undo() {
    if (_undo.isEmpty) return;
    final j = jsonDecode(_undo.removeLast()) as Map<String, dynamic>;
    segs = [for (final g in j['s'] as List) Segment.fromJson(g as Map<String, dynamic>)];
    trimStart = (j['a'] as num).toDouble();
    trimEnd = (j['b'] as num).toDouble();
    cuts = [for (final c in j['c'] as List) ((c[0] as num).toDouble(), (c[1] as num).toDouble())];
    if (selected != null && selected! >= segs.length) selected = null;
    notifyListeners();
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
    notifyListeners();
  }

  void seek(double t) {
    playhead = t.clamp(0, duration);
    notifyListeners();
  }

  Segment? get sel => selected == null ? null : segs[selected!];
  void _sort() {
    final s = sel;
    segs.sort((a, b) => a.start.compareTo(b.start));
    if (s != null) selected = segs.indexOf(s);
  }

  // ── عمليات المقطع المحدد ──
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

  void delete() {
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
    selected = null;
    segs.sort((a, b) => a.start.compareTo(b.start));
    selected = segs.indexOf(g);
    notifyListeners();
  }

  void trimBefore() {
    if (playhead >= trimEnd - 1) return;
    checkpoint();
    trimStart = playhead;
    notifyListeners();
  }

  void trimAfter() {
    if (playhead <= trimStart + 1) return;
    checkpoint();
    trimEnd = playhead;
    notifyListeners();
  }

  void resetTrim() {
    checkpoint();
    trimStart = 0;
    trimEnd = duration;
    cuts = [];
    notifyListeners();
  }

  // ── التظليل وحذف المظلل ──
  void markA() {
    selA = playhead;
    if (selB != null && selB! <= selA!) selB = null;
    notifyListeners();
  }

  void markB() {
    selB = playhead;
    if (selA != null && selA! >= selB!) selA = null;
    notifyListeners();
  }

  void clearSel() {
    selA = selB = null;
    notifyListeners();
  }

  /// يحذف الجزء المظلل من الصوت، والمقاطع التي داخله كلها، ويقص المقاطع التي تتقاطع معه.
  void deleteSel() {
    final a = selA, b = selB;
    if (a == null || b == null || b - a < 0.1) return;
    checkpoint();
    cuts = [...cuts, (a, b)];
    segs = [
      for (final g in segs)
        if (!(g.start >= a && g.end <= b))
          g.end > a && g.end <= b ? (g..end = a) : g.start >= a && g.start < b ? (g..start = b) : g
    ];
    selected = null;
    selA = selB = null;
    notifyListeners();
  }

  /// إن وقع t داخل جزء محذوف يرجع نهايته (للتشغيل الذي يقفز فوقه).
  double? skipCut(double t) {
    for (final (a, b) in cuts) {
      if (t >= a && t < b) return b;
    }
    return null;
  }

  // ── المزامنة بالنقر: كل نقرة تنهي المقطع الحالي وتبدأ التالي ──
  int? tapIndex;
  void tapStart() {
    checkpoint();
    tapIndex = segs.indexWhere((g) => g.end > playhead);
    if (tapIndex! < 0) tapIndex = null;
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

  /// المقاطع داخل حدود القص، مرتبة.
  List<Segment> get valid =>
      segs.where((g) => g.text.trim().isNotEmpty && g.end > g.start && g.end > trimStart && g.start < trimEnd).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  bool get hasEdits => trimStart > 0 || trimEnd < duration || cuts.isNotEmpty;
}

// ── الخط الزمني ──
// الصفوف كما في CapCut: المسطرة، ثم شريط صور الفيديو، ثم المقاطع، ثم موجة الصوت
const _rulerH = 18.0, _filmTop = 20.0, _filmH = 72.0, _segTop = 96.0, _segH = 44.0, _waveTop = 144.0, _waveH = 34.0;
const tlHeight = 180.0;

class Timeline extends StatefulWidget {
  final EditorModel m;
  final ui.Image? Function(double t)? thumb; // صورة مصغّرة من الفيديو النهائي عند t
  const Timeline(this.m, {super.key, this.thumb});
  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  String _mode = '';
  double _x0 = 0, _view0 = 0, _pps0 = 0, _a0 = 0, _b0 = 0;
  bool _moved = false;

  EditorModel get m => widget.m;
  double t2x(double t) => (t - m.view) * m.pps;
  double x2t(double x) => m.view + x / m.pps;

  int? _segAt(double x) {
    final t = x2t(x);
    for (var i = 0; i < m.segs.length; i++) {
      if (t >= m.segs[i].start && t <= m.segs[i].end) return i;
    }
    return null;
  }

  void _clampView(double width) {
    final maxView = max(0.0, m.duration - width / m.pps);
    m.view = m.view.clamp(0, maxView);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      return GestureDetector(
        onTapUp: (d) {
          final p = d.localPosition;
          if (p.dy >= _segTop && p.dy < _segTop + _segH) {
            final i = _segAt(p.dx);
            m.select(i);
            if (i != null) m.seek(max(m.segs[i].start, x2t(p.dx)));
          } else {
            m.seek(x2t(p.dx));
          }
        },
        onScaleStart: (d) {
          final p = d.localFocalPoint;
          _x0 = p.dx;
          _view0 = m.view;
          _pps0 = m.pps;
          _moved = false;
          _mode = 'pan';
          final g = m.sel;
          if (d.pointerCount == 1 && g != null && p.dy >= _segTop && p.dy < _segTop + _segH) {
            final xs = t2x(g.start), xe = t2x(g.end);
            if ((p.dx - xs).abs() < 18) {
              _mode = 'start';
            } else if ((p.dx - xe).abs() < 18) {
              _mode = 'end';
            } else if (p.dx > xs && p.dx < xe) {
              _mode = 'move';
            }
            _a0 = g.start;
            _b0 = g.end;
          }
        },
        onScaleUpdate: (d) {
          final dx = d.localFocalPoint.dx - _x0, dt = dx / m.pps;
          if (d.pointerCount >= 2) {
            final focusT = _view0 + _x0 / _pps0;
            m.pps = (_pps0 * d.horizontalScale).clamp(8.0, 400.0);
            m.view = focusT - d.localFocalPoint.dx / m.pps;
            _clampView(width);
            m.changed();
            return;
          }
          if (!_moved && dx.abs() > 3) {
            _moved = true;
            if (_mode != 'pan') m.checkpoint();
          }
          if (!_moved) return;
          final g = m.sel;
          final i = m.selected;
          if (_mode == 'pan' || g == null || i == null) {
            m.view = _view0 - dt;
            _clampView(width);
          } else {
            final lo = i > 0 ? m.segs[i - 1].end + 0.05 : 0.0;
            final hi = i + 1 < m.segs.length ? m.segs[i + 1].start - 0.05 : m.duration;
            if (_mode == 'start') {
              g.start = (_a0 + dt).clamp(lo, g.end - 0.2);
            } else if (_mode == 'end') {
              g.end = (_b0 + dt).clamp(g.start + 0.2, hi);
            } else {
              final shift = dt.clamp(lo - _a0, hi - _b0);
              g.start = _a0 + shift;
              g.end = _b0 + shift;
            }
          }
          m.changed();
        },
        child: CustomPaint(size: Size(width, tlHeight), painter: _TimelinePainter(m, Theme.of(context).colorScheme, widget.thumb)),
      );
    });
  }
}

class _TimelinePainter extends CustomPainter {
  final EditorModel m;
  final ColorScheme cs;
  final ui.Image? Function(double t)? thumb;
  _TimelinePainter(this.m, this.cs, this.thumb) : super(repaint: m);

  @override
  void paint(Canvas c, Size size) {
    final w = size.width;
    double x(double t) => (t - m.view) * m.pps;
    c.drawRect(Offset.zero & size, Paint()..color = cs.surfaceContainerHighest);
    // المسطرة
    final step = m.pps > 120 ? 1 : m.pps > 40 ? 5 : m.pps > 15 ? 10 : 30;
    final tick = Paint()..color = cs.outline;
    for (var s = (m.view / step).floor() * step; s <= m.view + w / m.pps; s += step) {
      final px = x(s.toDouble());
      c.drawLine(Offset(px, _rulerH - 6), Offset(px, _rulerH), tick);
      final tp = TextPainter(
          text: TextSpan(text: '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(c, Offset(px + 2, 2));
    }
    // شريط صور الفيديو: صورة لكل خانة من الفيديو النهائي في وقتها
    const tileW = _filmH * 9 / 16;
    final first = (m.view * m.pps / tileW).floor();
    for (var k = first; k * tileW / m.pps <= m.view + w / m.pps; k++) {
      final t0 = k * tileW / m.pps, px = x(t0);
      final dst = Rect.fromLTWH(px, _filmTop, tileW + 0.5, _filmH);
      final img = t0 < m.duration ? thumb?.call(t0 + tileW / m.pps / 2) : null;
      if (img != null) {
        c.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()), dst, Paint()..filterQuality = FilterQuality.low);
      } else if (t0 < m.duration) {
        c.drawRect(dst.deflate(0.5), Paint()..color = cs.surfaceContainerLow);
      }
    }
    // الموجة
    final wave = Paint()..color = cs.primary.withValues(alpha: 0.55);
    final mid = _waveTop + _waveH / 2;
    for (var px = 0.0; px < w; px += 2) {
      final i0 = (x2i(px)), i1 = x2i(px + 2);
      var v = 0.0;
      for (var i = max(0, i0); i < min(m.peaks.length, i1 + 1); i++) {
        v = max(v, m.peaks[i]);
      }
      c.drawRect(Rect.fromLTWH(px, mid - v * _waveH / 2, 1.5, max(1, v * _waveH)), wave);
    }
    // القص: المناطق المحذوفة مظللة
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.45);
    if (m.trimStart > 0) c.drawRect(Rect.fromLTRB(0, 0, x(m.trimStart).clamp(0, w), size.height), shade);
    if (m.trimEnd < m.duration) c.drawRect(Rect.fromLTRB(x(m.trimEnd).clamp(0, w), 0, w, size.height), shade);
    final cut = Paint()..color = Colors.red.withValues(alpha: 0.35);
    for (final (a, b) in m.cuts) {
      c.drawRect(Rect.fromLTRB(x(a).clamp(0, w), 0, x(b).clamp(0, w), size.height), cut);
    }
    // التظليل
    final sel = Paint()..color = Colors.amber.withValues(alpha: 0.35);
    final mark = Paint()
      ..color = Colors.amber
      ..strokeWidth = 2;
    if (m.selA != null && m.selB != null) c.drawRect(Rect.fromLTRB(x(m.selA!), 0, x(m.selB!), size.height), sel);
    for (final t in [m.selA, m.selB]) {
      if (t != null) c.drawLine(Offset(x(t), 0), Offset(x(t), size.height), mark);
    }
    // المقاطع
    for (var i = 0; i < m.segs.length; i++) {
      final g = m.segs[i];
      final l = x(g.start), r = x(g.end);
      if (r < 0 || l > w) continue;
      final selected = i == m.selected;
      final rect = RRect.fromRectAndRadius(Rect.fromLTRB(l, _segTop, r, _segTop + _segH), const Radius.circular(6));
      c.drawRRect(rect, Paint()..color = selected ? cs.primary : cs.secondaryContainer);
      if (selected) {
        final h = Paint()..color = cs.onPrimary;
        c.drawRect(Rect.fromLTWH(l + 2, _segTop + 14, 4, _segH - 28), h);
        c.drawRect(Rect.fromLTWH(r - 6, _segTop + 14, 4, _segH - 28), h);
      }
      if (r - l > 24) {
        c.save();
        c.clipRect(Rect.fromLTRB(l + 8, _segTop, r - 8, _segTop + _segH));
        final tp = TextPainter(
            text: TextSpan(
                text: g.text.replaceAll(marks, ''),
                style: TextStyle(fontSize: 13, color: selected ? cs.onPrimary : cs.onSecondaryContainer)),
            textDirection: TextDirection.rtl,
            maxLines: 2)
          ..layout(maxWidth: max(10, r - l - 16));
        tp.paint(c, Offset(r - 8 - tp.width, _segTop + (_segH - tp.height) / 2));
        c.restore();
      }
    }
    // المؤشر
    final ph = x(m.playhead);
    c.drawLine(Offset(ph, 0), Offset(ph, size.height), Paint()
      ..color = cs.error
      ..strokeWidth = 2);
  }

  int x2i(double px) => ((m.view + px / m.pps) * 100).floor();

  @override
  bool shouldRepaint(covariant _TimelinePainter old) => true;
}

String fmtTime(double t) => '${t ~/ 60}:${(t % 60).toStringAsFixed(1).padLeft(4, '0')}';

/// كلمات المقطع مع إبقاء رقم الآية ملتصقاً بآخر كلمة (لاختيار موضع التقسيم).
List<String> splitWords(String text) => text.split(' ').where((w) => w.isNotEmpty && !isNum(w)).toList();
