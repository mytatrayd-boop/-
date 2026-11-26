import 'package:just_audio/just_audio.dart';

/// واجهة رفيعة على المشغّل الصوتي لتسهيل الاختبار بمشغّل وهمي.
abstract interface class AudioEngine {
  Stream<PlaybackEvent> get playbackEventStream;
  Stream<bool> get playingStream;
  Stream<Duration> get positionStream;
  bool get playing;
  double get speed;
  Duration get position;

  /// [headers] تُرسل مع طلبات الصوت عبر وكيل just_audio المحلي (D26).
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
  // useProxyForRequestHeaders: true (الافتراضي): ExoPlayer يطلب من وكيل just_audio
  // على 127.0.0.1، والوكيل يجلب من googlevideo عبر HttpClient في Dart (المكدّس
  // الذي نجح فحصه على الجهاز بـ206، بينما فشل ExoPlayer المباشر، D26). يمرّر
  // Range وترويسات ExoPlayer ثم ترويساتنا فوقها. يتطلب network_security_config
  // يسمح بـcleartext لـ127.0.0.1/localhost فقط.
  JustAudioEngine([AudioPlayer? player]) : _p = player ?? AudioPlayer(useProxyForRequestHeaders: true);
  final AudioPlayer _p;

  @override
  Stream<PlaybackEvent> get playbackEventStream => _p.playbackEventStream;
  @override
  Stream<bool> get playingStream => _p.playingStream;
  @override
  Stream<Duration> get positionStream => _p.positionStream;
  @override
  bool get playing => _p.playing;
  @override
  double get speed => _p.speed;
  @override
  Duration get position => _p.position;

  @override
  Future<void> setUrl(Uri url, {required Duration initialPosition, Map<String, String> headers = const {}}) async {
    await _p.setAudioSource(
      proxiedSource(url, headers),
      initialPosition: initialPosition,
    );
  }

  @override
  Future<void> play() => _p.play();
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> seek(Duration position) => _p.seek(position);
  @override
  Future<void> setSpeed(double speed) => _p.setSpeed(speed);
  @override
  Future<void> setVolume(double volume) => _p.setVolume(volume);
  @override
  Future<void> dispose() => _p.dispose();
}

/// مصدر يمر دائماً عبر الوكيل المحلي: just_audio يستعمل الوكيل فقط إن كانت
/// headers غير null، فنمرّر خريطة (ولو فارغة) دائماً لروابط http(s).
UriAudioSource proxiedSource(Uri url, Map<String, String> headers) =>
    AudioSource.uri(url, headers: Map<String, String>.of(headers));
