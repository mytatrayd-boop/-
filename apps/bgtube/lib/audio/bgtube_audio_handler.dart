import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import '../core/app_failure.dart';
import '../domain/models/now_playing.dart';
import '../domain/models/resolved_audio.dart';
import '../domain/models/playback_position.dart';
import '../domain/playback_speed.dart';
import '../domain/position_policy.dart';
import '../domain/sleep_timer.dart';
import '../domain/ports/audio_source_resolver.dart';
import '../domain/ports/playback_controller.dart';
import '../domain/ports/position_repository.dart';
import '../domain/ports/speed_store.dart';
import 'audio_engine.dart';
import 'playback_diagnostics.dart';
import 'playback_state_mapper.dart';

/// معالج الصوت: يلفّ المشغّل ويعرضه عبر audio_service
/// (خدمة مقدّمة + إشعار + شاشة قفل). يعتمد على المنفذ `AudioSourceResolver` فقط.
class BgtubeAudioHandler extends BaseAudioHandler with SeekHandler implements PlaybackController {
  BgtubeAudioHandler({
    required this._resolver,
    AudioEngine? engine,
    this._positions,
    this._speedStore,
    this._saveInterval = const Duration(seconds: 5),
    this._probe,
  }) : _player = engine ?? JustAudioEngine() {
    _restoreSpeed();
    _player.playbackEventStream.listen(
      (event) {
        if (event.processingState == ProcessingState.ready) _autoRetried = false;
        if (event.processingState == ProcessingState.completed) _onCompleted();
        playbackState.add(toPlaybackState(
          event: event,
          playing: _player.playing,
          speed: _player.speed,
        ));
      },
      onError: _onPlayerError,
    );
    _player.playingStream.listen((p) {
      playing.value = p;
      if (p) {
        _saveTimer ??= Timer.periodic(_saveInterval, (_) => _savePosition());
      } else {
        _saveTimer?.cancel();
        _saveTimer = null;
        _savePosition(); // إيقاف مؤقت/مقاطعة
      }
    });
  }

  final PositionRepository? _positions;
  final SpeedStore? _speedStore;
  final Duration _saveInterval;

  /// فحص الرابط عند فشل التشغيل النهائي (للتشخيص فقط). null = بلا فحص.
  final StreamProbe? _probe;

  /// آخر مصدر محلول (للتشخيص).
  ResolvedAudio? _lastAudio;
  Timer? _saveTimer;

  final AudioSourceResolver _resolver;
  final AudioEngine _player;

  /// آخر فشل (null = لا فشل). الواجهة تعرضه مع زر إعادة المحاولة.
  @override
  final ValueNotifier<AppFailure?> failure = ValueNotifier(null);

  /// true أثناء حلّ الرابط وتحميله.
  @override
  final ValueNotifier<bool> resolving = ValueNotifier(false);

  @override
  final ValueNotifier<double> speed = ValueNotifier(defaultPlaybackSpeed);

  /// true بعد أن اختار المستخدم سرعة؛ يمنع قراءة التخزين المتأخرة من تجاوز اختياره.
  bool _speedTouched = false;

  Future<void> _restoreSpeed() async {
    try {
      final saved = normalizeSpeed(await _speedStore?.load());
      if (_speedTouched) return;
      await _applySpeed(saved);
    } catch (e) {
      debugPrint('speed restore failed: ${e.runtimeType}');
    }
  }

  Future<void> _applySpeed(double s) async {
    speed.value = s;
    await _player.setSpeed(s);
    // انعكاس فوري على الإشعار وشاشة القفل.
    playbackState.add(playbackState.value.copyWith(speed: s));
  }

  /// يغيّر السرعة (تعمل في الخلفية وتنعكس على الإشعار) ويحفظها للفيديو التالي.
  /// قيمة غير مسموحة تُقرَّب إلى المسموح. فشل الحفظ لا يمنع التطبيق.
  @override
  Future<void> setSpeed(double value) async {
    final s = normalizeSpeed(value);
    _speedTouched = true;
    await _applySpeed(s);
    try {
      await _speedStore?.save(s);
    } catch (e) {
      debugPrint('speed save failed: ${e.runtimeType}');
    }
  }

