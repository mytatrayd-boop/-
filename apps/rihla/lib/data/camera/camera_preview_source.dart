import 'package:flutter/widgets.dart';
import 'dart:async';

import 'package:rihla_recorder/rihla_recorder.dart';

import '../settings/camera_rotation_store.dart';

class CameraOpenException implements Exception {
  const CameraOpenException([this.message]);
  final String? message;
  @override
  String toString() => 'CameraOpenException(${message ?? ''})';
}

/// واجهة مجردة لمعاينة الكاميرا. الكاميرا الحقيقية تملكها الإضافة الأصلية
/// rihla_recorder (ARCHITECTURE 4.1) وتعرض Texture؛ تُوصَّل في F0ب/F6.
abstract class CameraPreviewSource {
  /// يفتح الكاميرا. يرمي [CameraOpenException] عند الفشل (مشغولة، مرفوضة).
  Future<void> open();
  Future<void> close();

  /// ويدجت المعاينة (تُستدعى بعد نجاح open).
  Widget buildPreview(BuildContext context);
}

/// التنفيذ الحقيقي: الكاميرا تملكها الإضافة الأصلية rihla_recorder وتعرض Texture.
/// المعاينة تُقصّ بنمط cover (نفس القص المركزي للفيديو، D16). غير مجرَّب على جهاز.
class NativeCameraPreviewSource implements CameraPreviewSource {
  NativeCameraPreviewSource(
    this._recorder, {
    this.quality = RecorderQuality.p720,
    CameraRotationStore rotationStore = const SharedPrefsCameraRotationStore(),
  }) : _store = rotationStore;

  final RihlaRecorder _recorder;
  final RecorderQuality quality;
  final CameraRotationStore _store;
  CameraInfo? _info;

  /// الأبعاد المعروضة (بعد الدوران)؛ تتبدل عند 90/270 بحدث previewSize من الجانب الأصلي.
  final ValueNotifier<Size?> _displayed = ValueNotifier<Size?>(null);
  StreamSubscription<RecorderEvent>? _sub;

  @override
  Future<void> open() async {
    try {
      // الإزاحة المحفوظة تُمرَّر قبل الفتح فتكون مطبَّقة على المعاينة والتسجيل (best-effort).
      try {
        await _recorder.setRotationOffset(await _store.load());
      } on RecorderException {
        // تبقى القيمة الأصلية الافتراضية.
      }
      unawaited(_sub?.cancel());
      _sub = _recorder.events.listen((e) {
        if (e is PreviewSizeChanged && _info != null) {
          _displayed.value = Size(e.width.toDouble(), e.height.toDouble());
        }
      }, onError: (Object _) {});
      _info = await _recorder.openCamera(quality: quality);
      _displayed.value = Size(_info!.width.toDouble(), _info!.height.toDouble());
    } on RecorderException catch (e) {
      _info = null;
      throw CameraOpenException(
        '${e.code}${e.message == null ? '' : ': ${e.message}'}',
      );
    }
  }

  @override
  Future<void> close() async {
    _info = null;
    unawaited(_sub?.cancel());
    _sub = null;
    try {
      await _recorder.closeCamera();
    } on RecorderException {
      // الإغلاق best-effort.
    }
  }

  @override
  Widget buildPreview(BuildContext context) {
    final i = _info;
    if (i == null) return const SizedBox.shrink();
    return ValueListenableBuilder<Size?>(
      valueListenable: _displayed,
      builder: (context, size, _) => ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: (size?.width ?? i.width.toDouble()),
            height: (size?.height ?? i.height.toDouble()),
            child: Texture(textureId: i.textureId),
          ),
        ),
      ),
    );
  }
}
