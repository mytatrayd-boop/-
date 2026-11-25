import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_failure.dart';
import '../domain/models/now_playing.dart';
import '../domain/ports/audio_source_resolver.dart';
import '../domain/ports/playback_controller.dart';
import 'playback_state_mapper.dart';

/// معالج الصوت: يلفّ just_audio ويعرضه عبر audio_service
/// (خدمة مقدّمة + إشعار + شاشة قفل). يعتمد على المنفذ `AudioSourceResolver` فقط.
class BgtubeAudioHandler extends BaseAudioHandler with SeekHandler implements PlaybackController {
  BgtubeAudioHandler({required this._resolver, AudioPlayer? player})
      : _player = player ?? AudioPlayer() {
    _player.playbackEventStream.listen(
      (event) => playbackState.add(toPlaybackState(
        event: event,
        playing: _player.playing,
        speed: _player.speed,
      )),
      onError: _onPlayerError,
    );
    _player.playingStream.listen((p) => playing.value = p);
  }

  final AudioSourceResolver _resolver;
  final AudioPlayer _player;

  /// آخر فشل (null = لا فشل). الواجهة تعرضه مع زر إعادة المحاولة.
  @override
  final ValueNotifier<AppFailure?> failure = ValueNotifier(null);

  /// true أثناء حلّ الرابط وتحميله.
  @override
  final ValueNotifier<bool> resolving = ValueNotifier(false);

  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);

  @override
  final ValueNotifier<NowPlaying?> nowPlaying = ValueNotifier(null);

  String? _videoId;
  int _token = 0;
  bool _autoRetried = false;

  /// يبدأ تشغيل فيديو. الفشل لا يُرمى؛ يُنشر في [failure].
  @override
  Future<void> playVideo(String videoId) {
    _autoRetried = false;
    return _load(videoId, start: Duration.zero);
  }

  /// يعيد المحاولة لآخر فيديو (يحافظ على الموضع).
  @override
  Future<void> retry() {
    final id = _videoId;
    if (id == null) return Future.value();
    return _load(id, start: _player.position);
  }

  Future<void> _load(String videoId, {required Duration start}) async {
    final token = ++_token;
    _videoId = videoId;
    failure.value = null;
    resolving.value = true;
    try {
      final audio = await _resolver.resolve(videoId);
      if (token != _token) return; // طلب أحدث حلّ محلّه
      nowPlaying.value = NowPlaying(
        videoId: videoId,
        title: audio.title,
        author: audio.author,
        duration: audio.duration,
      );
      mediaItem.add(MediaItem(
        id: videoId,
        title: audio.title,
        artist: audio.author,
        duration: audio.duration,
        artUri: audio.thumbnailUrl == null ? null : Uri.tryParse(audio.thumbnailUrl!),
      ));
      await _player.setAudioSource(AudioSource.uri(audio.url), initialPosition: start);
      if (token != _token) return;
      resolving.value = false;
      await _player.play();
    } on AppFailure catch (e) {
      if (token == _token) _fail(e);
    } catch (e) {
      if (token == _token) _fail(AppFailure(FailureKind.playbackFailed, e.runtimeType.toString()));
    }
  }

  void _fail(AppFailure f) {
    resolving.value = false;
    failure.value = f;
  }

  /// خطأ من المشغّل (غالباً انتهاء الرابط): محاولة تلقائية واحدة بحلّ جديد.
  void _onPlayerError(Object error, StackTrace _) {
    final id = _videoId;
    if (id != null && !_autoRetried) {
      _autoRetried = true;
      _load(id, start: _player.position);
    } else {
      _fail(AppFailure(FailureKind.playbackFailed, error.runtimeType.toString()));
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    _token++;
    resolving.value = false;
    await _player.stop();
    await super.stop();
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  Future<void> dispose() async {
    await _player.dispose();
  }
}
