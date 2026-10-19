import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

/// مكان مختار من البحث أو من الموقع الفعلي.
class Place {
  const Place({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final double latitude;
  final double longitude;
}

/// اسم المكان من نتيجة reverse geocoding، بالأولوية:
/// locality، ثم subAdministrativeArea، ثم administrativeArea.
String? placemarkName(
    {String? locality, String? subAdministrativeArea, String? administrativeArea}) {
  for (final n in [locality, subAdministrativeArea, administrativeArea]) {
    final t = n?.trim();
    if (t != null && t.isNotEmpty) return t;
  }
  return null;
}

/// نص البحث كما يُرسل لـ geocoding، مقيداً بالسعودية.
String searchAddress(String query) => '${query.trim()}، السعودية';

/// خدمة الأسماء والبحث (حزمة geocoding) خلف واجهة تُستبدل في الاختبارات.
abstract class PlaceGeocoder {
  /// اسم المكان بالعربية، أو null إن لم يُعرف. يرمي عند فشل الاتصال.
  Future<String?> placeName(double latitude, double longitude);

  /// نتائج البحث عن مدينة أو محافظة. يرمي عند فشل الاتصال.
  Future<List<Place>> search(String query);
}

class GeocodingPlaceGeocoder implements PlaceGeocoder {
  // الحزمة لا تحفظ locale المُمرر للمنشئ (geocoding 5.0.0)، فيُمرر مع كل طلب.
  static const _ar = Locale('ar', 'SA');
  static const _timeout = Duration(seconds: 12);
  static const _maxResults = 5;

  final _geocoding = Geocoding();

  @override
  Future<String?> placeName(double latitude, double longitude) async {
    final marks = await _geocoding
        .placemarkFromCoordinates(latitude, longitude, locale: _ar)
        .timeout(_timeout);
    for (final m in marks) {
      final n = placemarkName(
        locality: m.locality,
        subAdministrativeArea: m.subAdministrativeArea,
        administrativeArea: m.administrativeArea,
      );
      if (n != null) return n;
    }
    return null;
  }

  @override
  Future<List<Place>> search(String query) async {
    final locations = await _geocoding
        .locationFromAddress(searchAddress(query), locale: _ar)
        .timeout(_timeout);
    final out = <Place>[];
    for (final l in locations.take(_maxResults)) {
      String? name;
      try {
        name = await placeName(l.latitude, l.longitude);
      } on Exception catch (e) {
        debugPrint('geocoding name: $e');
      }
      final n = name ?? query.trim();
      if (out.any((p) => p.name == n)) continue;
      out.add(Place(name: n, latitude: l.latitude, longitude: l.longitude));
    }
    return out;
  }
}
