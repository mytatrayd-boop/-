/// تجربة T0 (ARCHITECTURE §17، D29): تشغيل 20 فقرة من الكتب الخمسة بصوت
/// MMS العربي عبر sherpa_onnx، مع RTF وزمن أول صوت وذروة الذاكرة.
/// تطبيق منفصل عن «الأديب الذكي»؛ لا يمس المشغّل الحالي.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'l10n/app_localizations.dart';
import 'lab_core.dart';
import 'tts_worker.dart';

const _modelAsset = 'assets/model.int8.onnx';
const _tokensAsset = 'assets/tokens.txt';
const _threads = 2;

void main() => runApp(const VoiceLabApp());

class VoiceLabApp extends StatelessWidget {
  const VoiceLabApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (c) => LabLocalizations.of(c).labTitle,
    localizationsDelegates: const [
      LabLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: LabLocalizations.supportedLocales,
    home: const VoiceLabScreen(),
  );
}

enum _Phase { preparing, loading, ready, missing, failed }

class VoiceLabScreen extends StatefulWidget {
  const VoiceLabScreen({super.key});

  @override
  State<VoiceLabScreen> createState() => _VoiceLabScreenState();
}

class _VoiceLabScreenState extends State<VoiceLabScreen> {
  final _player = AudioPlayer();
  final _stats = LabStats();
  var _phase = _Phase.preparing;
  String _error = '';
  List<LabParagraph> _paragraphs = const [];
  TtsWorker? _worker;
  Directory? _tmp;
  int? _baseKb, _peakKb;
  int? _playing;
  var _run = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _run++;
    _worker?.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets();
      if (!assets.contains(_modelAsset) || !assets.contains(_tokensAsset)) {
        setState(() => _phase = _Phase.missing);
        return;
      }
      final books = assets.where((a) => a.endsWith('.json.gz')).toList()
        ..sort();
      final paragraphs = <LabParagraph>[];
      for (final b in books) {
        final bytes = (await rootBundle.load(b)).buffer.asUint8List();
        final json = jsonDecode(utf8.decode(gzip.decode(bytes)));
        paragraphs.addAll(selectLabParagraphs(json as Map<String, Object?>));
      }
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/voice_lab',
      )..createSync(recursive: true);
      _tmp = Directory('${(await getTemporaryDirectory()).path}/voice_lab')
        ..createSync(recursive: true);
      final model = await _copyAsset(_modelAsset, dir);
      final tokens = await _copyAsset(_tokensAsset, dir);

      // الذروة تُقاس من هنا: نصفّر VmHWM بعد نسخ الأصول (Linux clear_refs=5).
      _resetPeak();
      _baseKb = _readKb('VmRSS');
      setState(() {
        _paragraphs = paragraphs;
        _phase = _Phase.loading;
      });
      _worker = await TtsWorker.start(
        model: model,
        tokens: tokens,
        threads: _threads,
      );
      _peakKb = _readKb('VmHWM');
      if (mounted) setState(() => _phase = _Phase.ready);
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.failed;
          _error = '$e';
        });
      }
    }
  }

  Future<String> _copyAsset(String asset, Directory dir) async {
    final data = await rootBundle.load(asset);
    final file = File('${dir.path}/${asset.split('/').last}');
    if (!file.existsSync() || file.lengthSync() != data.lengthInBytes) {
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  void _resetPeak() {
    try {
      File('/proc/self/clear_refs').writeAsStringSync('5');
    } catch (_) {
      // إن لم يُسمح، تبقى الذروة منذ بدء العملية (أعلى من الحقيقية).
    }
  }

  int? _readKb(String key) {
    try {
      return procStatusKb(File('/proc/self/status').readAsStringSync(), key);
    } catch (_) {
      return null;
    }
  }

  Future<void> _playFrom(int start) async {
    final worker = _worker;
    if (worker == null) return;
    final run = ++_run;
    await _player.stop();
    var chunkNo = 0;
    for (var i = start; i < _paragraphs.length; i++) {
      if (run != _run) return;
      setState(() => _playing = i);
      final chunks = labChunks(_paragraphs[i]);
      if (chunks.isEmpty) continue;
      _stats.startParagraph();
      final clock = Stopwatch()..start();
      var next = worker.generate(chunks.first.text);
      for (var c = 0; c < chunks.length; c++) {
        final GeneratedChunk audio;
        try {
          audio = await next;
        } catch (e) {
          if (mounted) setState(() => _error = '$e');
          return;
        }
        if (run != _run) return;
        if (c + 1 < chunks.length) next = worker.generate(chunks[c + 1].text);
        _stats.addChunk(
          generation: audio.generation,
          audioSeconds: audio.seconds,
        );
        final file = File('${_tmp!.path}/chunk_${chunkNo++ % 4}.wav');
        await file.writeAsBytes(encodeWav(audio.samples, audio.sampleRate));
        await _player.setFilePath(file.path);
        if (run != _run) return;
        if (c == 0) _stats.addFirstAudio(clock.elapsed);
        setState(() => _peakKb = _readKb('VmHWM'));
        await _player.play();
        await _player.pause();
        final pause = chunks[c].pauseAfter;
        if (pause > Duration.zero) await Future<void>.delayed(pause);
      }
    }
    if (run == _run && mounted) setState(() => _playing = null);
  }

  Future<void> _stop() async {
    _run++;
    setState(() => _playing = null);
    await _player.stop();
  }

  @override
  Widget build(BuildContext context) {
    final l = LabLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.labTitle)),
      body: switch (_phase) {
        _Phase.preparing => _centered(l.labPreparing, progress: true),
        _Phase.loading => _centered(l.labLoading, progress: true),
        _Phase.missing => _centered(l.labMissingModel),
        _Phase.failed => _centered(l.labError(_error)),
        _Phase.ready => _ready(l),
      },
    );
  }

  Widget _centered(String text, {bool progress = false}) => Center(
    child: Padding(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (progress) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );

  Widget _ready(LabLocalizations l) {
    String f(double? v, int digits) =>
        v == null ? l.labNotMeasured : v.toStringAsFixed(digits);
    String s(Duration? d) => f(d == null ? null : d.inMilliseconds / 1000, 2);
    String mb(int? kb) => f(kb == null ? null : kb / 1024, 0);
    final metrics = [
      (l.labRtf, l.labRtfValue(f(_stats.rtfLast, 2), f(_stats.rtfAll, 2))),
      (
        l.labFirstAudio,
        l.labFirstAudioValue(
          s(_stats.lastFirstAudio),
          s(_stats.worstFirstAudio),
        ),
      ),
      (l.labPeakMemory, l.labPeakMemoryValue(mb(_peakKb), mb(_baseKb))),
      (l.labModelLoad, l.labModelLoadValue(s(_worker?.loadTime), _threads)),
    ];
    return Column(
      children: [
        Card(
          margin: const EdgeInsetsDirectional.all(12),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value) in metrics)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$label: ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: value),
                        ],
                      ),
                    ),
                  ),
                if (_error.isNotEmpty)
                  Text(
                    l.labError(_error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _playing == null ? () => _playFrom(0) : _stop,
                  icon: Icon(_playing == null ? Icons.play_arrow : Icons.stop),
                  label: Text(_playing == null ? l.labPlayAll : l.labStop),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _paragraphs.length,
            itemBuilder: (context, i) {
              final p = _paragraphs[i];
              return ListTile(
                selected: _playing == i,
                leading: Icon(
                  _playing == i ? Icons.volume_up : Icons.play_circle_outline,
                ),
                title: Text(
                  l.labParagraphNumber(
                    p.bookTitle,
                    p.number,
                    p.kind == 'verse' ? l.labVerse : l.labProse,
                  ),
                ),
                subtitle: Text(
                  p.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
                onTap: () => _playFrom(i),
              );
            },
          ),
        ),
      ],
    );
  }
}
