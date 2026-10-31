import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum LocationFailure { denied, deniedForever, serviceDisabled, timeout, error }

/// نتيجة طلب الموقع: إحداثيات أو سبب الفشل.
class LocationResult {
  const LocationResult.success(double this.lat, double this.lng) : failure = null;
  const LocationResult.failure(LocationFailure this.failure)
      : lat = null,
        lng = null;

  final double? lat;
  final double? lng;
  final LocationFailure? failure;

  bool get isSuccess => failure == null;
}

abstract class LocationService {
  /// موقع واحد بإذن «عند الاستخدام». لا يرمي؛ الفشل يُعاد في [LocationResult].
  Future<LocationResult> getCurrentLocation({Duration timeout = const Duration(seconds: 10)});
}

class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({GeolocatorPlatform? platform}) : _p = platform ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _p;

  @override
  Future<LocationResult> getCurrentLocation({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      if (!await _p.isLocationServiceEnabled()) {
        return const LocationResult.failure(LocationFailure.serviceDisabled);
      }
      var permission = await _p.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied) {
        permission = await _p.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.failure(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        return const LocationResult.failure(LocationFailure.denied);
      }
      final pos = await _p.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeout),
      );
      return LocationResult.success(pos.latitude, pos.longitude);
    } on TimeoutException {
      return const LocationResult.failure(LocationFailure.timeout);
    } catch (_) {
      return const LocationResult.failure(LocationFailure.error);
    }
  }
}
