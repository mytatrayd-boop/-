import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// التنفيذ الحقيقي فوق geolocator: دقة منخفضة، قراءة واحدة، بلا بث.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationAccess> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<LocationAccess> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<ApproximatePosition> getApproximatePosition({
    required Duration timeLimit,
  }) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: timeLimit,
        ),
      );
      return ApproximatePosition(p.latitude, p.longitude);
    } on PermissionDeniedException {
      throw const LocationPermissionException();
    } on LocationServiceDisabledException {
      throw const LocationUnavailableException('service disabled');
    } on PermissionDefinitionsNotFoundException catch (e) {
      throw LocationUnavailableException(e.toString());
    } on PermissionRequestInProgressException catch (e) {
      throw LocationUnavailableException(e.toString());
    } on PositionUpdateException catch (e) {
      throw LocationUnavailableException(e.toString());
    }
  }

  static LocationAccess _map(LocationPermission p) => switch (p) {
    LocationPermission.denied => LocationAccess.denied,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    LocationPermission.whileInUse ||
    LocationPermission.always => LocationAccess.granted,
    LocationPermission.unableToDetermine => LocationAccess.unknown,
  };
}
