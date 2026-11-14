import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

import '../../data/camera/camera_preview_source.dart';
import '../../data/platform/screen_orientation.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_controller.dart' show cameraPreviewSourceProvider, recorderProvider;
import 'camera_rotation_controller.dart';
import 'settings_screen.dart';

/// معاينة حية قصيرة لاختبار «تدوير الكاميرا»: تفرض الأفقي (كشاشة التسجيل) وتعرض الأزرار والتشخيص.
/// إن كانت الكاميرا مفتوحة أصلاً (شاشة التسجيل تحتنا) لا نغلقها ولا نغيّر الاتجاه عند الخروج.
class CameraRotationTestPage extends ConsumerStatefulWidget {
  const CameraRotationTestPage({super.key});

  @override
  ConsumerState<CameraRotationTestPage> createState() => _State();
}

class _State extends ConsumerState<CameraRotationTestPage> {
  late final CameraPreviewSource _camera = ref.read(cameraPreviewSourceProvider);
  late final ScreenOrientation _orientation = ref.read(screenOrientationProvider);
  late final RihlaRecorder _recorder = ref.read(recorderProvider);
  late final OrientationInfoNotifier _info = ref.read(orientationInfoProvider.notifier);
  bool _wasOpen = false;
  bool _opened = false;
  bool _failed = false;
  // هل بدأنا تغيير الاتجاه/فتح الكاميرا (فيلزم تنظيفهما عند الخروج المبكر)؟
  bool _touched = false;
  bool _openCalled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _wasOpen = (await _recorder.getOrientationInfo()).cameraOpen;
    } on RecorderException {
      _wasOpen = false;
    }
    // خرج المستخدم قبل أن نفعل شيئاً: لا شيء لتنظيفه.
    if (!mounted) return;
    _touched = true;
    if (!_wasOpen) _orientation.landscape().catchError((_) {});
    try {
      _openCalled = true;
      await _camera.open();
      if (!mounted) {
        // انتهى open بعد الخروج: dispose قد سبقه، فنغلق هنا.
        if (!_wasOpen) _camera.close();
        return;
      }
      setState(() => _opened = true);
      await _info.refresh();
    } on CameraOpenException {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    if (_touched && !_wasOpen) {
      // يغلق حتى لو لم يكتمل open بعد (يُغلق ثانية عند اكتماله).
      if (_openCalled) _camera.close();
      _orientation.portrait().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final offset = ref.watch(cameraRotationProvider);
    final info = ref.watch(orientationInfoProvider);
    ref.listen<int>(cameraRotationProvider, (_, _) {
      // بعد تطبيق الإزاحة نحدّث التشخيص.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _info.refresh();
      });
    });
    return Scaffold(
      appBar: AppBar(title: Text(l.cameraRotationTest)),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _failed
                  ? Center(child: Text(l.cameraRotationOpenFailed))
                  : _opened
                  ? _camera.buildPreview(context)
                  : const Center(child: CircularProgressIndicator()),
            ),
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsetsDirectional.all(12),
                children: [
                  Text(l.cameraRotationTestHint),
                  const SizedBox(height: 12),
                  const RotationChoices(),
                  const SizedBox(height: 12),
                  DiagnosticsTable(info: info, offset: offset),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('camera-test-done'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.cameraRotationDone),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
