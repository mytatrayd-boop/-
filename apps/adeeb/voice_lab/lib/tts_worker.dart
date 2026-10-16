/// توليد الصوت بـ sherpa_onnx في Isolate دائم، فلا تتجمد الواجهة ويُولَّد
/// المقطع التالي أثناء تشغيل الحالي (ARCHITECTURE §17.3).
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class GeneratedChunk {
  const GeneratedChunk(this.samples, this.sampleRate, this.generation);

  final Float32List samples;
  final int sampleRate;
  final Duration generation;

  double get seconds => sampleRate == 0 ? 0 : samples.length / sampleRate;
}

class TtsWorker {
  TtsWorker._(this._isolate, this._commands, this._replies, this.loadTime);

  final Isolate _isolate;
  final SendPort _commands;
  final StreamIterator<Object?> _replies;
  final Duration loadTime;
  Future<void> _queue = Future.value();

  static Future<TtsWorker> start({
    required String model,
    required String tokens,
    required int threads,
  }) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(_main, [
      port.sendPort,
      model,
      tokens,
      threads,
    ]);
    final replies = StreamIterator<Object?>(port);
    await replies.moveNext();
    final first = replies.current;
    if (first is String) {
      isolate.kill();
      throw StateError(first);
    }
    final ready = first! as List<Object?>;
    return TtsWorker._(
      isolate,
      ready[0]! as SendPort,
      replies,
      Duration(microseconds: ready[1]! as int),
    );
  }

  /// يولّد [text]؛ الطلبات تُنفَّذ بالترتيب.
  Future<GeneratedChunk> generate(String text) {
    final result = _queue.then((_) async {
      _commands.send(text);
      await _replies.moveNext();
      final r = _replies.current;
      if (r is String) throw StateError(r);
      final l = r! as List<Object?>;
      return GeneratedChunk(
        (l[0]! as TransferableTypedData).materialize().asFloat32List(),
        l[1]! as int,
        Duration(microseconds: l[2]! as int),
      );
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  void dispose() => _isolate.kill(priority: Isolate.immediate);
}

void _main(List<Object?> args) {
  final reply = args[0]! as SendPort;
  final sherpa.OfflineTts tts;
  final sw = Stopwatch()..start();
  try {
    sherpa.initBindings();
    tts = sherpa.OfflineTts(
      sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: args[1]! as String,
            tokens: args[2]! as String,
          ),
          numThreads: args[3]! as int,
          debug: false,
        ),
      ),
    );
  } catch (e) {
    reply.send('$e');
    return;
  }
  final commands = ReceivePort();
  reply.send([commands.sendPort, sw.elapsedMicroseconds]);
  commands.listen((message) {
    try {
      final t = Stopwatch()..start();
      final audio = tts.generate(text: message! as String);
      reply.send([
        TransferableTypedData.fromList([audio.samples]),
        audio.sampleRate,
        t.elapsedMicroseconds,
      ]);
    } catch (e) {
      reply.send('$e');
    }
  });
}
