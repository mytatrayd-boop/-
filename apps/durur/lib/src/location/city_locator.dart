import 'dart:async';

import '../domain/city.dart';
import 'location_service.dart';
import 'nearest_city.dart';

/// حد قراءة الموقع (SPEC الميزة 4 بند 4، D11).
const Duration locationTimeLimit = Duration(seconds: 10);

/// نتيجة محاولة تحديد المدينة بالموقع.
sealed class LocateResult {
  const LocateResult();
}

/// وُجدت أقرب مدينة ضمن الحد. لا تحمل الإحداثيات عمداً.
final class LocateFound extends LocateResult {
  const LocateFound(this.city);

  final City city;
}

/// رفض المستخدم الإذن الآن.
final class LocateDenied extends LocateResult {
  const LocateDenied();
}

/// الموقع غير متاح: رفض دائم سابق، أو خدمة الموقع مطفأة، أو خطأ من النظام.
final class LocateUnavailable extends LocateResult {
  const LocateUnavailable();
}

/// لم تصل قراءة خلال [locationTimeLimit].
final class LocateTimeout extends LocateResult {
  const LocateTimeout();
}

/// أقرب مدينة أبعد من [maxNearestCityKm] (خارج الخليج).
final class LocateOutOfRange extends LocateResult {
  const LocateOutOfRange();
}

/// يحدد أقرب مدينة بقراءة موقع **واحدة** (ARCHITECTURE §7). Dart صافٍ.
///
/// الإحداثيات تبقى متغيراً محلياً داخل [locate] فقط: لا تُحفظ ولا تُعاد
/// ولا تُرسل؛ الناتج مدينة من القائمة أو حالة خطأ.
class CityLocator {
  const CityLocator(this._service, {this.timeLimit = locationTimeLimit});

  final LocationService _service;
  final Duration timeLimit;

  Future<LocateResult> locate(List<City> cities) async {
    try {
      if (!await _service.isServiceEnabled()) return const LocateUnavailable();

      switch (await _service.checkPermission()) {
        case LocationAccess.deniedForever:
        case LocationAccess.unknown:
          return const LocateUnavailable();
        case LocationAccess.denied:
          final requested = await _service.requestPermission();
          if (requested == LocationAccess.unknown) {
            return const LocateUnavailable();
          }
          if (requested != LocationAccess.granted) return const LocateDenied();
        case LocationAccess.granted:
          break;
      }

      // حد المكتبة نفسه + حد هنا احتياطاً إن تجاهلته المنصة.
      final position = await _service
          .getApproximatePosition(timeLimit: timeLimit)
          .timeout(timeLimit);
      final nearest = findNearestCity(cities, position.lat, position.lon);
      if (nearest == null || !nearest.inRange) return const LocateOutOfRange();
      return LocateFound(nearest.city);
    } on TimeoutException {
      return const LocateTimeout();
    } on LocationPermissionException {
      return const LocateDenied();
    } on Exception {
      return const LocateUnavailable();
    }
  }
}
