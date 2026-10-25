import 'package:geolocator/geolocator.dart';

/// إحداثيات قراءة واحدة.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// تعذّر تحديد الموقع لأي سبب (رفض الصلاحية، خدمة مطفأة، مهلة 10 ث).
/// الشاشة تعرض رسالة واحدة ويبقى الحفظ بالاسم متاحاً (SPEC F6).
class LocationUnavailable implements Exception {
  const LocationUnavailable(this.cause);

  final String cause;

  @override
  String toString() => 'LocationUnavailable($cause)';
}

/// الموقع يُقرأ فقط عند ضغط «حفظ موقعي» (ARCHITECTURE §6): قراءة واحدة بدقة
/// متوسطة ومهلة 10 ثوانٍ، والصلاحية تُطلب عندها فقط. لا تتبع.
abstract interface class LocationService {
  Future<GeoPoint> currentPosition();

  /// يفتح إعدادات الموقع/التطبيق لتفعيل الصلاحية.
  Future<void> openSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  static const timeLimit = Duration(seconds: 10);

  @override
  Future<GeoPoint> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationUnavailable('service_disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        throw const LocationUnavailable('permission_denied');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeLimit,
        ),
      );
      return GeoPoint(p.latitude, p.longitude);
    } on LocationUnavailable {
      rethrow;
    } on Exception catch (e) {
      // مهلة، صلاحية، خدمة مطفأة، أو خطأ منصة: نفس السلوك للمستخدم.
      throw LocationUnavailable(e.runtimeType.toString());
    }
  }

  @override
  Future<void> openSettings() async {
    final opened = await Geolocator.openLocationSettings();
    if (!opened) await Geolocator.openAppSettings();
  }
}
