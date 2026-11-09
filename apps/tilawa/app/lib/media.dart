// الوسائط عبر FFmpeg: قراءة الصوت للتعرف، وصورة مصغّرة للفيديو، وإنتاج الفيديو النهائي.
// سلسلة المرشحات منقولة من engine/render.py المختبر.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'look.dart';
import 'sync.dart';

const fps = 30;
const previewFps = 8, previewMaxSec = 10; // إطارات معاينة الفيديو

class Bg {
  final String path, name;
  final bool video;
  String? thumb; // صورة للمعاينة (للفيديو)
  List<ui.Image>? frames; // إطارات مصغّرة من الفيديو للمعاينة المتحركة
  double speed; // سرعة الفيديو: 0.5 = حركة بطيئة (يطول الفيديو)
  Bg(this.path, this.name, {this.video = false, this.thumb}) : speed = video ? 0.5 : 1;
  String get preview => thumb ?? path;
}

Future<Directory> workDir() async =>
    Directory('${(await getTemporaryDirectory()).path}/tilawa')..createSync(recursive: true);

Future<void> _run(List<String> args) async {
  final s = await FFmpegKit.executeWithArguments(['-y', '-v', 'error', ...args]);
  if (!ReturnCode.isSuccess(await s.getReturnCode())) {
    throw Exception((await s.getAllLogsAsString()) ?? 'ffmpeg failed');
  }
}

/// الصوت بمعدل 16 ألف عينة/ث أحادي (ما يحتاجه التعرف ورسم الموجة).
Future<Float32List> decode16k(String path) async {
  final out = '${(await workDir()).path}/audio16.f32';
  await _run(['-i', path, '-ac', '1', '-ar', '16000', '-f', 'f32le', out]);
  final b = await File(out).readAsBytes();
  return b.buffer.asFloat32List(b.offsetInBytes, b.lengthInBytes ~/ 4);
}

Future<String> videoThumb(String path) async {
  final out = '${(await workDir()).path}/thumb_${path.hashCode}.jpg';
  await _run(['-i', path, '-frames:v', '1', '-vf', 'scale=540:-2', out]);
  return out;
}

/// إطارات مصغّرة (8 في الثانية، حتى 10 ث) تجعل خلفية الفيديو تتحرك في المعاينة.
Future<List<ui.Image>> videoFrames(String path) async {
  final dir = Directory('${(await workDir()).path}/frames_${path.hashCode}');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);
  await _run(['-i', path, '-t', '$previewMaxSec', '-vf', 'fps=$previewFps,scale=270:-2', '-q:v', '5', '${dir.path}/f%03d.jpg']);
  final files = dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) await decodeImageFromList(await f.readAsBytes())];
}

/// إطار الفيديو المناسب لزمن t داخل مقطع الخلفية (يتكرر كما في التصدير، وتُراعى السرعة).
ui.Image? videoFrameAt(Bg b, double t) {
  final f = b.frames;
  if (f == null || f.isEmpty) return null;
  return f[(t * b.speed * previewFps).floor().abs() % f.length];
}

bool isVideo(String path) => RegExp(r'\.(mp4|mov|m4v|webm|mkv|3gp)$', caseSensitive: false).hasMatch(path);

/// أوقات تبدّل الخلفية [0، t1، ...]. خلفية واحدة = بلا تبدّل.
List<double> bgSchedule(int n, double duration, List<Segment> segs, Look l) {
  const minLen = 3.0;
  if (n < 2) return [0];
  if (l.bgChange == 'segment') {
    final p = [0.0];
    for (final g in segs.skip(1)) {
      if (g.start - p.last >= minLen && duration - g.start >= minLen) p.add(g.start);
    }
    return p;
  }
  final every = max(l.bgEvery, minLen);
  return [for (var i = 0; i == 0 || i * every <= duration - minLen; i++) i * every];
}

/// الأجزاء الباقية من الصوت بعد القص من الطرفين وحذف المناطق المظللة.
List<(double, double)> keptRanges(double start, double end, List<(double, double)> cuts) {
  final out = <(double, double)>[];
  var t = start;
  for (final (a, b) in [...cuts]..sort((x, y) => x.$1.compareTo(y.$1))) {
    if (b <= t || a >= end) continue;
    if (a > t) out.add((t, a));
    t = max(t, b);
  }
  if (end > t) out.add((t, end));
  return out;
}

/// وقت الصوت ← وقت الفيديو (null إن كان داخل جزء محذوف).
double? outTime(double t, List<(double, double)> kept) {
  var acc = 0.0;
  for (final (a, b) in kept) {
    if (t < a) return null;
    if (t <= b) return acc + t - a;
    acc += b - a;
  }
  return null;
}

