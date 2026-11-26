import 'package:just_audio/just_audio.dart';

import 'local_stream_proxy.dart';

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

  /// يحمّل [url]. كل طلبات البايتات تمر عبر وكيلنا المحلي بترويسات [headers] كما هي (D26).
  Future<void> setUrl(Uri url, {required Duration initialPosition, Map<String, String> headers = const {}});
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  // لا نعطي ExoPlayer رابط googlevideo مباشرة (فشل على الجهاز، D26)، ولا نستعمل
  // وكيل just_audio (لا ضغط عكسي فيُنزَّل الملف كله إلى الذاكرة، ويكتب UA الخاص
  // بـdart:io، وفيه أخطاء غير معالجة). بدلاً منهما وكيلنا [LocalStreamProxy]:
  // ExoPlayer ← http://127.0.0.1:port/<token> ← fetchRange بترويسات العميل.
  JustAudioEngine({AudioPlayer? player, LocalStreamProxy? proxy})
      : _p = player ?? AudioPlayer(useProxyForRequestHeaders: false),
        _proxy = proxy ?? LocalStreamProxy();

  final AudioPlayer _p;
  final LocalStreamProxy _proxy;
  ProxiedStream? _current;

  /// المصدر المحمَّل حالياً في الوكيل (للاختبار والتشخيص).
  ProxiedStream? get currentStream => _current;

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
    await _proxy.start();
    // بعد await: الأحدث يغلق ما قبله، فلا يتسرّب مصدر عند setUrl متزامن.
    _closeCurrent(); // يقطع طلبات المصدر السابق ويُزيل مساره
    final stream = _proxy.register(url, headers);
    _current = stream;
    // بلا headers: لا يُفعَّل وكيل just_audio؛ UA العميل يرسله وكيلنا إلى الأصل.
    await _p.setAudioSource(AudioSource.uri(stream.localUri), initialPosition: initialPosition);
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
    await _proxy.close();
    await _p.dispose();
  }
}
