import 'package:flutter/widgets.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

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
  });

  final RihlaRecorder _recorder;
  final RecorderQuality quality;
  CameraInfo? _info;

  @override
  Future<void> open() async {
    try {
      _info = await _recorder.openCamera(quality: quality);
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
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: i.width.toDouble(),
          height: i.height.toDouble(),
          child: Texture(textureId: i.textureId),
        ),
      ),
    );
  }
}
