import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/geo/distance.dart';
import '../../core/geo/geo_point.dart';
import '../../data/camera/camera_preview_source.dart';
import '../../data/location/location_source.dart';
import '../../data/map/map_tiles.dart';
import '../../data/network/network_status_source.dart';
import '../../data/platform/screen_awake.dart';
import '../../data/permissions/permission_service.dart';
import '../onboarding_permissions/permissions_controller.dart';

const _camPerm = AppPermission.camera;
const _granted = AppPermissionStatus.granted;

// الاعتماديات على الجهاز، تُستبدل في الاختبارات بنسخ مزيّفة.
final locationSourceProvider = Provider<LocationSource>(
  (_) => const GeolocatorLocationSource(),
);
final cameraPreviewSourceProvider = Provider<CameraPreviewSource>(
  (_) => const NativeCameraPreviewSource(),
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
  );
}

class HomeController extends Notifier<HomeState> {
  StreamSubscription<LocationFix>? _locSub;
  StreamSubscription<bool>? _netSub;
  Timer? _timer;
  bool _disposed = false;
  bool _cameraWanted = false;

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
      _timer?.cancel();
      if (_cameraWanted) camera.close();
      awake.disable();
    });
    ref.listen(permissionsProvider, (_, p) => _sync(p));
    // بعد عودة build (state غير جاهزة قبلها).
    Future.microtask(() {
      if (_disposed) return;
      _sync(ref.read(permissionsProvider));
      _watchNetwork();
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

  bool get canStart => !state.recording && blocker == null;

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
    if (state.recording && p.isValid && !state.weakFor(f)) {
      final t = [...state.track, p];
      state = state.copyWith(fix: f, track: t, distanceM: pathLengthMeters(t));
    } else {
      state = state.copyWith(fix: f);
    }
  }

  /// بدء جلسة (F5: واجهة فقط؛ لا ترميز ولا حفظ). يُرفض بلا كاميرا وموقع.
  Future<void> start() async {
    if (!canStart) return;
    final f = state.fix!;
    state = HomeState(
      camera: state.camera,
      fix: f,
      recording: true,
      track: [GeoPoint(f.lat, f.lng, time: f.time)],
      muted: state.muted,
      quality: state.quality,
      online: state.online,
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      // عدّ ثوانٍ لواجهة F5 فقط؛ في F6 يُؤخذ الزمن من ساعة التسجيل.
      state = state.copyWith(
        elapsed: state.elapsed + const Duration(seconds: 1),
      );
    });
    await ref.read(screenAwakeProvider).enable();
  }

  Future<void> stop() async {
    if (!state.recording) return;
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(recording: false);
    await ref.read(screenAwakeProvider).disable();
  }

  void toggleMute() => state = state.copyWith(muted: !state.muted);

  /// الجودة تُغيَّر قبل البدء فقط.
  void setQuality(VideoQuality q) {
    if (state.recording) return;
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
