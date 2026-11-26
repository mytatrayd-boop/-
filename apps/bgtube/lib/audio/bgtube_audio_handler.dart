import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' show ProcessingState;

import '../core/app_failure.dart';
import '../domain/models/now_playing.dart';
import '../domain/models/resolved_audio.dart';
import '../domain/models/playback_position.dart';
import '../domain/models/video_ref.dart';
import '../domain/playback_queue_model.dart';
import '../domain/playback_queue_model.dart' as model show clearUpcoming;
import '../domain/playback_speed.dart';
import '../domain/position_policy.dart';
import '../domain/sleep_timer.dart';
import '../domain/ports/audio_source_resolver.dart';
import '../domain/ports/playback_controller.dart';
import '../domain/ports/playback_queue.dart';
import '../domain/ports/position_repository.dart';
import '../domain/ports/queue_repository.dart';
import '../domain/ports/speed_store.dart';
import 'audio_engine.dart';
import 'playback_diagnostics.dart';
import 'playback_state_mapper.dart';

/// ناتج استخراج محفوظ في الذاكرة (الحالي أو التالي فقط، D27).
class _Fetched {
  _Fetched(this.audio, this.fetchedAt);
  final ResolvedAudio audio;
  final DateTime fetchedAt;
}

/// الحفظ الدوري للموضع: ٣ ث حتى يتحقق ±٣ ث في SPEC (الميزة 10) عند قتل التطبيق.
const defaultSaveInterval = Duration(seconds: 3);

/// مهلة الهدوء بعد آخر تعديل يغيّر «التالي» قبل استخراجه مسبقاً (D28).
const defaultPrefetchQuiet = Duration(milliseconds: 2500);

