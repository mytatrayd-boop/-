import 'dart:async';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

import '../../core/geo/distance.dart';
import '../../core/geo/geo_point.dart';
import '../../data/camera/camera_preview_source.dart';
import '../../data/location/location_source.dart';
import '../../data/map/map_tiles.dart';
import '../../data/network/network_status_source.dart';
import '../../data/platform/screen_awake.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/permissions/permission_service.dart';
import '../onboarding_permissions/permissions_controller.dart';

const _camPerm = AppPermission.camera;
const _granted = AppPermissionStatus.granted;

// الاعتماديات على الجهاز، تُستبدل في الاختبارات بنسخ مزيّفة.
final locationSourceProvider = Provider<LocationSource>(
  (_) => const GeolocatorLocationSource(),
);
/// المُسجِّل الأصلي (كاميرا + ترميز). يُستبدل بـFakeRihlaRecorder في الاختبارات.
final recorderProvider = Provider<RihlaRecorder>(
  (_) => MethodChannelRihlaRecorder(),
);
final cameraPreviewSourceProvider = Provider<CameraPreviewSource>(
  (ref) => NativeCameraPreviewSource(ref.watch(recorderProvider)),
);
final networkStatusSourceProvider = Provider<NetworkStatusSource>(
  (_) => const ConnectivityNetworkStatusSource(),
);
final screenAwakeProvider = Provider<ScreenAwake>(
  (_) => const WakelockScreenAwake(),
);
final mapTilesProvider = Provider<MapTilesSource>(
  (_) => const OpenFreeMapTiles(),
);

enum CameraStatus { idle, opening, ready, error }

enum VideoQuality { p720, p1080 }

enum StartBlocker { permissions, cameraOpening, cameraError, waitingGps }

/// رسالة عابرة تعرضها الشاشة مرة واحدة.
enum HomeNotice { startFailed }

/// رحلة انتهت للتو (بإيقاف أو انقطاع): تنقل الشاشة إلى الملخص مرة واحدة.
class FinishedTrip {
  const FinishedTrip(this.tripId, {this.interruptReason, this.dbError = false});
  final String tripId;
  final InterruptReason? interruptReason;

  /// تعذّر تحديث سجل الرحلة في القاعدة عند الإنهاء.
  final bool dbError;
}

/// عدّ تنازلي قبل البدء (DESIGN 7.2).
const countdownSeconds = 3;

/// دقة أسوأ من هذا = "إشارة GPS ضعيفة" (يمكن البدء مع تنبيه).
const weakGpsAccuracyM = 50.0;

class HomeState {
  const HomeState({
    this.camera = CameraStatus.idle,
    this.fix,
    this.recording = false,
    this.track = const [],
    this.elapsed = Duration.zero,
    this.distanceM = 0,
    this.muted = false,
    this.quality = VideoQuality.p720,
    this.online = true,
    this.countdown,
    this.saving = false,
    this.tripId,
    this.notice,
    this.finished,
  });

  final CameraStatus camera;
  final LocationFix? fix;
  final bool recording;

  /// مسار الجلسة الحي (F5: عرض فقط، بلا حفظ؛ الحفظ في F6).
  final List<GeoPoint> track;
  final Duration elapsed;
  final double distanceM;
  final bool muted;
  final VideoQuality quality;
  final bool online;

  /// 3-2-1 قبل البدء؛ null خارج العدّ.
  final int? countdown;

  /// جارٍ إيقاف التسجيل وحفظه.
  final bool saving;
  final String? tripId;
  final HomeNotice? notice;
  final FinishedTrip? finished;

  bool get busy => countdown != null || saving;

  bool get weakGps =>
      fix != null &&
      (fix!.accuracyM == null || fix!.accuracyM! > weakGpsAccuracyM);