  @override
  final ValueNotifier<Duration?> sleepRemaining = ValueNotifier(null);

  static const _sleepTick = Duration(milliseconds: 250);
  Timer? _sleepTimer;
  Duration _sleepLeft = Duration.zero;

  /// وقت الانتهاء المطلق؛ المتبقي يُحسب منه عند كل نبضة فلا يطول المؤقت
  /// إن تأخرت النبضات (Doze/ازدحام).
  DateTime _sleepEnd = DateTime.fromMillisecondsSinceEpoch(0);

  /// انتهى المؤقت أثناء تحميل فيديو (playing ما زال false): لا نبدأ التشغيل
  /// بعد اكتمال التحميل.
  bool _sleepExpiredWhileLoading = false;

  /// مؤقت النوم يعمل هنا داخل المعالج (خدمة مقدّمة) فيستمر والشاشة مغلقة.
  /// العدّ بعدد النبضات لا بالساعة. يبقى فعّالاً عند تبديل الفيديو أو الإيقاف
  /// المؤقت اليدوي، ويُلغى عند stop() أو cancelSleepTimer().
  @override
  void startSleepTimer(Duration duration) {
    if (duration <= Duration.zero) return;
    _sleepTimer?.cancel();
    _sleepExpiredWhileLoading = false;
    _sleepEnd = clock.now().add(duration);
    _sleepLeft = duration;
    _publishSleepRemaining();
    _sleepTimer = Timer.periodic(_sleepTick, (_) => _onSleepTick());
    _player.setVolume(1.0);
  }

