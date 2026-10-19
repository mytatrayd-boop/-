// الوسائط عبر FFmpeg: قراءة الصوت للتعرف، وصورة مصغّرة للفيديو، وإنتاج الفيديو النهائي.
// سلسلة المرشحات منقولة من engine/render.py المختبر.
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';

import 'look.dart';
import 'sync.dart';

const fps = 30;

class Bg {
  final String path, name;
  final bool video;
  String? thumb; // صورة للمعاينة (للفيديو)
  Bg(this.path, this.name, {this.video = false, this.thumb});
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

(List<String>, String) _clip(Bg bg, double len, bool zoom) {
  if (!bg.video) {
    final args = ['-loop', '1', '-framerate', '$fps', '-t', len.toStringAsFixed(3), '-i', bg.path];
    final frames = (len * fps).ceil() + 1;
    final f = zoom
        ? 'scale=1350:2400:force_original_aspect_ratio=increase,crop=1350:2400,'
            "zoompan=z='1+0.08*on/$frames':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1080x1920:fps=$fps"
        : 'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=$fps';
    return (args, f);
  }
  return (
    ['-stream_loop', '-1', '-t', len.toStringAsFixed(3), '-i', bg.path],
    'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps=$fps'
  );
}

/// ينتج الفيديو: segs بأوقات مطلقة في الصوت، ويؤخذ من الصوت [trimStart, trimEnd].
Future<String> renderVideo({
  required String audio,
  required List<Segment> segs,
  required List<String> texts, // نصوص المقاطع مرمّزة لخط المجمع
  required List<Bg> bgs,
  required Look look,
  required String? headerName,
  required String? headerBasmala,
  required double trimStart,
  required double trimEnd,
  required void Function(double) onProgress,
}) async {
  final dir = await workDir();
  final duration = trimEnd - trimStart;
  final shifted = <(Segment, String)>[];
  for (var i = 0; i < segs.length; i++) {
    final s = max(segs[i].start, trimStart) - trimStart, e = min(segs[i].end, trimEnd) - trimStart;
    if (e - s > 0.2) shifted.add((Segment(segs[i].text, s, e), texts[i]));
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
  final post = [if (look.blur > 0) 'gblur=sigma=${look.blur.toStringAsFixed(1)}', if (look.dim > 0) 'drawbox=c=black@${look.dim.toStringAsFixed(2)}:t=fill'];
  chain.add('[$cur]${post.isEmpty ? 'null' : post.join(',')},format=yuv420p[bg]');

  final n = points.length;
  args.addAll(['-ss', trimStart.toStringAsFixed(3), '-t', duration.toStringAsFixed(3), '-i', audio]);
  final head = '${dir.path}/header.png';
  await File(head).writeAsBytes(await layerPng((c) => paintHeader(c, headerName, headerBasmala, look)));
  args.addAll(['-loop', '1', '-framerate', '$fps', '-t', duration.toStringAsFixed(3), '-i', head]);
  chain.add('[bg][${n + 1}:v]overlay=0:0[v0]');
  for (var i = 0; i < shifted.length; i++) {
    final (g, text) = shifted[i];
    final png = '${dir.path}/seg_$i.png';
    await File(png).writeAsBytes(await layerPng((c) => paintText(c, text, look)));
    final d = g.end - g.start, f = min(look.fade, d / 3);
    args.addAll(['-loop', '1', '-framerate', '$fps', '-t', d.toStringAsFixed(3), '-i', png]);
    chain.add('[${i + n + 2}:v]format=rgba,fade=in:st=0:d=${f.toStringAsFixed(3)}:alpha=1,'
        'fade=out:st=${max(d - f, 0).toStringAsFixed(3)}:d=${f.toStringAsFixed(3)}:alpha=1,'
        'setpts=PTS+${g.start.toStringAsFixed(3)}/TB[t$i]');
    chain.add('[v$i][t$i]overlay=0:0:eof_action=pass[v${i + 1}]');
  }
  final out = '${dir.path}/tilawa_${DateTime.now().millisecondsSinceEpoch}.mp4';
  args.addAll([
    '-filter_complex', chain.join(';'), '-map', '[v${shifted.length}]', '-map', '$n:a',
    '-t', duration.toStringAsFixed(3), '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '21',
    '-pix_fmt', 'yuv420p', '-r', '$fps', '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', out,
  ]);
  final done = Completer<void>();
  await FFmpegKit.executeWithArgumentsAsync(['-y', '-v', 'error', ...args], (session) async {
    if (ReturnCode.isSuccess(await session.getReturnCode())) {
      done.complete();
    } else {
      done.completeError(Exception((await session.getAllLogsAsString()) ?? 'ffmpeg failed'));
    }
  }, null, (stats) => onProgress((stats.getTime() / 1000 / duration).clamp(0, 1)));
  await done.future;
  return out;
}