  HomeState copyWith({
    CameraStatus? camera,
    LocationFix? fix,
    bool? recording,
    List<GeoPoint>? track,
    Duration? elapsed,
    double? distanceM,
    bool? muted,
    VideoQuality? quality,
    bool? online,
    int? countdown,
    bool clearCountdown = false,
    bool? saving,
    String? tripId,
    HomeNotice? notice,
    bool clearNotice = false,
    FinishedTrip? finished,
    bool clearFinished = false,
  }) => HomeState(
    camera: camera ?? this.camera,
    fix: fix ?? this.fix,
    recording: recording ?? this.recording,
    track: track ?? this.track,
    elapsed: elapsed ?? this.elapsed,
    distanceM: distanceM ?? this.distanceM,
    muted: muted ?? this.muted,
    quality: quality ?? this.quality,
    online: online ?? this.online,
    countdown: clearCountdown ? null : (countdown ?? this.countdown),
    saving: saving ?? this.saving,
    tripId: tripId ?? this.tripId,
    notice: clearNotice ? null : (notice ?? this.notice),
    finished: clearFinished ? null : (finished ?? this.finished),
  );
}

class HomeController extends Notifier<HomeState> {
  StreamSubscription<LocationFix>? _locSub;
  StreamSubscription<bool>? _netSub;
  StreamSubscription<RecorderEvent>? _recSub;
  Timer? _timer;
  Timer? _countTimer;
  bool _disposed = false;
  bool _beginCancelled = false;
  bool _beginning = false;
  bool _cameraWanted = false;
  Future<void> _writes = Future.value();
  GeoPoint? _lastPoint;

  @override
  HomeState build() {
    _disposed = false;
    // لا ref.read داخل onDispose (Riverpod 3).
    final camera = ref.read(cameraPreviewSourceProvider);
    final awake = ref.read(screenAwakeProvider);
    ref.onDispose(() {
      _disposed = true;
      _locSub?.cancel();
      _netSub?.cancel();
      _recSub?.cancel();
      _timer?.cancel();
      _countTimer?.cancel();
      if (_cameraWanted) camera.close();
      awake.disable();
    });
    ref.listen(permissionsProvider, (_, p) => _sync(p));
    // بعد عودة build (state غير جاهزة قبلها).
    Future.microtask(() {
      if (_disposed) return;
      _sync(ref.read(permissionsProvider));
      _watchNetwork();
      _recSub = ref.read(recorderProvider).events.listen(_onRecorderEvent);
    });
    return const HomeState();
  }

  /// الأذونات الحالية (بدونها لا بدء).
  PermissionsState get _perms => ref.read(permissionsProvider);

  StartBlocker? get blocker {
    if (!_perms.canStartRecording) return StartBlocker.permissions;
    return switch (state.camera) {
      CameraStatus.error => StartBlocker.cameraError,
      CameraStatus.ready => state.fix == null ? StartBlocker.waitingGps : null,
      _ => StartBlocker.cameraOpening,
    };
  }

  bool get canStart => !state.recording && !state.busy && blocker == null;

  void _sync(PermissionsState p) {
    final locOk = p.canStartRecording;
    if (locOk && _locSub == null) {
      _locSub = ref
          .read(locationSourceProvider)
          .fixes()
          .listen(_onFix, onError: (_) {});
    } else if (!locOk && _locSub != null) {
      _locSub!.cancel();
      _locSub = null;
    }
    if (p.statusOf(_camPerm) == _granted && state.camera == CameraStatus.idle) {
      openCamera();
    }
  }

  Future<void> _watchNetwork() async {
    final n = ref.read(networkStatusSourceProvider);
    _netSub = n.onlineChanges().listen((v) {
      if (!_disposed) state = state.copyWith(online: v);
    });
    final v = await n.isOnline();
    if (!_disposed) state = state.copyWith(online: v);
  }

  Future<void> openCamera() async {
    if (_disposed) return;
    _cameraWanted = true;
    state = state.copyWith(camera: CameraStatus.opening);
    try {
      await ref.read(cameraPreviewSourceProvider).open();
      if (!_disposed) state = state.copyWith(camera: CameraStatus.ready);
    } on CameraOpenException {
      if (!_disposed) state = state.copyWith(camera: CameraStatus.error);
    }
  }

