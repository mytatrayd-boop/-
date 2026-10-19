// الشكل: إعدادات النص والترويسة والخلفية، ورسم طبقات النص والترويسة بمقاس الفيديو 1080×1920.
// نفس الرسم يُستعمل في المعاينة وفي الإنتاج (صور PNG شفافة يركّبها FFmpeg).
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'quran.dart';

const vw = 1080.0, vh = 1920.0;

class Look {
  double fontSize = 60, textY = 0.40, width = 0.85, lineGap = 1.9, shadow = 0.85, fade = 0.35;
  String align = 'center';
  Color color = Colors.white;
  String headerMode = 'mushaf'; // mushaf إطار وبسملة مزخرفة / basmala بسملة مزخرفة / plain نص عادي
  bool showName = true, showBasmala = true;
  double headerSize = 46, headerY = 0.09;
  Color headerColor = const Color(0xFFEBEBEB);
  double dim = 0.25, blur = 0;
  bool zoom = false; // التقريب البطيء أثقل جزء في الإنتاج
  bool manyBgs = false;
  String bgChange = 'time'; // time / segment
  double bgEvery = 8, transDur = 1;
  String transition = 'fade';
}

List<Shadow> _shadows(double s) =>
    s <= 0 ? const [] : [Shadow(color: Colors.black.withValues(alpha: s), blurRadius: 16, offset: const Offset(3, 4))];

TextPainter _tp(String text, TextStyle style) =>
    TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.rtl)..layout();

List<String> _tokens(String text) {
  final out = <String>[];
  for (final w in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
    if (out.isNotEmpty && isNum(w)) {
      out[out.length - 1] += ' $w';
    } else {
      out.add(w);
    }
  }
  return out;
}

/// أقل عدد من الأسطر، موزّعة بأطوال متقاربة (رقم الآية مع آخر كلمة، ولا سطر أخير بكلمة واحدة).
List<String> wrapBalanced(String text, TextStyle style, double maxW) {
  final words = _tokens(text);
  if (words.isEmpty) return [];
  double width(int i, int j) => _tp(words.sublist(i, j).join(' '), style).width;
  var count = 1;
  var cur = '';
  for (final w in words) {
    final t = cur.isEmpty ? w : '$cur $w';
    if (cur.isNotEmpty && _tp(t, style).width > maxW) {
      count++;
      cur = w;
    } else {
      cur = t;
    }
  }
  final n = words.length;
  final best = <String, (double, int)>{'0,0': (0, -1)};
  for (var k = 1; k <= count; k++) {
    for (var j = k; j <= n; j++) {
      (double, int)? opt;
      for (var i = k - 1; i < j; i++) {
        final p = best['${k - 1},$i'];
        if (p == null) continue;
        final v = max(p.$1, width(i, j));
        if (opt == null || v < opt.$1) opt = (v, i);
      }
      if (opt != null) best['$k,$j'] = opt;
    }
  }
  final lines = <String>[];
  var j = n;
  for (var k = count; k > 0; k--) {
    final i = best['$k,$j']!.$2;
    lines.insert(0, words.sublist(i, j).join(' '));
    j = i;
  }
  return lines;
}

/// يرسم نص المقطع (مرمّزاً لخط المجمع) على لوحة بمقاس الفيديو.
Rect paintText(Canvas c, String text, Look l) {
  final style = TextStyle(fontFamily: 'Hafs', fontSize: l.fontSize, color: l.color, height: 1.0, shadows: _shadows(l.shadow));
  final maxW = vw * l.width, margin = (vw - maxW) / 2;
  final lines = wrapBalanced(text, style, maxW);
  final step = l.fontSize * l.lineGap;
  var y = vh * l.textY - step * lines.length / 2;
  var box = Rect.zero;
  for (final ln in lines) {
    final tp = _tp(ln, style);
    final x = l.align == 'right' ? vw - margin - tp.width : l.align == 'left' ? margin : (vw - tp.width) / 2;
    final at = Offset(x, y + (step - tp.height) / 2);
    tp.paint(c, at);
    box = box.isEmpty ? at & tp.size : box.expandToInclude(at & tp.size);
    y += step;
  }
  return box;
}

/// رمز واحد من خط الترويسة (QCF_BSML) في المنتصف بعرض محدد؛ يرجع ارتفاعه.
Rect _glyph(Canvas c, String ch, double width, double y, Look l) {
  final probe = _tp(ch, const TextStyle(fontFamily: 'Bsml', fontSize: 100));
  final size = 100 * width / max(probe.width, 1);
  final tp = TextPainter(
      text: TextSpan(text: ch, style: TextStyle(fontFamily: 'Bsml', fontSize: size, color: l.headerColor, shadows: _shadows(l.shadow))),
      textDirection: TextDirection.ltr)
    ..layout();
  final at = Offset((vw - tp.width) / 2, y);
  tp.paint(c, at);
  return at & tp.size;
}

Rect paintHeader(Canvas c, String? name, String? bas, Look l) {
  if (name == null && bas == null) return Rect.zero;
  var box = Rect.zero;
  void add(Rect r) => box = box.isEmpty ? r : box.expandToInclude(r);
  final style = TextStyle(fontFamily: 'Hafs', fontSize: l.headerSize, color: l.headerColor, shadows: _shadows(l.shadow));
  void plain(String t, double cy) {
    final tp = _tp(t, style);
    final at = Offset((vw - tp.width) / 2, cy - tp.height / 2);
    tp.paint(c, at);
    add(at & tp.size);
  }

  var y = vh * l.headerY;
  final scale = l.headerSize / 46;
  if (name != null) {
    if (l.headerMode == 'mushaf') {
      final r = _glyph(c, 'ò', vw * min(0.86 * scale, 0.98), y, l);
      add(r);
      final h = r.height;
      plain(name, y + h / 2);
      y += h + l.headerSize * 0.4;
    } else {
      plain(name, y + l.headerSize * 0.6);
      y += l.headerSize * 1.8;
    }
  }
  if (bas != null) {
    if (l.headerMode == 'plain') {
      plain(bas, y + l.headerSize * 0.6);
    } else {
      add(_glyph(c, 'ó', vw * min(0.72 * scale, 0.95), y, l));
    }
  }
  return box;
}

/// طبقة PNG شفافة مقصوصة على ما رُسم فيها (مع هامش للظل): ترجع الصورة وموضعها في الإطار.
/// الطبقة الصغيرة أسرع بكثير في التركيب من طبقة بمقاس الشاشة كاملة.
Future<(Uint8List, int, int)> layerPng(Rect Function(Canvas) paint) async {
  final probe = ui.PictureRecorder();
  final box = paint(Canvas(probe)); // قياس فقط
  probe.endRecording().dispose();
  final r = box.isEmpty ? const Rect.fromLTWH(0, 0, 2, 2) : box.inflate(28).intersect(const Rect.fromLTWH(0, 0, vw, vh));
  final x = r.left.floor() & ~1, y = r.top.floor() & ~1;
  final w = (r.right.ceil() - x + 1) & ~1, h = (r.bottom.ceil() - y + 1) & ~1;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..translate(-x.toDouble(), -y.toDouble());
  paint(c);
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return (data!.buffer.asUint8List(), x, y);
}