(List<String>, String) _clip(Bg bg, double len, bool zoom) {
  if (!bg.video) {
    final args = ['-loop', '1', '-framerate', '$fps', '-t', len.toStringAsFixed(3), '-i', bg.path];
    final frames = (len * fps).ceil() + 1;
    final f = zoom
        ? 'scale=1188:2112:force_original_aspect_ratio=increase:flags=lanczos,crop=1188:2112,'
            "zoompan=z='1+0.08*on/$frames':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=$fps"
        : 'scale=1080:1920:force_original_aspect_ratio=increase:flags=lanczos,crop=1080:1920,fps=$fps';
    return (args, f);
  }
  // الحركة البطيئة: setpts يمدّ الزمن فيحتاج الفيديو مصدراً أقل ويطول مقطعه
  final slow = bg.speed == 1 ? '' : 'setpts=${(1 / bg.speed).toStringAsFixed(3)}*PTS,';
  return (
    ['-stream_loop', '-1', '-t', (len * bg.speed + 1).toStringAsFixed(3), '-i', bg.path],
    '${slow}scale=1080:1920:force_original_aspect_ratio=increase:flags=lanczos,crop=1080:1920,fps=$fps'
  );
}

/// ينتج الفيديو: segs بأوقات مطلقة في الصوت، ويؤخذ من الصوت الأجزاء kept فقط متصلة.
Future<String> renderVideo({
  required String audio,
  required List<Segment> segs,
  required List<String> texts, // نصوص المقاطع مرمّزة لخط المجمع
  required List<String> trans, // ترجمة كل مقطع ('' = بلا)
  required List<Bg> bgs,
  required Look look,
  required String? headerName,
  required String? headerBasmala,
  required List<(double, double)> kept,
  int height = 1920, // 1920 = 1080p، و1280 = 720p
  required void Function(double) onProgress,
}) async {
  final dir = await workDir();
  final duration = kept.fold(0.0, (s, k) => s + k.$2 - k.$1);
  // كل مقطع يُنقل إلى وقت الفيديو؛ ما وقع في جزء محذوف يُقص على حدوده
  double clampOut(double t, bool isStart) {
    final o = outTime(t, kept);
    if (o != null) return o;
    var acc = 0.0;
    for (final (a, b) in kept) {
      if (t < a) return acc;
      acc += b - a;
    }
    return isStart ? duration : acc;
  }

  final shifted = <(Segment, String, String)>[];
  for (var i = 0; i < segs.length; i++) {
    final s = clampOut(segs[i].start, true), e = clampOut(segs[i].end, false);
    if (e - s > 0.2) shifted.add((Segment(segs[i].text, s, e), texts[i], trans[i]));
  }
  final points = bgSchedule(bgs.length, duration, [for (final x in shifted) x.$1], look);
  final td = look.transition != 'none' && points.length > 1 ? min(look.transDur, 1.5) : 0.0;

  final args = <String>[], chain = <String>[];
  for (var k = 0; k < points.length; k++) {
    final end = k + 1 < points.length ? points[k + 1] + td : duration;
    final (a, f) = _clip(bgs[k % bgs.length], end - points[k], look.zoom);
    args.addAll(a);
    chain.add('[$k:v]$f,setsar=1,format=yuv420p,trim=duration=${(end - points[k]).toStringAsFixed(3)},setpts=PTS-STARTPTS[c$k]');
  }
  var cur = 'c0';
  for (var k = 1; k < points.length; k++) {
    chain.add(td > 0
        ? '[$cur][c$k]xfade=transition=${look.transition}:duration=${td.toStringAsFixed(3)}:offset=${points[k].toStringAsFixed(3)}[x$k]'
        : '[$cur][c$k]concat=n=2:v=1:a=0[x$k]');
    cur = 'x$k';
  }
  final post = [
    if (look.sharpen > 0) 'unsharp=5:5:${look.sharpen.toStringAsFixed(2)}:5:5:0',
    if (look.brightness != 0 || look.contrast != 1 || look.saturation != 1)
      'eq=brightness=${look.brightness.toStringAsFixed(2)}:contrast=${look.contrast.toStringAsFixed(2)}:saturation=${look.saturation.toStringAsFixed(2)}',
    if (look.blur > 0) 'gblur=sigma=${look.blur.toStringAsFixed(1)}', if (look.dim > 0) 'drawbox=c=black@${look.dim.toStringAsFixed(2)}:t=fill'];
  chain.add('[$cur]${post.isEmpty ? 'null' : post.join(',')},format=yuv420p[bg]');

  final n = points.length;
  // الصوت: الأجزاء الباقية متصلة
  args.addAll(['-i', audio]);
  final parts = [
    for (var k = 0; k < kept.length; k++)
      '[$n:a]atrim=start=${kept[k].$1.toStringAsFixed(3)}:end=${kept[k].$2.toStringAsFixed(3)},asetpts=PTS-STARTPTS[a$k]'
  ];
  chain.addAll(parts);
  chain.add('${[for (var k = 0; k < kept.length; k++) '[a$k]'].join()}concat=n=${kept.length}:v=0:a=1[aout]');
  // طبقات صغيرة مقصوصة، تُقرأ صورها مرة في الثانية وتُكرر إطاراتها (أسرع بكثير)
  final head = '${dir.path}/header.png';
  final (hb, hx, hy) = await layerPng((c) => paintHeader(c, headerName, headerBasmala, look));
  await File(head).writeAsBytes(hb);
  args.addAll(['-loop', '1', '-framerate', '1', '-t', duration.toStringAsFixed(3), '-i', head]);
  chain.add('[${n + 1}:v]fps=$fps,format=rgba[hd]');
  chain.add('[bg][hd]overlay=$hx:$hy:eof_action=repeat[v0]');
  for (var i = 0; i < shifted.length; i++) {
    final (g, text, tr) = shifted[i];
    final png = '${dir.path}/seg_$i.png';
    final (tb, tx, ty) = await layerPng((c) => unionRect(paintText(c, text, look), paintTrans(c, tr, look)));
    await File(png).writeAsBytes(tb);
    final d = g.end - g.start, f = max(look.textFx == 'none' ? 0.04 : min(look.fade, d / 3), 0.04);
    final pos = look.textFx == 'slide'
        ? "$tx:y='$ty+50*max(0,1-(t-${g.start.toStringAsFixed(3)})/${f.toStringAsFixed(3)})'"
        : '$tx:$ty';
    args.addAll(['-loop', '1', '-framerate', '1', '-t', (d + 1).toStringAsFixed(3), '-i', png]);
    chain.add('[${i + n + 2}:v]fps=$fps,trim=duration=${d.toStringAsFixed(3)},format=rgba,fade=in:st=0:d=${f.toStringAsFixed(3)}:alpha=1,'
        'fade=out:st=${max(d - f, 0).toStringAsFixed(3)}:d=${f.toStringAsFixed(3)}:alpha=1,'
        'setpts=PTS+${g.start.toStringAsFixed(3)}/TB[t$i]');
    chain.add('[v$i][t$i]overlay=$pos:eof_action=pass[v${i + 1}]');
  }
  var last = 'v${shifted.length}';
  if (look.reciter.trim().isNotEmpty) {
    final rd = look.reciterAll ? duration : min(look.reciterSecs, duration), rf = min(0.5, rd / 3);
    final png = '${dir.path}/reciter.png';
    final (rb, rx, ry) = await layerPng((c) => paintReciter(c, look));
    await File(png).writeAsBytes(rb);
    args.addAll(['-loop', '1', '-framerate', '1', '-t', (rd + 1).toStringAsFixed(3), '-i', png]);
    chain.add('[${n + 2 + shifted.length}:v]fps=$fps,trim=duration=${rd.toStringAsFixed(3)},format=rgba,fade=in:st=0:d=${rf.toStringAsFixed(3)}:alpha=1,'
        'fade=out:st=${max(rd - rf, 0).toStringAsFixed(3)}:d=${rf.toStringAsFixed(3)}:alpha=1[rc]');
    chain.add('[$last][rc]overlay=$rx:$ry:eof_action=pass[vr]');
    last = 'vr';
  }
  final out = '${dir.path}/tilawa_${DateTime.now().millisecondsSinceEpoch}.mp4';
  final small = height < 1920;
  if (small) chain.add('[$last]scale=720:1280:flags=lanczos[vout]');
  final common = ['-filter_complex', chain.join(';'), '-map', small ? '[vout]' : '[$last]', '-map', '[aout]', '-t', duration.toStringAsFixed(3)];
  final tail = ['-r', '$fps', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', out];
  // ترميز العتاد (MediaCodec) أسرع بكثير؛ إن لم يدعمه الجوال نرجع إلى x264 السريع
  try {
    await _runAsync([...args, ...common, '-c:v', 'h264_mediacodec', '-b:v', small ? (look.hq ? '10M' : '5M') : (look.hq ? '20M' : '8M'), '-pix_fmt', 'nv12', ...tail], duration, onProgress);
  } catch (_) {
    await _runAsync([...args, ...common, '-c:v', 'libx264', '-preset', look.hq ? 'veryfast' : 'superfast', '-crf', look.hq ? '17' : '22', '-pix_fmt', 'yuv420p', ...tail],
        duration, onProgress);
  }
  return out;
}

Future<void> _runAsync(List<String> args, double duration, void Function(double) onProgress) async {
  final done = Completer<void>();
  await FFmpegKit.executeWithArgumentsAsync(['-y', '-v', 'error', ...args], (session) async {
    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      done.complete();
    } else {
      done.completeError(Exception((await session.getAllLogsAsString()) ?? 'ffmpeg failed'));
    }
  }, null, (stats) => onProgress((stats.getTime() / 1000 / duration).clamp(0, 1)));
  await done.future;
}
