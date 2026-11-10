// الشكل: إعدادات النص والترويسة والخلفية، ورسم طبقات النص والترويسة بمقاس الفيديو 1080×1920.
// نفس الرسم يُستعمل في المعاينة وفي الإنتاج (صور PNG شفافة يركّبها FFmpeg).
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'quran.dart';

const vw = 1080.0, vh = 1920.0;
const rtlTrans = {'ar.muyassar', 'ur.jalandhry'};
const fontOptions = {'': 'خط النظام', 'Amiri': 'أميري', 'Tajawal': 'تجوال', 'Almarai': 'المراعي', 'Scheherazade': 'شهرزاد', 'Lateef': 'لطيف'};

// رسم المقاطع والترويسة مرة واحدة ثم إعادة استخدامه في كل إطار (التخطيط النصي هو الأثقل)
final _pics = <String, ui.Picture>{};
ui.Picture _cached(String key, void Function(Canvas) draw) {
  if (_pics.length > 300) _pics.clear();
  return _pics.putIfAbsent(key, () {
    final rec = ui.PictureRecorder();
    draw(Canvas(rec));
    return rec.endRecording();
  });
}

class Look {
  double fontSize = 60, textY = 0.40, width = 0.85, lineGap = 1.9, shadow = 0.85, fade = 0.35;
  String align = 'center';
  Color color = Colors.white;
  String headerMode = 'mushaf'; // mushaf إطار وبسملة مزخرفة / basmala بسملة مزخرفة / plain نص عادي
  bool showName = true, showBasmala = true;
  double headerSize = 46, headerY = 0.09;
  Color headerColor = const Color(0xFFEBEBEB);
  double dim = 0.25, blur = 0;
  // أدوات تحسين الصورة (تُطبَّق على الخلفية في المعاينة والتصدير)
  double sharpen = 0.5, brightness = 0, contrast = 1, saturation = 1;
  bool hq = true; // تصدير عالي الجودة (معدل بيانات أعلى)
  // مستطيل خلف النص (والترجمة) لتوضيح القراءة على الخلفيات الفاتحة أو المزدحمة
  bool boxOn = false;
  Color boxColor = Colors.black;
  double boxOpacity = 0.5, boxPad = 36, boxRadius = 28;
  String textFx = 'fade'; // تأثير ظهور النص: fade / slide / none
  // الترجمة أو التفسير تحت الآية ('' = بلا)
  String trans = '';
  double transSize = 40, transY = 0.68, transGap = 50; // transGap: المسافة الثابتة بين آخر سطر من الآية والترجمة
  Color transColor = const Color(0xFFE8E8E8);
  // اسم القارئ في بداية الفيديو
  String reciter = '';
  double reciterSecs = 5, reciterSize = 42, reciterY = 0.9;
  // ظل وخط مستقلان للترجمة ولاسم القارئ ('' = خط النظام)
  double transShadow = 0.85, reciterShadow = 0.85;
  String transFont = '', reciterFont = '';
  bool reciterAll = false;
  bool zoom = false; // التقريب البطيء أثقل جزء في الإنتاج
  bool manyBgs = false;
  String bgChange = 'time'; // time / segment
  double bgEvery = 8, transDur = 1;
  String transition = 'fade';

  Map<String, dynamic> toJson() => {
        'fontSize': fontSize,
        'textY': textY,
        'width': width,
        'lineGap': lineGap,
        'shadow': shadow,
        'fade': fade,
        'headerSize': headerSize,
        'headerY': headerY,
        'dim': dim,
        'blur': blur,
        'sharpen': sharpen,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'boxOpacity': boxOpacity,
        'boxPad': boxPad,
        'boxRadius': boxRadius,
        'transSize': transSize,
        'transY': transY,
        'transGap': transGap,
        'reciterSecs': reciterSecs,
        'reciterSize': reciterSize,
        'reciterY': reciterY,
        'transShadow': transShadow,
        'reciterShadow': reciterShadow,
        'bgEvery': bgEvery,
        'transDur': transDur,
        'align': align,
        'headerMode': headerMode,
        'textFx': textFx,
        'trans': trans,
        'reciter': reciter,
        'transFont': transFont,
        'reciterFont': reciterFont,
        'bgChange': bgChange,
        'transition': transition,
        'showName': showName,
        'showBasmala': showBasmala,
        'hq': hq,
        'boxOn': boxOn,
        'reciterAll': reciterAll,
        'zoom': zoom,
        'manyBgs': manyBgs,
        'color': color.toARGB32(),
        'headerColor': headerColor.toARGB32(),
        'boxColor': boxColor.toARGB32(),
        'transColor': transColor.toARGB32(),
      };

