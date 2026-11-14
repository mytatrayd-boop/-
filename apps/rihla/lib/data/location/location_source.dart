import 'package:geolocator/geolocator.dart' as geo;

/// قراءة موقع واحدة.
class LocationFix {
  const LocationFix({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.headingDeg,
    this.speedMps,
    required this.time,
  });

  final double lat;
  final double lng;

  /// الدقة الأفقية بالمتر (null إن لم تُعرف).
  final double? accuracyM;

  /// الاتجاه بالدرجات (null إن لم يُعرف أو كان الجهاز ساكناً).
  final double? headingDeg;
  final double? speedMps;
  final DateTime time;
}

/// واجهة مجردة لـGPS. التنفيذ الحقيقي geolocator، والنسخة المزيّفة للاختبار.
abstract class LocationSource {
  /// يبدأ الاستماع عند الاشتراك (يتطلب إذن الموقع الدقيق).
  Stream<LocationFix> fixes();
}

/// التنفيذ الحقيقي. لم يُجرَّب على جهاز.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Stream<LocationFix> fixes() =>
      geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.best,
          distanceFilter: 0,
        ),
      ).map(
        (p) => LocationFix(
          lat: p.latitude,
          lng: p.longitude,
          accuracyM: p.accuracy,
          headingDeg: p.heading >= 0 ? p.heading : null,
          speedMps: p.speed >= 0 ? p.speed : null,
          time: p.timestamp,
        ),
      );
}
