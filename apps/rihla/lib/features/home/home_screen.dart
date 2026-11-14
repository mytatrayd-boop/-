import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:rihla_recorder/rihla_recorder.dart';

import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding_permissions/permissions_controller.dart';
import 'home_controller.dart';
import 'map_frame_capturer.dart';
import 'widgets/controls.dart';
import 'widgets/recording_map.dart';

/// الشاشة الرئيسية المقسومة (DESIGN 7.2): الكاميرا يمين والخريطة يسار، 50/50،
/// ثابتة ولا تنعكس مع اللغة (تطابق الفيديو الناتج).
/// F6: عدّ تنازلي، بدء/إيقاف فعلي عبر المُسجِّل، التقاط الخريطة ~2/ث، حوار تأكيد.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _mapBoundaryKey = GlobalKey();
  Timer? _frameTimer;
  bool _grabbing = false;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // الأذونات قد تتغير من إعدادات الجوال أو من الشاشة السابقة.
    Future.microtask(() => ref.read(permissionsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      ref.read(permissionsProvider.notifier).refresh();
    }
  }

  void _setCapturing(bool on) {
    if (!on) {
      _frameTimer?.cancel();
      _frameTimer = null;
    } else {
      _frameTimer ??= Timer.periodic(mapFrameInterval, (_) => _grab());
    }
  }

  Future<void> _grab() async {
    if (_grabbing) return;
    _grabbing = true;
    try {
      final st = ref.read(homeProvider);
      if (!st.recording || st.saving) return;
      final q = st.quality == VideoQuality.p1080
          ? RecorderQuality.p1080
          : RecorderQuality.p720;
      final frame = await captureMapFrame(_mapBoundaryKey, q.mapWidth);
      if (frame != null && mounted) {
        await ref.read(homeProvider.notifier).pushMapFrame(frame);
      }
    } finally {
      _grabbing = false;
    }
  }

  Future<void> _confirmStop() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('stop-dialog'),
        title: Text(l.stopConfirmTitle),
        content: Text(l.stopConfirmBody),
        actions: [
          // الإجراء الآمن (المتابعة) أولاً أي على جهة البداية.
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              key: const ValueKey('stop-continue'),
              onPressed: () => Navigator.of(c).pop(false),
              child: Text(l.stopConfirmContinue),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              key: const ValueKey('stop-confirm'),
              onPressed: () => Navigator.of(c).pop(true),
              child: Text(l.stopConfirmEnd),
            ),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (ok == true && mounted) await ref.read(homeProvider.notifier).stop();
  }

  void _onStateChange(HomeState? prev, HomeState next) {
    _setCapturing(next.recording && !next.saving);
    final fin = next.finished;
    if (fin != null && prev?.finished != fin) {
      if (_dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      ref.read(homeProvider.notifier).consumeFinished();
      context.go(
        AppRoutes.summaryFor(fin.tripId, reason: fin.interruptReason?.name),
      );
    }
    if (next.notice == HomeNotice.startFailed && prev?.notice != next.notice) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.startFailed),
          duration: const Duration(seconds: 4),
        ),
      );
      ref.read(homeProvider.notifier).clearNotice();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(homeProvider, _onStateChange);
    final st = ref.watch(homeProvider);
    final ctl = ref.read(homeProvider.notifier);
    final perms = ref.watch(permissionsProvider);
    final blocker = perms.canStartRecording
        ? switch (st.camera) {
            CameraStatus.error => StartBlocker.cameraError,
            CameraStatus.ready =>
              st.fix == null ? StartBlocker.waitingGps : null,
            _ => StartBlocker.cameraOpening,
          }
        : StartBlocker.permissions;
    final canStart = !st.recording && !st.busy && blocker == null;
    final counting = st.countdown != null;
    final camera = ref.read(cameraPreviewSourceProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // التقسيم ثابت: اليسار خريطة واليمين كاميرا بصرف النظر عن اللغة.
            Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  child: RecordingMap(
                    boundaryKey: _mapBoundaryKey,
                    tiles: ref.watch(mapTilesProvider),
                    fix: st.fix,
                    track: st.track,
                    interactive: !st.recording,
                  ),
                ),
                Expanded(
                  child: CameraHalf(
                    status: st.camera,
                    preview: st.camera == CameraStatus.ready
                        ? camera.buildPreview(context)
                        : null,
                    blocker: blocker,
                    canStart: canStart,
                    recording: st.recording,
                    onRetryCamera: ctl.openCamera,
                    onOpenPermissions: () =>
                        context.push(AppRoutes.permissions),
                  ),
                ),
              ],
            ),
            Positioned(
              // فيزيائي (لا ينعكس): يترك يمين الشاشة لشريط التحكم.
              top: 8,
              left: 8,
              right: 16 + 88 + 8,
              child: TopBar(
                state: st,
                onSettings: () => context.push(AppRoutes.settings),
              ),
            ),
            // شريط التحكم على الحافة اليمنى (قرب إبهام السائق، DESIGN 7.2).
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: ControlStrip(
                  recording: st.recording,
                  canStart: canStart || counting,
                  muted: st.muted,
                  quality: st.quality,
                  onStartStop: st.recording
                      ? _confirmStop
                      : counting
                      ? ctl.cancelCountdown
                      : ctl.start,
                  onToggleMute: ctl.toggleMute,
                  onQuality: (q) => ctl.setQuality(q),
                ),
              ),
            ),
            if (counting)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('countdown-overlay'),
                  behavior: HitTestBehavior.opaque,
                  onTap: ctl.cancelCountdown,
                  child: ColoredBox(
                    color: const Color(0x99000000),
                    child: Center(
                      child: Semantics(
                        label: AppLocalizations.of(
                          context,
                        ).countdownLabel(st.countdown!),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${st.countdown}',
                              key: const ValueKey('countdown-number'),
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(fontSize: 96),
                            ),
                            Text(
                              AppLocalizations.of(context).countdownCancelHint,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (st.saving)
              Positioned.fill(
                child: AbsorbPointer(
                  child: ColoredBox(
                    key: const ValueKey('saving-overlay'),
                    color: const Color(0xCC000000),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context).savingTrip,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(AppLocalizations.of(context).savingDoNotClose),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (!st.online)
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: OfflineBanner(
                    text: AppLocalizations.of(context).offlineBanner,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