  void _onFix(LocationFix f) {
    if (_disposed) return;
    final p = GeoPoint(f.lat, f.lng, time: f.time);
    final id = state.tripId;
    if (state.recording && !state.saving && id != null && p.isValid && !state.weakFor(f)) {
      final prev = _lastPoint;
      _lastPoint = p;
      state = state.copyWith(
        fix: f,
        track: [...state.track, p],
        distanceM: state.distanceM + (prev == null ? 0 : haversineMeters(prev, p)),
      );
      _persist(id, f);
    } else {
      state = state.copyWith(fix: f);
    }
  }

  /// حفظ النقطة في القاعدة بالتسلسل. فشل الحفظ لا يوقف التسجيل.
  void _persist(String tripId, LocationFix f) {
    final repo = ref.read(tripRepositoryProvider);
    _writes = _writes.then((_) async {
      try {
        await repo.addPoints(tripId, [
          TrackSample(
            lat: f.lat,
            lng: f.lng,
            ts: f.time.toUtc(),
            accuracyM: f.accuracyM,
            speedMps: f.speedMps,
          ),
        ]);
      } catch (_) {}
    });
  }

  /// يبدأ العدّ التنازلي 3-2-1 ثم التسجيل. يُرفض بلا كاميرا وموقع.
  Future<void> start() async {
    if (!canStart) return;
    state = state.copyWith(countdown: countdownSeconds, clearNotice: true);
    _countTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_disposed) return;
      final n = (state.countdown ?? 0) - 1;
      if (n <= 0) {
        t.cancel();
        _countTimer = null;
        _begin();
      } else {
        state = state.copyWith(countdown: n);
      }
    });
  }

  /// لمسة أثناء العدّ تلغيه.
  void cancelCountdown() {
    if (state.countdown == null) return;
    _countTimer?.cancel();
    _countTimer = null;
    // لمسة أثناء انتظار recorder.start: تُفحص العلامة بعد await.
    if (_beginning) _beginCancelled = true;
    state = state.copyWith(clearCountdown: true);
  }

  Future<void> _begin() async {
    final f = state.fix;
    if (f == null) return cancelCountdown();
    // كل الاعتماديات تُلتقط قبل أي await (ref.read بعد dispose يرمي).
    final rec = ref.read(recorderProvider);
    final repo = ref.read(tripRepositoryProvider);
    final awake = ref.read(screenAwakeProvider);
    final q = state.quality;
    _beginning = true;
    _beginCancelled = false;
    try {
      await _beginInner(f, rec, repo, awake, q);
    } finally {
      _beginning = false;
      _beginCancelled = false;
    }
  }

  Future<void> _stopQuietly(RihlaRecorder rec) async {
    try {
      await rec.stop();
    } catch (_) {}
  }

  Future<void> _beginInner(
    LocationFix f,
    RihlaRecorder rec,
    TripRepository repo,
    ScreenAwake awake,
    VideoQuality q,
  ) async {
    void failed() {
      if (!_disposed) {
        state = state.copyWith(clearCountdown: true, notice: HomeNotice.startFailed);
      }
    }

    try {
      await rec.start(RecordingConfig(
        quality: q == VideoQuality.p1080 ? RecorderQuality.p1080 : RecorderQuality.p720,
        muted: state.muted,
      ));
    } catch (_) {
      // أي استثناء (لا RecorderException فقط) يعني فشل البدء.
      failed();
      return;
    }
    if (_beginCancelled || _disposed) {
      // أُلغي العدّ أو أُغلقت الشاشة أثناء البدء: لا يبقى مُسجِّل شغّال.
      await _stopQuietly(rec);
      if (!_disposed) state = state.copyWith(clearCountdown: true);
      return;
    }
    String id;
    try {
      id = await repo.startTrip(quality: q == VideoQuality.p1080 ? 1080 : 720);
    } catch (_) {
      await _stopQuietly(rec);
      failed();
      return;
    }
    if (_beginCancelled || _disposed) {
      await _stopQuietly(rec);
      try {
        await repo.interruptTrip(id);
      } catch (_) {}
      if (!_disposed) state = state.copyWith(clearCountdown: true);
      return;
    }
    final first = GeoPoint(f.lat, f.lng, time: f.time);
    _lastPoint = first;
    state = HomeState(
      camera: state.camera,
      fix: state.fix,
      recording: true,
      tripId: id,
      track: [first],
      muted: state.muted,
      quality: q,
      online: state.online,
    );
    _persist(id, state.fix!);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      // عدّ ثوانٍ؛ المدة الرسمية للرحلة من نتيجة المُسجِّل/القاعدة عند الإيقاف.
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    try {
      await awake.enable();
    } catch (_) {}
  }

  /// إطار خريطة من الشاشة (~2/ث). أخطاء الدفع لا توقف التسجيل.
  Future<void> pushMapFrame(RgbaFrame frame) async {
    if (!state.recording || state.saving) return;
    try {
      await ref.read(recorderProvider).pushMapFrame(frame);
    } catch (_) {}
  }

  /// يوقف ويحفظ (بعد تأكيد المستخدم في الشاشة). لا يبقى saving=true مهما فشل.
  Future<void> stop() async {
    final id = state.tripId;
    if (!state.recording || state.saving || id == null) return;
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(saving: true);
    final repo = ref.read(tripRepositoryProvider);
    final rec = ref.read(recorderProvider);
    final awake = ref.read(screenAwakeProvider);
    await _writes;
    String? path;
    try {
      path = (await rec.stop()).path;
    } catch (_) {
      path = null; // المسار محفوظ دائماً؛ الفيديو لم يُحفظ.
    }
    var dbError = false;
    try {
      if (path != null) {
        await repo.completeTrip(id, videoPath: path);
      } else {
        await repo.interruptTrip(id);
      }
    } catch (_) {
      dbError = true;
      try {
        await repo.interruptTrip(id, videoPath: path);
        dbError = false; // الاحتياط نجح.
      } catch (_) {}
    }
    await _finish(FinishedTrip(id, dbError: dbError), awake);
  }

  void _onRecorderEvent(RecorderEvent e) {
    if (e is RecordingInterrupted) _onInterrupted(e);
  }

  /// انقطاع أصلي: المُسجِّل حفظ ما صُوِّر؛ نحفظ المسار والملف ونبلغ المستخدم.
  Future<void> _onInterrupted(RecordingInterrupted e) async {
    final id = state.tripId;
    if (_disposed || !state.recording || state.saving || id == null) return;
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(saving: true);
    final repo = ref.read(tripRepositoryProvider);
    final awake = ref.read(screenAwakeProvider);
    await _writes;
    var dbError = false;
    try {
      await repo.interruptTrip(id, videoPath: e.result.path);
    } catch (_) {
      dbError = true;
    }
    await _finish(
      FinishedTrip(id, interruptReason: e.reason, dbError: dbError),
      awake,
    );
  }

  Future<void> _finish(FinishedTrip done, ScreenAwake awake) async {
    _lastPoint = null;
    try {
      await awake.disable();
    } catch (_) {}
    if (_disposed) return;
    state = HomeState(
      camera: state.camera,
      fix: state.fix,
      muted: state.muted,
      quality: state.quality,
      online: state.online,
      finished: done,
    );
  }

  void consumeFinished() => state = state.copyWith(clearFinished: true);
  void clearNotice() => state = state.copyWith(clearNotice: true);

  void toggleMute() {
    final m = !state.muted;
    state = state.copyWith(muted: m);
    if (state.recording) {
      ref.read(recorderProvider).setMuted(m).catchError((_) {});
    }
  }

  /// الجودة تُغيَّر قبل البدء فقط.
  void setQuality(VideoQuality q) {
    if (state.recording || state.busy) return;
    state = state.copyWith(quality: q);
  }
}

extension on HomeState {
  bool weakFor(LocationFix f) =>
      f.accuracyM == null || f.accuracyM! > weakGpsAccuracyM;
}

final homeProvider = NotifierProvider<HomeController, HomeState>(
  HomeController.new,
);
