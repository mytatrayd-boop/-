import 'package:just_audio/just_audio.dart';

import 'yt_stream_audio_source.dart';

/// واجهة رفيعة على المشغّل الصوتي لتسهيل الاختبار بمشغّل وهمي.
abstract interface class AudioEngine {
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;

  /// مدة المصدر الحالي كما يعرفها المشغّل (null قبل التحميل).
  Stream<Duration?> get durationStream;
  bool get playing;
  double get speed;
  Duration get position;

  /// يحمّل [url]. كل طلبات البايتات تمر عبر Dart بترويسات [headers] كما هي (D26).
  Future<void> setUrl(Uri url, {required Duration initialPosition, Map<String, String> headers = const {}});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

/// يبني مصدر الصوت لرابط وترويسات (قابل للحقن في الاختبار).
typedef YtSourceFactory = YtStreamAudioSource Function(Uri url, Map<String, String> headers);

YtStreamAudioSource defaultYtSource(Uri url, Map<String, String> headers) =>
    YtStreamAudioSource(url, Map<String, String>.unmodifiable(headers));

class JustAudioEngine implements AudioEngine {
  // لا نستعمل AudioSource.uri: ExoPlayer المباشر فشل على الجهاز (probe 206 من
  // Dart)، ووكيل just_audio للروابط يكتب User-Agent الخاص بـdart:io فوق
  // ترويساتنا. بدلاً منهما YtStreamAudioSource: الوكيل المحلي يمرّر Range إلى
  // request() ونحن نجلب بأنفسنا (D26).
  JustAudioEngine({AudioPlayer? player, YtSourceFactory? sourceFactory})
      : _p = player ?? AudioPlayer(),
        _sourceFactory = sourceFactory ?? defaultYtSource;

  final AudioPlayer _p;
  final YtSourceFactory _sourceFactory;
  YtStreamAudioSource? _current;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _p.playbackEventStream;
  @override
  Stream<bool> get playingStream => _p.playingStream;
  @override
  Stream<Duration> get positionStream => _p.positionStream;
  @override
  Stream<Duration?> get durationStream => _p.durationStream;
  @override
  bool get playing => _p.playing;
  @override
  double get speed => _p.speed;
  @override
  Duration get position => _p.position;

  @override
  Future<void> setUrl(Uri url, {required Duration initialPosition, Map<String, String> headers = const {}}) async {
    _closeCurrent(); // يُلغي طلبات المصدر السابق
    final source = _sourceFactory(url, headers);
    _current = source;
    await _p.setAudioSource(source, initialPosition: initialPosition);
  }

  void _closeCurrent() {
    try {
      _current?.close();
    } finally {
      _current = null;
    }
  }

  @override
  Future<void> play() => _p.play();
  @override
  Future<void> pause() => _p.pause();
  // لا نغلق المصدر عند stop: just_audio يعيد تفعيله إن طُلب play بعدها؛ يُغلق
  // عند تبديل المصدر أو التخلص من المشغّل.
  @override
  Future<void> stop() => _p.stop();

  @override
  Future<void> seek(Duration position) => _p.seek(position);
  @override
  Future<void> setSpeed(double speed) => _p.setSpeed(speed);
  @override
  Future<void> setVolume(double volume) => _p.setVolume(volume);
  @override
  Future<void> dispose() async {
    _closeCurrent();
    await _p.dispose();
  }
}
