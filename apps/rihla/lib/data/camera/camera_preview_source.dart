import 'package:flutter/widgets.dart';

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

/// مكان التنفيذ الحقيقي: الإضافة الأصلية غير مبنية بعد (D12)، فيفشل open
/// دائماً بصدق بدل عرض معاينة وهمية على جهاز حقيقي.
class NativeCameraPreviewSource implements CameraPreviewSource {
  const NativeCameraPreviewSource();

  @override
  Future<void> open() => throw const CameraOpenException(
    'native camera plugin not built yet (F0b)',
  );

  @override
  Future<void> close() async {}

  @override
  Widget buildPreview(BuildContext context) => const SizedBox.shrink();
}
