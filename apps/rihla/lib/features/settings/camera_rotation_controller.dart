import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

import '../../data/settings/camera_rotation_store.dart';
import '../home/home_controller.dart' show recorderProvider;

final cameraRotationStoreProvider = Provider<CameraRotationStore>(
  (_) => const SharedPrefsCameraRotationStore(),
);

/// إعداد «تدوير الكاميرا» (إزاحة مع عقارب الساعة فوق الحساب). يبدأ بالافتراضي ثم يحمّل المحفوظ.
class CameraRotationNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return defaultCameraRotation;
  }

  bool _changed = false;

  Future<void> _load() async {
    final v = await ref.read(cameraRotationStoreProvider).load();
    if (!_changed && ref.mounted) state = v;
  }

  /// يحفظ ويطبّق فوراً على المعاينة/الفيديو عبر القناة (الفشل في التطبيق لا يمنع الحفظ).
  Future<void> set(int degrees) async {
    final v = sanitizeCameraRotation(degrees);
    _changed = true;
    state = v;
    await ref.read(cameraRotationStoreProvider).save(v);
    try {
      await ref.read(recorderProvider).setRotationOffset(v);
    } on RecorderException {
      // لا كاميرا/منصة غير مدعومة: القيمة محفوظة وتُمرَّر عند الفتح.
    }
  }
}

final cameraRotationProvider = NotifierProvider<CameraRotationNotifier, int>(
  CameraRotationNotifier.new,
);

/// آخر قيم تشخيص جُلبت من الجانب الأصلي (null قبل أول جلب).
class OrientationInfoNotifier extends Notifier<OrientationInfo?> {
  @override
  OrientationInfo? build() => null;

  Future<void> refresh() async {
    try {
      final i = await ref.read(recorderProvider).getOrientationInfo();
      if (ref.mounted) state = i;
    } on RecorderException {
      // تبقى آخر قيمة.
    }
  }
}

final orientationInfoProvider =
    NotifierProvider<OrientationInfoNotifier, OrientationInfo?>(
      OrientationInfoNotifier.new,
    );
