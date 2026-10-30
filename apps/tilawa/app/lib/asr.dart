// التعرف الصوتي بنموذج Whisper المدرّب على القرآن (sherpa-onnx) في خيط منفصل، بكل أنوية المعالج.
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as so;

const _files = ['tiny-encoder.int8.onnx', 'tiny-decoder.int8.onnx', 'tiny-tokens.txt'];

class Asr {
  final SendPort _send;
  Asr._(this._send);

  /// ينسخ ملفات النموذج من التطبيق إلى مجلده (sherpa يحتاج مسارات ملفات) ثم يشغّل الخيط.
  static Future<Asr> start() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/model')..createSync(recursive: true);
    for (final f in _files) {
      final out = File('${dir.path}/$f');
      if (!out.existsSync()) {
        final data = await rootBundle.load('assets/model/$f');
        await out.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
    }
    final ready = ReceivePort();
    await Isolate.spawn(_worker, [ready.sendPort, dir.path, max(1, min(4, Platform.numberOfProcessors))]);
    return Asr._(await ready.first as SendPort);
  }

  Future<String> transcribe(Float32List audio) async {
    final reply = ReceivePort();
    _send.send([TransferableTypedData.fromList([audio]), reply.sendPort]);
    final text = await reply.first as String;
    reply.close();
    return text;
  }
}

void _worker(List args) {
  so.initBindings();
  final dir = args[1] as String;
  final rec = so.OfflineRecognizer(so.OfflineRecognizerConfig(
    model: so.OfflineModelConfig(
      whisper: so.OfflineWhisperModelConfig(
          encoder: '$dir/${_files[0]}', decoder: '$dir/${_files[1]}', language: 'ar', task: 'transcribe'),
      tokens: '$dir/${_files[2]}',
      numThreads: args[2] as int,
      debug: false,
    ),
  ));
  final port = ReceivePort();
  (args[0] as SendPort).send(port.sendPort);
  port.listen((m) {
    final a = (m[0] as TransferableTypedData).materialize().asFloat32List();
    // النموذج يتأخر في كتابة آخر الكلام: 8 ث صمت بعده حتى يكمله
    final padded = Float32List(a.length + 8 * 16000)..setAll(0, a);
    final s = rec.createStream();
    s.acceptWaveform(samples: padded, sampleRate: 16000);
    rec.decode(s);
    final text = rec.getResult(s).text;
    s.free();
    (m[1] as SendPort).send(text);
  });
}
