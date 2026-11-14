import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding_permissions/permissions_controller.dart';
import 'home_controller.dart';
import 'widgets/controls.dart';
import 'widgets/recording_map.dart';

/// الشاشة الرئيسية المقسومة (DESIGN 7.2): الكاميرا يمين والخريطة يسار، 50/50،
/// ثابتة ولا تنعكس مع اللغة (تطابق الفيديو الناتج).
/// F5: واجهة وتحكم فقط. لا ترميز ولا حفظ (F6).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  final _mapBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // الأذونات قد تتغير من إعدادات الجوال أو من الشاشة السابقة.
    Future.microtask(() => ref.read(permissionsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      ref.read(permissionsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
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
    final canStart = !st.recording && blocker == null;
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
                  canStart: canStart,
                  muted: st.muted,
                  quality: st.quality,
                  onStartStop: st.recording ? ctl.stop : ctl.start,
                  onToggleMute: ctl.toggleMute,
                  onQuality: (q) => ctl.setQuality(q),
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
