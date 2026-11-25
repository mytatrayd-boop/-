import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import '../core/app_failure.dart';
import '../domain/models/now_playing.dart';
import '../domain/ports/audio_source_resolver.dart';
import '../domain/ports/playback_controller.dart';
import 'audio_engine.dart';
import 'playback_state_mapper.dart';

/// معالج الصوت: يلفّ المشغّل ويعرضه عبر audio_service
/// (خدمة مقدّمة + إشعار + شاشة قفل). يعتمد على المنفذ `AudioSourceResolver` فقط.
class BgtubeAudioHandler extends BaseAudioHandler with SeekHandler implements PlaybackController {
  BgtubeAudioHandler({required this._resolver, AudioEngine? engine})
      : _player = engine ?? JustAudioEngine() {
    _player.playbackEventStream.listen(
      (event) {
        if (event.processingState == ProcessingState.ready) _autoRetried = false;
        playbackState.add(toPlaybackState(
          event: event,
          playing: _player.playing,
          speed: _player.speed,
        ));
      },
      onError: _onPlayerError,
    );
    _player.playingStream.listen((p) => playing.value = p);
  }

  final AudioSourceResolver _resolver;
  final AudioEngine _player;

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

  /// موضع البدء/الاستئناف للفيديو الحالي (صفر للجديد).
  Duration _resumeFrom = Duration.zero;

  /// true بعد نجاح تحميل مصدر الفيديو الحالي في المشغّل.
  bool _loaded = false;

  /// يبدأ تشغيل فيديو. الفشل لا يُرمى؛ يُنشر في [failure].
  @override
  Future<void> playVideo(String videoId) {
    _autoRetried = false;
    _resumeFrom = Duration.zero;
    return _load(videoId);
  }

  /// يعيد المحاولة لآخر فيديو (يحافظ على الموضع إن كان قد بدأ).
  @override
  Future<void> retry() {
    final id = _videoId;
    if (id == null) return Future.value();
    _autoRetried = false;
    _captureResume();
    return _load(id);
  }

  /// يحفظ موضع المشغّل إن كان مصدر الفيديو الحالي محمّلاً (قبل أي إيقاف).
  void _captureResume() {
    if (_loaded) _resumeFrom = _player.position;
  }

  Future<void> _load(String videoId) async {
    final token = ++_token;
    _videoId = videoId;
    _loaded = false;
    failure.value = null;
    resolving.value = true;
    // أوقف الصوت القديم فوراً قبل حلّ الجديد.
    await _player.stop();
    if (token != _token) return;
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
      await _player.setUrl(audio.url, initialPosition: _resumeFrom);
      if (token != _token) return;
      _loaded = true;
      resolving.value = false;
      await _player.play();
    } on AppFailure catch (e) {
      if (token == _token) await _fail(e);
    } catch (e) {
      // خطأ من المشغّل أثناء التحميل: يُعالَج هنا لا من تيار الأحداث (انظر _onPlayerError).
      if (token == _token) await _handleEngineError(token, e);
    }
  }

  Future<void> _fail(AppFailure f) async {
    _captureResume();
    _token++; // أي نتيجة متأخرة تُتجاهل
    resolving.value = false;
    failure.value = f;
    await _player.stop(); // لا يبقى صوت الفيديو القديم
    _loaded = false;
  }

  /// خطأ مشغّل: محاولة تلقائية واحدة بحلّ جديد، ثم فشل ظاهر.
  Future<void> _handleEngineError(int token, Object error) async {
    if (token != _token) return;
    final id = _videoId;
    if (id != null && !_autoRetried) {
      _autoRetried = true;
      _captureResume();
      await _load(id);
    } else {
      await _fail(AppFailure(FailureKind.playbackFailed, error.runtimeType.toString()));
    }
  }

  /// خطأ من تيار الأحداث. أثناء التحميل يلتقطه `_load` نفسه (يرمي setUrl أيضاً)،
  /// فيُتجاهل هنا لمنع معالجته مرتين.
  void _onPlayerError(Object error, StackTrace _) {
    if (resolving.value || _videoId == null) return;
    _handleEngineError(_token, error);
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
    _videoId = null;
    _loaded = false;
    resolving.value = false;
    failure.value = null;
    nowPlaying.value = null;
    await _player.stop();
    await super.stop();
  }

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  Future<void> dispose() async {
    await _player.dispose();
  }
}
