import 'dart:io';
import 'dart:typed_data';

import 'rgba_frame.dart';

/// مشفِّر مضيف للتحقق فقط (ffmpeg على جهاز التطوير/CI). ليس المشفِّر الأصلي
/// (MediaCodec/AVAssetWriter) ولا يُشحن مع التطبيق؛ يثبت منطق التركيب والتزامن
/// وصحة الحاوية H.264+AAC بلا جهاز.
class HostFfmpegEncoder {
  const HostFfmpegEncoder({this.ffmpeg = 'ffmpeg'});

  final String ffmpeg;

  static bool isAvailable() {
    try {
      return Process.runSync('ffmpeg', ['-version']).exitCode == 0 &&
          Process.runSync('ffprobe', ['-version']).exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<void> encode({
    required String outPath,
    required Iterable<RgbaFrame> frames,
    required int width,
    required int height,
    required int fps,
    required Uint8List wavAudio,
  }) async {
    final dir = await Directory.systemTemp.createTemp('rihla_enc_');
    try {
      final wav = File('${dir.path}/a.wav')..writeAsBytesSync(wavAudio);
      final p = await Process.start(ffmpeg, [
        '-y', '-loglevel', 'error',
        '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '${width}x$height',
        '-r', '$fps', '-i', '-',
        '-i', wav.path,
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'ultrafast',
        '-crf', '18', '-g', '$fps', '-r', '$fps',
        '-c:a', 'aac', '-b:a', '128k',
        '-movflags', '+faststart',
        outPath,
      ]);
      final err = p.stderr.transform(const SystemEncoding().decoder).join();
      p.stdout.drain<void>();
      for (final f in frames) {
        p.stdin.add(f.rgba);
      }
      await p.stdin.close();
      final code = await p.exitCode;
      if (code != 0) {
        throw StateError('ffmpeg exit $code: ${await err}');
      }
    } finally {
      await dir.delete(recursive: true);
    }
  }
}
