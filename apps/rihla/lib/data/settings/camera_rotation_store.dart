import 'package:rihla_recorder/rihla_recorder.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// القيم المسموحة لإعداد «تدوير الكاميرا» (درجات مع عقارب الساعة، إزاحة فوق الحساب).
const cameraRotationChoices = [0, 90, 180, 270];

/// الافتراضي 270 (قرار مؤقت في DECISIONS.md): يصحح ما رُصد على جهاز المالك.
const defaultCameraRotation = OrientationInfo.defaultRotationOffset;

/// قيمة صالحة فقط، وإلا الافتراضي.
int sanitizeCameraRotation(int? v) => cameraRotationChoices.contains(v) ? v! : defaultCameraRotation;

abstract class CameraRotationStore {
  Future<int> load();
  Future<void> save(int degrees);
}

class SharedPrefsCameraRotationStore implements CameraRotationStore {
  const SharedPrefsCameraRotationStore();
  static const key = 'camera_rotation_offset';

  @override
  Future<int> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return sanitizeCameraRotation(p.getInt(key));
    } catch (_) {
      return defaultCameraRotation;
    }
  }

  @override
  Future<void> save(int degrees) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(key, sanitizeCameraRotation(degrees));
  }
}

class MemoryCameraRotationStore implements CameraRotationStore {
  MemoryCameraRotationStore([this.value]);
  int? value;
  @override
  Future<int> load() async => sanitizeCameraRotation(value);
  @override
  Future<void> save(int degrees) async => value = degrees;
}