/// معالج الصوت: يلفّ المشغّل ويعرضه عبر audio_service
/// (خدمة مقدّمة + إشعار + شاشة قفل). يعتمد على المنفذ `AudioSourceResolver` فقط.
/// ينفّذ أيضاً طابور التشغيل (D27): مصدر واحد في المشغّل في كل لحظة، والطابور
/// نموذج صرف في domain.
class BgtubeAudioHandler extends BaseAudioHandler with SeekHandler implements PlaybackController, PlaybackQueue {
  BgtubeAudioHandler({
    required this._resolver,
    AudioEngine? engine,
    this._positions,
    this._speedStore,
    this._queueRepo,
    this._saveInterval = defaultSaveInterval,
    this._probe,
    this._prefetchQuiet = defaultPrefetchQuiet,
  }) : _player = engine ?? JustAudioEngine() {
    _restoreSpeed();
    _player.playbackEventStream.listen(
      (event) {
        if (event.processingState == ProcessingState.ready) _onReady();
        if (event.processingState == ProcessingState.completed) _onCompleted();
        playbackState.add(toPlaybackState(
          event: event,
          playing: _player.playing,
          speed: _player.speed,
          queueIndex: _queueIndexOrNull,
        ));
      },
      onError: _onPlayerError,
    );
    // المدة من المشغّل نفسه (أدق، وتعمل حين تتأخر البيانات الوصفية أو تفشل):
    // لشريط التقدم والإشعار وPositionPolicy.
    _player.durationStream.listen((d) {
      final now = nowPlaying.value;
      if (d == null || d <= Duration.zero || now == null || now.duration == d) return;
      _updateNowPlaying(now.videoId, duration: d);
    });
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
  final QueueRepository? _queueRepo;
  final Duration _saveInterval;
  final Duration _prefetchQuiet;

  /// فحص الرابط عند فشل التشغيل النهائي (للتشخيص فقط). null = بلا فحص.
  final StreamProbe? _probe;

  /// آخر مصدر محلول (للتشخيص ولمعرفة انتهاء الرابط) ووقت جلبه.
  ResolvedAudio? _lastAudio;
  DateTime? _lastFetchedAt;
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
  /// يبقى فعّالاً عند تبديل الفيديو أو الانتقال في الطابور أو الإيقاف المؤقت
  /// اليدوي، ويُلغى عند stop() أو cancelSleepTimer().
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

  /// الانتهاء `pause()` لا stop: لا completed ولا انتقال، فيتوقف الطابور كله.
  Future<void> _finishSleep() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepRemaining.value = null;
    // أثناء التحميل، أو في الفجوة قبله (انتقال ينتظر حفظ الموضع، أو لا مصدر
    // محمّل للرمز الحالي): لا يبدأ تشغيل بعد اكتمال التحميل.
    if (resolving.value || _loadedToken != _token) _sleepExpiredWhileLoading = true;
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

  /// الفيديو الذي يعمل عليه المشغّل (محمّل أو يُحمَّل أو فشل). null بعد stop
  /// أو بعد الاستعادة قبل أول تشغيل.
  String? _videoId;
  int _token = 0;
  bool _autoRetried = false;

  /// موضع البدء/الاستئناف للفيديو الحالي (صفر للجديد).
  Duration _resumeFrom = Duration.zero;

  /// true بعد نجاح تحميل مصدر الفيديو الحالي في المشغّل.
  bool _loaded = false;

  /// الرمز الذي حُمّل عنده المصدر الحالي؛ completed يُعتدّ به فقط إن طابق [_token].
  int _loadedToken = -1;

  /// الرمز الذي عولج عنده completed (انتهى الحالي ولا انتقال بعده = نهاية الطابور).
  int _completedToken = -1;

  // ───────────────────────────── الطابور ─────────────────────────────

  final ValueNotifier<QueueSnapshot> _queue = ValueNotifier(QueueSnapshot.empty);

  @override
  ValueListenable<QueueSnapshot> get queueState => _queue;

  int _keySeq = 1;

  /// فشلات نهائية متتالية بلا نجاح أو طلب مستخدم بينها.
  int _consecutiveFailures = 0;
  static const maxConsecutiveFailures = 3;

  final _skipped = StreamController<VideoRef>.broadcast();

  @override
  Stream<VideoRef> get skippedFailures => _skipped.stream;

  // ── الاستخراج المسبق (D27/D28) ──
  // طلب جارٍ واحد على الأكثر؛ مهلة هدوء بعد تعديلات الطابور؛ ذاكرة صغيرة لنواتج
  // ما زالت عناصرها في الطابور (لا يُعاد استخراج فيديو استُخرج)؛ وذاكرة فشل صغيرة.

  /// النواتج المحفوظة بترتيب الإدراج (الأقدم أولاً)، بحد [maxPrefetched].
  final Map<int, _Fetched> _fetched = {};
  static const maxPrefetched = 3;

  /// الطلب المسبق الجاري (واحد على الأكثر).
  int? _prefetchKey;
  Future<ResolvedAudio>? _prefetchFuture;

  /// عناصر فشل استخراجها المسبق (لا يُعاد لها حتى تصبح تالية لحالي جديد).
  final Set<int> _prefetchFailed = {};
  static const maxPrefetchFailed = 8;

  Timer? _prefetchTimer;
  int? _lastNextKey;

  /// الرمز الذي بلغ عنده الحالي ready (بعده يُستخرج التالي مسبقاً).
  int _readyToken = -1;

  /// هامش صلاحية الرابط المعروف انتهاؤه، وعمر الرابط المجهول انتهاؤه (D27).
  static const linkExpiryMargin = Duration(minutes: 10);
  static const unknownExpiryMaxAge = Duration(minutes: 30);

  /// مفاتيح النواتج المحفوظة والطلب الجاري (للاختبار).
  @visibleForTesting
  Set<int> get prefetchedKeys => {..._fetched.keys, ?_prefetchKey};

  int? get _queueIndexOrNull {
    final i = _queue.value.currentIndex;
    return i < 0 ? null : i;
  }

  List<QueueEntry> _newEntries(List<VideoRef> refs) =>
      [for (final r in refs) QueueEntry(key: _keySeq++, ref: r)];

  /// ينشر اللقطة في الواجهة وaudio_service ويحفظها ويقلّم الاستخراج المسبق.
  void _setQueue(QueueSnapshot s, {bool persist = true, bool prefetch = true}) {
    if (s == _queue.value) return;
    _queue.value = s;
    queue.add([for (final e in s.entries) _mediaItemFor(e)]);
    playbackState.add(playbackState.value.copyWith(queueIndex: _queueIndexOrNull));
    _pruneFetched();
    // تغيّر التالي بعد جاهزية الحالي (شغّل التالي/ترتيب/حذف): يُستخرج الجديد
    // مسبقاً بعد مهلة هدوء يعيدها كل تعديل، فلا تُطلق سلسلة سحب طلباً لكل خطوة.
    final nextKey = s.next?.key;
    if (nextKey != _lastNextKey) {
      _lastNextKey = nextKey;
      if (prefetch && _prefetchAllowed) {
        _prefetchTimer?.cancel();
        _prefetchTimer = Timer(_prefetchQuiet, _prefetchNext);
      }
    }
    if (persist) _persist(s);
  }

  MediaItem _mediaItemFor(QueueEntry e, {String? titleOverride, String? author, Duration? duration, String? art}) {
    final thumb = art ?? e.ref.thumbUrl;
    return MediaItem(
      id: '${e.key}',
      title: titleOverride ?? e.ref.title ?? e.ref.videoId,
      artist: author ?? e.ref.author,
      duration: duration ?? e.ref.duration,
      artUri: thumb == null ? null : Uri.tryParse(thumb),
      extras: {'videoId': e.ref.videoId},
    );
  }

  /// يُبقي نواتج العناصر التي ما زالت في الطابور وصالحة، بحد [maxPrefetched]
  /// (يُطرد الأقدم عدا التالي). الطلب الجاري لا يُلغى؛ ناتجه يُحفظ إن بقي عنصره.
  void _pruneFetched() {
    final s = _queue.value;
    _fetched.removeWhere((k, f) => s.indexOfKey(k) < 0 || !_isFresh(f.audio, f.fetchedAt));
    _prefetchFailed.removeWhere((k) => s.indexOfKey(k) < 0);
    final nextKey = s.next?.key;
    while (_fetched.length > maxPrefetched) {
      final victim = _fetched.keys.firstWhere((k) => k != nextKey, orElse: () => _fetched.keys.first);
      _fetched.remove(victim);
    }
  }

  void _storeFetched(int key, _Fetched f) {
    _fetched.remove(key); // يعيد ترتيبه كأحدث
    _fetched[key] = f;
    _pruneFetched();
  }

  /// الاستخراج المسبق مسموح بعد جاهزية الحالي فقط، وللرمز نفسه.
  bool get _prefetchAllowed => _loaded && _readyToken == _token;

  bool _isFresh(ResolvedAudio audio, DateTime fetchedAt) {
    final now = clock.now();
    final exp = audio.expiresAt;
    if (exp != null) return exp.difference(now) > linkExpiryMargin;
    return now.difference(fetchedAt) < unknownExpiryMaxAge;
  }

  /// أول ready للحالي: يُستخرج التالي فوراً (بلا مهلة). لا يلمس المشغّل ولا
  /// الوكيل (D26: لا preload للمصدر نفسه). فشله يُبتلع؛ الفشل الحقيقي يظهر عند
  /// الانتقال. عنصر فشل سابقاً يُعاد له مرة لأنه صار تالياً لحالي جديد.
  void _maybePrefetch() {
    if (_readyToken == _token) return;
    _readyToken = _token;
    final next = _queue.value.next;
    if (next != null) _prefetchFailed.remove(next.key);
    _prefetchTimer?.cancel();
    _prefetchNext();
  }

  /// يستخرج «التالي» إن لم يكن محفوظاً صالحاً ولا فاشلاً. طلب واحد على الأكثر:
  /// إن كان غيره جارياً ينتظر، وعند انتهائه يبدأ للتالي الجديد مرة واحدة.
  void _prefetchNext() {
    if (!_prefetchAllowed) return;
    if (_prefetchTimer?.isActive ?? false) return; // ما زالت التعديلات جارية
    final next = _queue.value.next;
    if (next == null) return;
    final have = _fetched[next.key];
    if (have != null && _isFresh(have.audio, have.fetchedAt)) return;
    if (_prefetchFailed.contains(next.key)) return;
    if (_prefetchKey != null) return; // واحد جارٍ؛ يُستأنف عند انتهائه
    final key = next.key;
    final future = _resolver.resolve(next.ref.videoId);
    _prefetchKey = key;
    _prefetchFuture = future;
    void done() {
      if (_prefetchKey == key) {
        _prefetchKey = null;
        _prefetchFuture = null;
      }
    }
    future.then((audio) {
      final wasOurs = _prefetchKey == key;
      done();
      final f = _Fetched(audio, clock.now());
      if (!_isFresh(f.audio, f.fetchedAt)) {
        // رابط قريب الانتهاء من أصله: لا يُكرَّر استخراجه في حلقة؛ الانتقال يستخرج.
        _rememberPrefetchFailure(key);
      } else if (_queue.value.indexOfKey(key) >= 0) {
        // يُحفظ ما دام عنصره في الطابور (حتى لو لم يعد التالي).
        _storeFetched(key, f);
      }
      if (wasOurs) _prefetchNext(); // تغيّر التالي أثناءه: مرة واحدة للجديد
    }, onError: (Object _) {
      final wasOurs = _prefetchKey == key;
      done();
      _rememberPrefetchFailure(key);
      if (wasOurs) _prefetchNext();
    });
  }

  void _rememberPrefetchFailure(int key) {
    _prefetchFailed.remove(key);
    _prefetchFailed.add(key);
    while (_prefetchFailed.length > maxPrefetchFailed) {
      _prefetchFailed.remove(_prefetchFailed.first);
    }
  }

  /// يعطي ناتجاً جاهزاً للعنصر إن وُجد صالحاً، أو ينتظر استخراجه المسبق الجاري
  /// بدل تكراره (فلا يُستهلك تدوير العملاء في D24).
  Future<_Fetched?> _takeFetched(int key) async {
    final have = _fetched.remove(key);
    if (have != null) return _isFresh(have.audio, have.fetchedAt) ? have : null;
    if (_prefetchKey == key && _prefetchFuture != null) {
      final f = _prefetchFuture!;
      try {
        await f;
        // ناتجه حُفظ عند اكتماله (ما دام العنصر في الطابور).
        return _fetched.remove(key);
      } catch (_) {
        return null; // نعيد الاستخراج بأنفسنا فيظهر الفشل الحقيقي
      }
    }
    return null;
  }

  // ─────────── الحفظ: كتابات متسلسلة، تُدمج اللقطات المنتظرة فتُكتب الأحدث ───────────

  QueueSnapshot? _pendingSave;
  Future<void>? _saveLoop;

  /// يكتمل حين تُكتب كل اللقطات المنتظرة (للاختبار).
  @visibleForTesting
  Future<void> get queueSavesIdle => _saveLoop ?? Future.value();

  void _persist(QueueSnapshot s) {
    if (_queueRepo == null) return;
    _pendingSave = s;
    _saveLoop ??= _runSaves();
  }

  Future<void> _runSaves() async {
    try {
      while (_pendingSave != null) {
        final snap = _pendingSave!;
        _pendingSave = null;
        try {
          await _queueRepo!.save(snap);
        } catch (e) {
          debugPrint('queue save failed: ${e.runtimeType}'); // لا يكسر التشغيل
        }
      }
    } finally {
      _saveLoop = null;
    }
  }

  /// يستعيد الطابور المحفوظ عند الإقلاع: ينشره مع المقطع الحالي دون استخراج ولا
  /// تشغيل. أول play() يحمّل الحالي من موضعه المحفوظ. ما أُضيف قبل اكتمال
  /// الاستعادة (مشاركة عند البدء البارد) يبقى بعد المستعاد ويبقى حالياً.
  Future<void> restoreQueue() async {
    final repo = _queueRepo;
    if (repo == null) return;
    QueueSnapshot? stored;
    try {
      stored = await repo.load();
    } catch (e) {
      debugPrint('queue restore failed: ${e.runtimeType}');
      return;
    }
    if (stored == null || stored.isEmpty) return;
    // مفاتيح جديدة للجلسة: لا تصادم مع ما أُضيف قبل الاستعادة.
    int? currentKey;
    final restored = <QueueEntry>[];
    for (final e in stored.entries) {
      final k = _keySeq++;
      if (e.key == stored.currentKey) currentKey = k;
      restored.add(e.copyWith(key: k));
    }
    final live = _queue.value;
    if (live.isEmpty) {
      final room = restored.take(PlaybackQueue.maxLength).toList();
      final snap = QueueSnapshot(
        entries: room,
        currentKey: room.any((e) => e.key == currentKey) ? currentKey : room.first.key,
      );
      _setQueue(snap, persist: false);
      if (_videoId == null) _publishIdleCurrent();
    } else {
      final room = PlaybackQueue.maxLength - live.entries.length;
      final merged = [...restored.take(room < 0 ? 0 : room), ...live.entries];
      _setQueue(QueueSnapshot(entries: merged, currentKey: live.currentKey));
    }
  }

  /// ينشر الحالي في الواجهة والإشعار دون تحميل (بعد الاستعادة أو حذف الحالي).
  void _publishIdleCurrent() {
    final cur = _queue.value.current;
    if (cur == null) {
      nowPlaying.value = null;
      return;
    }
    nowPlaying.value = NowPlaying(
      videoId: cur.ref.videoId,
      title: cur.ref.title ?? cur.ref.videoId,
      author: cur.ref.author,
      duration: cur.ref.duration,
    );
    mediaItem.add(_mediaItemFor(cur));
  }

  @override
  Future<EnqueueResult> enqueue(List<VideoRef> refs, QueuePlacement placement) async {
    if (refs.isEmpty) return const EnqueueResult([]);
    final before = _queue.value;
    final room = PlaybackQueue.maxLength - before.entries.length;
    final take = refs.length <= room ? refs : refs.sublist(0, room < 0 ? 0 : room);
    final truncated = take.length < refs.length;
    if (take.isEmpty) return EnqueueResult(const [], truncated: truncated);
    final added = _newEntries(take);
    final keys = [for (final e in added) e.key];
    final startPlayback = before.isEmpty;
    // «شغّل الآن» ينتقل فوراً: لا استخراج مسبق لما سيُحمَّل على أي حال.
    final prefetch = placement != QueuePlacement.playNow;
    switch (placement) {
      case QueuePlacement.playNow:
      case QueuePlacement.playNext:
        _setQueue(insertNext(before, added), prefetch: prefetch);
      case QueuePlacement.addToEnd:
        _setQueue(append(before, added), prefetch: prefetch);
    }
    if (placement == QueuePlacement.playNow || startPlayback) {
      // ينتظر التحميل (playVideo يعيد بعد اكتماله كما كان)؛ الواجهة لا تعرض
      // رسالة تأكيد في هذه الحالة بل المشغّل.
      await _transitionTo(keys.first, user: true);
    }
    return EnqueueResult(keys, truncated: truncated);
  }

  /// يبدأ تشغيل فيديو: غلاف لـ`enqueue([ref], playNow)` (D27). الفشل لا يُرمى؛
  /// يُنشر في [failure].
  @override
  Future<void> playVideo(String videoId) => enqueue([VideoRef(videoId: videoId)], QueuePlacement.playNow);

  @override
  Future<void> skipToNext() async {
    final next = _queue.value.next;
    if (next == null) return;
    await _transitionTo(next.key, user: true);
  }

  @override
  Future<void> skipToPrevious() async {
    final s = _queue.value;
    switch (previousAction(s, _loaded ? _player.position : Duration.zero)) {
      case PreviousAction.restart:
        if (_loaded) await _player.seek(Duration.zero);
      case PreviousAction.goPrevious:
        await _transitionTo(s.previous!.key, user: true);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final entries = _queue.value.entries;
    if (index < 0 || index >= entries.length) return;
    await jumpTo(entries[index].key);
  }

  @override
  Future<void> jumpTo(int key) async {
    final s = _queue.value;
    if (s.indexOfKey(key) < 0) return;
    if (key == s.currentKey) {
      if (failure.value != null && _videoId != null) return retry();
      if (!_loaded && !resolving.value) return _transitionTo(key, user: true);
      return _player.play();
    }
    await _transitionTo(key, user: true);
  }

  @override
  Future<void> removeEntry(int key) async {
    final s = _queue.value;
    if (s.indexOfKey(key) < 0) return;
    if (key != s.currentKey) {
      _setQueue(remove(s, key));
      return;
    }
    // حذف الحالي: ينتقل إلى التالي بحالة التشغيل نفسها.
    final wasActive = _player.playing || resolving.value;
    final next = s.next;
    if (next != null) {
      await _savePosition();
      _setQueue(remove(s, key), prefetch: false); // الانتقال يحمّله الآن
      await _transitionTo(next.key, user: true, autoplay: wasActive);
      return;
    }
    await _unloadAndSet(remove(s, key));
  }

  /// يوقف المشغّل ويجعل [s] هي الطابور، والحالي فيها غير محمّل (يُحمَّل عند play).
  Future<void> _unloadAndSet(QueueSnapshot s) async {
    _token++;
    await _savePosition();
    _videoId = null;
    _loaded = false;
    _lastAudio = null;
    resolving.value = false;
    failure.value = null;
    _setQueue(s);
    _publishIdleCurrent();
    await _player.stop();
  }

  @override
  Future<void> removeEntries(List<int> keys) async {
    final cur = _queue.value.currentKey;
    var s = _queue.value;
    for (final k in keys) {
      if (k != cur) s = remove(s, k);
    }
    _setQueue(s);
    if (cur != null && keys.contains(cur)) await removeEntry(cur);
  }

  @override
  Future<void> moveEntry(int key, int toIndex) async => _setQueue(move(_queue.value, key, toIndex));

  @override
  Future<void> clearUpcoming() async => _setQueue(model.clearUpcoming(_queue.value));

  @override
  Future<void> restoreEntries(List<IndexedEntry> removed) async {
    final wasEmpty = _queue.value.isEmpty;
    _setQueue(reinsert(_queue.value, removed));
    if (wasEmpty && _videoId == null) _publishIdleCurrent();
  }

  /// ينتقل إلى عنصر. [user] = طلب مستخدم (يصفّر عدّ الفشلات وعلامة انتهاء
  /// المؤقت أثناء التحميل، ويزيل علامة فشل العنصر). الانتقال التلقائي ليس طلباً.
  /// الأحدث يفوز: الرمز يُزاد قبل أي انتظار.
  Future<void> _transitionTo(int key, {required bool user, bool autoplay = true}) async {
    final token = ++_token;
    if (user) {
      _sleepExpiredWhileLoading = false;
      _consecutiveFailures = 0;
    }
    _autoRetried = false;
    _resumeFrom = Duration.zero;
    var s = setCurrent(_queue.value, key);
    if (user) s = markFailed(s, key, false);
    _setQueue(s);
    await _savePosition(); // موضع الحالي قبل استبداله
    // stop() (أو طلب أحدث) أثناء الحفظ: لا نبدأ تشغيلاً بعد إيقاف المستخدم.
    if (token != _token) return;
    await _loadEntry(key, token, resumeSaved: true, useCache: true, autoplay: autoplay);
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

  void _onReady() {
    _autoRetried = false;
    if (!_loaded || _loadedToken != _token) return;
    // نجح الحالي: يُصفَّر عدّ الفشلات وتُزال علامته، ثم يُستخرج التالي.
    _consecutiveFailures = 0;
    final key = _queue.value.currentKey;
    if (key != null) _setQueue(markFailed(_queue.value, key, false));
    _maybePrefetch();
  }

  /// انتهى الفيديو: لا استئناف في المرة القادمة، ثم التالي تلقائياً إن وُجد.
  void _onCompleted() {
    // completed قديم (من مصدر سابق أثناء انتقال) أو مكرر: يُتجاهل.
    if (!_loaded || _loadedToken != _token || _completedToken == _token) return;
    _completedToken = _token;
    _saveTimer?.cancel(); // لا حفظ دوري بعد الانتهاء
    _saveTimer = null;
    final repo = _positions;
    final id = _videoId;
    if (repo != null && id != null) repo.delete(id).catchError((Object _) {});
    final next = _queue.value.next;
    if (next == null) return; // نهاية الطابور: يتوقف (لا تكرار)
    final token = _token;
    // إن ضغط المستخدم «التالي» في اللحظة نفسها فاز طلبه (الرمز تغيّر).
    scheduleMicrotask(() {
      if (token != _token) return;
      final n = _queue.value.next;
      if (n != null) _transitionTo(n.key, user: false);
    });
  }

  Future<Duration> _savedPosition(String videoId) async {
    try {
      final saved = await _positions?.get(videoId);
      return saved?.position ?? Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// يعيد المحاولة للمقطع الحالي (يحافظ على الموضع إن كان قد بدأ)، باستخراج جديد.
  @override
  Future<void> retry() {
    final id = _videoId;
    final key = _queue.value.currentKey;
    if (id == null || key == null) return Future.value();
    _autoRetried = false;
    _sleepExpiredWhileLoading = false;
    _consecutiveFailures = 0;
    _setQueue(markFailed(_queue.value, key, false));
    _captureResume();
    return _loadEntry(key, ++_token);
  }

  /// يحفظ موضع المشغّل إن كان مصدر الفيديو الحالي محمّلاً (قبل أي إيقاف).
  void _captureResume() {
    if (_loaded) _resumeFrom = _player.position;
  }

  /// يحمّل عنصراً بالرمز [token] (يجب أن يكون الأحدث). [useCache] يستعمل
  /// الاستخراج المسبق؛ إعادة المحاولة لا تستعمله (تدوير العملاء، D24).
  Future<void> _loadEntry(
    int key,
    int token, {
    bool resumeSaved = false,
    bool useCache = false,
    bool autoplay = true,
  }) async {
    final entry = _queue.value.entryByKey(key);
    if (entry == null || token != _token) return;
    final videoId = entry.ref.videoId;
    _videoId = videoId;
    _loaded = false;
    _lastAudio = null;
    failure.value = null;
    resolving.value = true;
    if (nowPlaying.value?.videoId != videoId || mediaItem.value?.id != '$key') {
      nowPlaying.value = NowPlaying(
        videoId: videoId,
        title: entry.ref.title ?? videoId,
        author: entry.ref.author,
        duration: entry.ref.duration,
      );
      mediaItem.add(_mediaItemFor(entry));
    }
    // أوقف الصوت القديم فوراً قبل حلّ الجديد.
    await _player.stop();
    if (token != _token) return;
    if (resumeSaved) {
      _resumeFrom = await _savedPosition(videoId);
      if (token != _token) return;
    }
    try {
      final cached = useCache ? await _takeFetched(key) : null;
      if (token != _token) return;
      final ResolvedAudio audio;
      if (cached != null) {
        audio = cached.audio;
        _lastFetchedAt = cached.fetchedAt;
      } else {
        audio = await _resolver.resolve(videoId);
        if (token != _token) return; // طلب أحدث حلّ محلّه
        _lastFetchedAt = clock.now();
      }
      _lastAudio = audio;
      _applyMetadata(key, videoId,
          title: audio.title, author: audio.author, duration: audio.duration, thumbUrl: audio.thumbnailUrl);
      final late = audio.lateMetadata;
      if (late != null) {
        unawaited(late.then((m) {
          // لا نكتب بيانات فيديو سابق فوق الحالي. الرمز وحده لا يكفي: إعادة
          // المحاولة للفيديو نفسه تغيّره والبيانات ما زالت صحيحة؛ فالمعيار هو
          // أن الفيديو الحالي ما زال هو نفسه.
          if (m == null || _videoId != videoId) return;
          _applyMetadata(key, videoId,
              title: m.title,
              author: m.author,
              // مدة المشغّل إن عُرفت أدق من البيانات الوصفية.
              duration: nowPlaying.value?.duration ?? m.duration,
              thumbUrl: m.thumbnailUrl,
              late: true);
        }, onError: (Object _) {}));
      }
      await _player.setUrl(audio.url, initialPosition: _resumeFrom, headers: audio.httpHeaders);
      if (token != _token) return;
      await _player.setSpeed(speed.value); // السرعة المختارة لكل عنصر
      if (token != _token) return;
      _loaded = true;
      _loadedToken = token;
      resolving.value = false;
      if (_sleepExpiredWhileLoading) {
        // انتهى مؤقت النوم أثناء التحميل: يبقى محمّلاً ومتوقفاً (الاستئناف يدوي).
        _sleepExpiredWhileLoading = false;
        await _player.setVolume(1.0);
        return;
      }
      if (!autoplay) return;
      await _player.play();
    } on AppFailure catch (e) {
      if (token == _token) await _finalFailure(e);
    } catch (e) {
      // خطأ من المشغّل أثناء التحميل: يُعالَج هنا لا من تيار الأحداث (انظر _onPlayerError).
      if (token == _token) await _handleEngineError(token, e);
    }
  }

  /// يدمج البيانات الوصفية في العنصر (يُحفظ) وفي الواجهة والإشعار. لا يُستبدل
  /// عنوان معروف بالمعرّف الذي يعود عند فشل البيانات الوصفية (D26).
  void _applyMetadata(
    int key,
    String videoId, {
    required String title,
    String? author,
    Duration? duration,
    String? thumbUrl,
    bool late = false,
  }) {
    final entry = _queue.value.entryByKey(key);
    if (entry == null) return;
    final enriched = enrichRef(entry.ref, title: title, author: author, duration: duration, thumbUrl: thumbUrl);
    _setQueue(updateRef(_queue.value, key, enriched));
    final realTitle = title.isNotEmpty && title != videoId ? title : null;
    if (late) {
      _updateNowPlaying(videoId,
          title: realTitle, author: author, duration: duration, thumbnailUrl: thumbUrl);
      return;
    }
    nowPlaying.value = NowPlaying(
      videoId: videoId,
      title: enriched.title ?? title,
      author: author ?? enriched.author,
      duration: duration ?? enriched.duration,
    );
    mediaItem.add(_mediaItemFor(entry.copyWith(ref: enriched),
        titleOverride: enriched.title ?? title,
        author: author ?? enriched.author,
        duration: duration ?? enriched.duration,
        art: thumbUrl));
  }

  /// فشل نهائي للحالي (D27): يُعلَّم ويُتخطّى إلى التالي. يتوقف الطابور ويظهر
  /// الفشل مع «إعادة المحاولة» دون تعليم عند network أو بعد ٣ فشلات متتالية.
  /// الأخير في الطابور يُعلَّم ويظهر فشله.
  Future<void> _finalFailure(AppFailure f) async {
    final key = _queue.value.currentKey;
    if (key == null || f.kind == FailureKind.network) return _fail(f);
    _consecutiveFailures++;
    if (_consecutiveFailures >= maxConsecutiveFailures) {
      return _fail(AppFailure(FailureKind.queueStopped, f.debugDetail ?? f.kind.name));
    }
    _setQueue(markFailed(_queue.value, key, true));
    final next = _queue.value.next;
    if (next == null) return _fail(f);
    final ref = _queue.value.entryByKey(key)!.ref;
    _skipped.add(ref);
    await _transitionTo(next.key, user: false);
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

  /// خطأ مشغّل: محاولة تلقائية واحدة بحلّ جديد، ثم فشل نهائي.
  Future<void> _handleEngineError(int token, Object error) async {
    if (token != _token) return;
    final key = _queue.value.currentKey;
    if (_videoId != null && key != null && !_autoRetried) {
      _autoRetried = true;
      _captureResume();
      _fetched.remove(key);
      await _loadEntry(key, ++_token);
    } else {
      // الفشل يظهر فوراً؛ الفحص (حتى 6 ث) يُكمل السطر التشخيصي لاحقاً (D26).
      final audio = _lastAudio;
      final shown = AppFailure(FailureKind.playbackFailed, _playbackDetail(error, audio, null));
      await _finalFailure(shown);
      if (identical(failure.value, shown)) unawaited(_enrichWithProbe(shown, error, audio));
    }
  }

  /// يحدّث العنوان/القناة/المدة/الصورة للفيديو الحالي في الواجهة والإشعار معاً.
  void _updateNowPlaying(
    String videoId, {
    String? title,
    String? author,
    Duration? duration,
    String? thumbnailUrl,
  }) {
    final now = nowPlaying.value;
    if (now == null || now.videoId != videoId || _videoId != videoId) return;
    final next = NowPlaying(
      videoId: videoId,
      title: title ?? now.title,
      author: author ?? now.author,
      duration: duration ?? now.duration,
    );
    nowPlaying.value = next;
    final item = mediaItem.value;
    mediaItem.add(MediaItem(
      id: item?.id ?? '${_queue.value.currentKey}',
      title: next.title,
      artist: next.author,
      duration: next.duration,
      artUri: thumbnailUrl != null ? Uri.tryParse(thumbnailUrl) : item?.artUri,
      extras: {'videoId': videoId},
    ));
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

  /// تشخيص قصير يظهر تحت رسالة الخطأ: خطأ المشغّل · فشل الوكيل · نتيجة الفحص · المصدر.
  String _playbackDetail(Object error, ResolvedAudio? audio, String? probeResult) {
    final parts = [playerErrorDetail(error)];
    if (_player.sourceErrorDetail case final proxy?) parts.add(proxy);
    if (probeResult != null) parts.add(probeResult);
    if (audio?.sourceInfo case final info?) parts.add(info);
    return sanitizeDetail(parts.join(' · '));
  }

  /// خطأ من تيار الأحداث. أثناء التحميل يلتقطه `_loadEntry` نفسه (يرمي setUrl أيضاً)،
  /// فيُتجاهل هنا لمنع معالجته مرتين.
  void _onPlayerError(Object error, StackTrace _) {
    if (resolving.value || _videoId == null) return;
    _handleEngineError(_token, error);
  }

  /// تشغيل/استئناف. إن لم يكن هناك مصدر محمّل (بعد الاستعادة أو stop) يحمّل
  /// الحالي من موضعه المحفوظ؛ وإن انتهى الطابور يعيده من أوله؛ وإن انتهت صلاحية
  /// الرابط بعد إيقاف طويل يعيد تحميله من موضعه.
  @override
  Future<void> play() async {
    final s = _queue.value;
    final cur = s.currentKey;
    if (cur == null || resolving.value) return _player.play();
    if (_loaded && _completedToken == _token && _completedToken == _loadedToken && s.next == null) {
      return _transitionTo(s.entries.first.key, user: true);
    }
    if (!_loaded) {
      if (failure.value != null && _videoId != null) return retry();
      return _transitionTo(cur, user: true);
    }
    final audio = _lastAudio;
    final fetchedAt = _lastFetchedAt;
    if (!_player.playing && audio != null && fetchedAt != null && !_isFresh(audio, fetchedAt)) {
      _captureResume();
      _fetched.remove(cur);
      return _loadEntry(cur, ++_token);
    }
    return _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// يُبطل كل شيء ويوقف المشغّل ومؤقت النوم، ولا يمسح الطابور (D27).
  @override
  Future<void> stop() async {
    _token++; // أولاً: يُبطل أي انتقال ينتظر حفظ الفيديو السابق
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
    _prefetchTimer?.cancel();
    _sleepTimer?.cancel();
    await _skipped.close();
    await _player.dispose();
  }
}
