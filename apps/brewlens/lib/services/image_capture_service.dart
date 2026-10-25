
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart' as picker;

enum CaptureSource { camera, gallery }

/// رفض صلاحية الكاميرا أو المعرض.
class CaptureAccessDenied implements Exception {
  const CaptureAccessDenied(this.source);

  final CaptureSource source;
}

/// الصورة عبر image_picker (D17): كاميرا النظام أو المعرض، مضغوطة لأطول ضلع
/// 1024 بكسل وجودة 80 (نحو 300 ك.ب، SPEC F5 معيار 3).
abstract interface class ImageCaptureService {
  /// null إذا ألغى المستخدم.
  Future<Uint8List?> pick(CaptureSource source);

  /// أندرويد قد يُنهي التطبيق أثناء الكاميرا؛ يستعيد الصورة عند العودة.
  Future<Uint8List?> retrieveLost();

  Future<void> openAppSettings();
}

class ImagePickerCaptureService implements ImageCaptureService {
  ImagePickerCaptureService([picker.ImagePicker? imagePicker])
      : _picker = imagePicker ?? picker.ImagePicker();

  static const maxSide = 1024.0;
  static const quality = 80;

  final picker.ImagePicker _picker;

  @override
  Future<Uint8List?> pick(CaptureSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == CaptureSource.camera
            ? picker.ImageSource.camera
            : picker.ImageSource.gallery,
        maxWidth: maxSide,
        maxHeight: maxSide,
        imageQuality: quality,
        preferredCameraDevice: picker.CameraDevice.rear,
      );
      return file == null ? null : await file.readAsBytes();
    } on PlatformException catch (e) {
      if (e.code.contains('access_denied') || e.code.contains('permission')) {
        throw CaptureAccessDenied(source);
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List?> retrieveLost() async {
    if (!Platform.isAndroid) return null;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty) return null;
      final file = response.file ?? response.files?.firstOrNull;
      return file == null ? null : await file.readAsBytes();
    } on Object {
      return null;
    }
  }

  // geolocator يوفّر فتح إعدادات التطبيق؛ لا حاجة لحزمة صلاحيات إضافية.
  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();
}