  @override
  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining.value = null;
    _player.setVolume(1.0); // يلغي أي تلاشٍ جارٍ
  }

  void _publishSleepRemaining() {
    final secs = (_sleepLeft.inMilliseconds / 1000).ceil();
    final d = Duration(seconds: secs);
    if (sleepRemaining.value != d) sleepRemaining.value = d;
  }

  void _onSleepTick() {
    _sleepLeft = _sleepEnd.difference(clock.now());
    if (_sleepLeft <= Duration.zero) {
      _finishSleep();
      return;
    }
    _publishSleepRemaining();
    if (_sleepLeft <= sleepFadeDuration) {
      _player.setVolume(_sleepLeft.inMilliseconds / sleepFadeDuration.inMilliseconds);
    }
  }

  Future<void> _finishSleep() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining.value = null;
    if (resolving.value) _sleepExpiredWhileLoading = true;
    try {
      if (_player.playing) await _player.pause();
      await _savePosition();
    } finally {
      // الصوت يعود كاملاً ليعمل الاستئناف اليدوي بصوت عادي.
      await _player.setVolume(1.0);
    }
  }

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
  Future<void> playVideo(String videoId) async {
    _autoRetried = false;
    _sleepExpiredWhileLoading = false; // طلب تشغيل جديد من المستخدم
    _resumeFrom = Duration.zero;
    final token = _token;
    await _savePosition(); // موضع الفيديو السابق قبل استبداله
    // stop() (أو طلب أحدث) أثناء الحفظ: لا نبدأ تشغيلاً بعد إيقاف المستخدم.
    if (token != _token) return;
    return _load(videoId, resumeSaved: true);
  }

  /// يحفظ/يحذف موضع الفيديو الحالي حسب [PositionPolicy]. لا يرمي أبداً:
  /// فشل التخزين لا يكسر التشغيل.
  Future<void> _savePosition() async {
    final repo = _positions;
    final id = _videoId;
    if (repo == null || id == null || !_loaded) return;
    final position = _player.position;
    final duration = nowPlaying.value?.duration;
    try {
      switch (PositionPolicy.decide(position, duration)) {
        case PositionAction.save:
          await repo.save(PlaybackPosition(
            videoId: id,
            position: position,
            duration: duration ?? Duration.zero,
            updatedAt: DateTime.now(),
          ));
        case PositionAction.delete:
          await repo.delete(id);
        case PositionAction.skip:
          break;
      }
    } catch (e) {
      debugPrint('position save failed: ${e.runtimeType}');
    }
  }

  /// انتهى الفيديو: لا استئناف في المرة القادمة.
  void _onCompleted() {
    _saveTimer?.cancel(); // لا حفظ دوري بعد الانتهاء
    _saveTimer = null;
    final repo = _positions;
    final id = _videoId;
    if (repo == null || id == null) return;
    repo.delete(id).catchError((Object _) {});
  }

  Future<Duration> _savedPosition(String videoId) async {
    try {
      final saved = await _positions?.get(videoId);
      return saved?.position ?? Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// يعيد المحاولة لآخر فيديو (يحافظ على الموضع إن كان قد بدأ).
  @override
  Future<void> retry() {
    final id = _videoId;
    if (id == null) return Future.value();
    _autoRetried = false;
    _sleepExpiredWhileLoading = false;
    _captureResume();
    return _load(id);
  }

  /// يحفظ موضع المشغّل إن كان مصدر الفيديو الحالي محمّلاً (قبل أي إيقاف).
  void _captureResume() {
    if (_loaded) _resumeFrom = _player.position;
  }

  Future<void> _load(String videoId, {bool resumeSaved = false}) async {
    final token = ++_token;
    _videoId = videoId;
    _loaded = false;
    _lastAudio = null;
    failure.value = null;
    resolving.value = true;
    // أوقف الصوت القديم فوراً قبل حلّ الجديد.
    await _player.stop();
    if (token != _token) return;
    if (resumeSaved) {
      _resumeFrom = await _savedPosition(videoId);
      if (token != _token) return;
    }
    try {
      final audio = await _resolver.resolve(videoId);
      if (token != _token) return; // طلب أحدث حلّ محلّه
      _lastAudio = audio;
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
      await _player.setUrl(audio.url, initialPosition: _resumeFrom, headers: audio.httpHeaders);
      if (token != _token) return;
      await _player.setSpeed(speed.value); // السرعة المختارة للفيديو الجديد
      if (token != _token) return;
      _loaded = true;
      resolving.value = false;
      if (_sleepExpiredWhileLoading) {
        // انتهى مؤقت النوم أثناء التحميل: يبقى محمّلاً ومتوقفاً (الاستئناف يدوي).
        _sleepExpiredWhileLoading = false;
        await _player.setVolume(1.0);
        return;
      }
      await _player.play();
    } on AppFailure catch (e) {
      if (token == _token) await _fail(e);
    } catch (e) {
      // خطأ من المشغّل أثناء التحميل: يُعالَج هنا لا من تيار الأحداث (انظر _onPlayerError).
      if (token == _token) await _handleEngineError(token, e);
    }
  }

  Future<void> _fail(AppFailure f) async {
    await _savePosition();
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
      // الفشل يظهر فوراً؛ الفحص (حتى 6 ث) يُكمل السطر التشخيصي لاحقاً (D26).
      final audio = _lastAudio;
      final shown = AppFailure(FailureKind.playbackFailed, _playbackDetail(error, audio, null));
      await _fail(shown);
      unawaited(_enrichWithProbe(shown, error, audio));
    }
  }

  /// يضيف نتيجة الفحص إلى الفشل المعروض إن بقي هو نفسه المعروض.
  Future<void> _enrichWithProbe(AppFailure shown, Object error, ResolvedAudio? audio) async {
    final probe = _probe;
    if (probe == null || audio == null) return;
    String result;
    try {
      result = await probe(audio.url, audio.httpHeaders);
    } catch (e) {
      result = 'probe ${e.runtimeType}';
    }
    if (!identical(failure.value, shown)) return; // إعادة محاولة/طلب أحدث/إيقاف
    failure.value = AppFailure(FailureKind.playbackFailed, _playbackDetail(error, audio, result));
  }

  /// تشخيص قصير يظهر تحت رسالة الخطأ: خطأ المشغّل · نتيجة الفحص · المصدر.
  String _playbackDetail(Object error, ResolvedAudio? audio, String? probeResult) {
    final parts = [playerErrorDetail(error)];
    if (probeResult != null) parts.add(probeResult);
    if (audio?.sourceInfo case final info?) parts.add(info);
    return sanitizeDetail(parts.join(' · '));
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
    _token++; // أولاً: يُبطل أي playVideo ينتظر حفظ الفيديو السابق
    _sleepExpiredWhileLoading = false;
    cancelSleepTimer();
    await _savePosition(); // قبل تصفير الحالة
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
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    await _player.dispose();
  }
}