  /// يطبّق القيم المحفوظة؛ المفقود منها يعود للقيمة الافتراضية ({} = إعادة الضبط).
  void fromJson(Map<String, dynamic> j) {
    final d = Look();
    double n(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    String s(String k, String def) => j[k] as String? ?? def;
    bool b(String k, bool def) => j[k] as bool? ?? def;
    Color c(String k, Color def) => j[k] is int ? Color(j[k] as int) : def;
    fontSize = n('fontSize', d.fontSize);
    textY = n('textY', d.textY);
    width = n('width', d.width);
    lineGap = n('lineGap', d.lineGap);
    shadow = n('shadow', d.shadow);
    fade = n('fade', d.fade);
    headerSize = n('headerSize', d.headerSize);
    headerY = n('headerY', d.headerY);
    dim = n('dim', d.dim);
    blur = n('blur', d.blur);
    sharpen = n('sharpen', d.sharpen);
    brightness = n('brightness', d.brightness);
    contrast = n('contrast', d.contrast);
    saturation = n('saturation', d.saturation);
    boxOpacity = n('boxOpacity', d.boxOpacity);
    boxPad = n('boxPad', d.boxPad);
    boxRadius = n('boxRadius', d.boxRadius);
    transSize = n('transSize', d.transSize);
    transY = n('transY', d.transY);
    transGap = n('transGap', d.transGap);
    reciterSecs = n('reciterSecs', d.reciterSecs);
    reciterSize = n('reciterSize', d.reciterSize);
    reciterY = n('reciterY', d.reciterY);
    transShadow = n('transShadow', d.transShadow);
    reciterShadow = n('reciterShadow', d.reciterShadow);
    bgEvery = n('bgEvery', d.bgEvery);
    transDur = n('transDur', d.transDur);
    align = s('align', d.align);
    headerMode = s('headerMode', d.headerMode);
    textFx = s('textFx', d.textFx);
    trans = s('trans', d.trans);
    reciter = s('reciter', d.reciter);
    transFont = s('transFont', d.transFont);
    reciterFont = s('reciterFont', d.reciterFont);
    bgChange = s('bgChange', d.bgChange);
    transition = s('transition', d.transition);
    showName = b('showName', d.showName);
    showBasmala = b('showBasmala', d.showBasmala);
    hq = b('hq', d.hq);
    boxOn = b('boxOn', d.boxOn);
    reciterAll = b('reciterAll', d.reciterAll);
    zoom = b('zoom', d.zoom);
    manyBgs = b('manyBgs', d.manyBgs);
    color = c('color', d.color);
    headerColor = c('headerColor', d.headerColor);
    boxColor = c('boxColor', d.boxColor);
    transColor = c('transColor', d.transColor);
  }
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

/// المقطع كاملاً: المستطيل الخلفي (إن فُعّل) ثم النص ثم الترجمة. يرجع المنطقة المرسومة.
Rect paintSegment(Canvas c, String text, String tr, Look l) {
  // الترجمة تتبع آخر سطر من الآية بمسافة ثابتة، فتبقى المسافة نفسها سواء كانت الآية سطراً أو عدة أسطر
  Rect layout(Canvas cv) {
    final t = paintText(cv, text, l);
    return unionRect(t, paintTrans(cv, tr, l, top: t.isEmpty ? null : t.bottom + l.transGap));
  }

  var back = Rect.zero;
  if (l.boxOn) {
    final rec = ui.PictureRecorder(); // قياس فقط
    back = layout(Canvas(rec)).inflate(l.boxPad);
    rec.endRecording().dispose();
    if (!back.isEmpty) {
      c.drawRRect(RRect.fromRectAndRadius(back, Radius.circular(l.boxRadius)), Paint()..color = l.boxColor.withValues(alpha: l.boxOpacity));
    }
  }
  return unionRect(back, layout(c));
}

ui.Picture segmentPicture(String text, String tr, Look l) => _cached(
    'S|$text|$tr|${l.fontSize}|${l.textY}|${l.width}|${l.lineGap}|${l.color.toARGB32()}|${l.shadow}|${l.align}|${l.boxOn}|${l.boxColor.toARGB32()}|'
    '${l.boxOpacity}|${l.boxPad}|${l.boxRadius}|${l.trans}|${l.transSize}|${l.transGap}|${l.transColor.toARGB32()}|${l.transShadow}|${l.transFont}',
    (c) => paintSegment(c, text, tr, l));

ui.Picture headerPicture(String? name, String? bas, Look l) => _cached(
    'H|$name|$bas|${l.headerMode}|${l.headerSize}|${l.headerY}|${l.headerColor.toARGB32()}|${l.shadow}', (c) => paintHeader(c, name, bas, l));

ui.Picture reciterPicture(Look l) => _cached(
    'R|${l.reciter}|${l.reciterFont}|${l.reciterSize}|${l.reciterY}|${l.headerColor.toARGB32()}|${l.reciterShadow}', (c) => paintReciter(c, l));

Rect unionRect(Rect a, Rect b) => a.isEmpty ? b : b.isEmpty ? a : a.expandToInclude(b);

/// الترجمة تحت الآية بخط النظام، موسّطة، حتى 7 أسطر.
Rect paintTrans(Canvas c, String text, Look l, {double? top}) {
  if (text.isEmpty) return Rect.zero;
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(
            fontFamily: l.transFont.isEmpty ? null : l.transFont, fontSize: l.transSize, color: l.transColor, height: 1.35, shadows: _shadows(l.transShadow))),
    textDirection: rtlTrans.contains(l.trans) ? TextDirection.rtl : TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 7,
    ellipsis: '…',
  )..layout(maxWidth: vw * l.width);
  final at = Offset((vw - tp.width) / 2, top ?? vh * l.transY - tp.height / 2);
  tp.paint(c, at);
  return at & tp.size;
}

/// اسم القارئ.
Rect paintReciter(Canvas c, Look l) {
  final name = l.reciter.trim();
  if (name.isEmpty) return Rect.zero;
  final tp = _tp(
      name,
      TextStyle(
          fontFamily: l.reciterFont.isEmpty ? null : l.reciterFont, fontSize: l.reciterSize, color: l.headerColor, shadows: _shadows(l.reciterShadow)));
  final at = Offset((vw - tp.width) / 2, vh * l.reciterY - tp.height / 2);
  tp.paint(c, at);
  return at & tp.size;
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
