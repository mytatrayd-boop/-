/// واجهة قراءة الموقع (ARCHITECTURE §7)، بلا اعتماد على أي مكتبة، لتُستبدل
/// في الاختبارات. التنفيذ الحقيقي في `geolocator_location_service.dart`.
///
/// عمداً لا توجد طريقة بث أو قراءة في الخلفية: قراءة واحدة فقط (SPEC الميزة 4).
abstract interface class LocationService {
  /// هل خدمة الموقع مفعّلة في الجهاز؟
  Future<bool> isServiceEnabled();

  /// حالة الإذن الحالية بلا سؤال المستخدم.
  Future<LocationAccess> checkPermission();

  /// يطلب إذن الموقع **التقريبي** أثناء الاستخدام من النظام.
  Future<LocationAccess> requestPermission();

  /// قراءة واحدة بدقة منخفضة. ترمي [LocationUnavailableException]
  /// أو [LocationPermissionException] أو `TimeoutException` بعد [timeLimit].
  Future<ApproximatePosition> getApproximatePosition({
    required Duration timeLimit,
  });
}

/// حالة إذن الموقع.
enum LocationAccess {
  /// غير ممنوح، ويمكن طلبه.
  denied,

  /// مرفوض نهائياً (لا يظهر طلب النظام مرة أخرى).
  deniedForever,

  /// ممنوح.
  granted,

  /// لا يمكن معرفته (المنصة لا تدعم).
  unknown,
}

/// إحداثيات قراءة واحدة. تُستخدم لحظياً لاختيار أقرب مدينة ثم تُترك؛
/// **لا تُحفظ ولا تُرسل** (D11).
class ApproximatePosition {
  const ApproximatePosition(this.lat, this.lon);

  final double lat;
  final double lon;
}

/// خدمة الموقع معطّلة أو تعذّرت القراءة لسبب من النظام.
class LocationUnavailableException implements Exception {
  const LocationUnavailableException([this.message]);

  final String? message;

  @override
  String toString() => 'LocationUnavailableException: $message';
}

/// سحب الإذن أثناء القراءة.
class LocationPermissionException implements Exception {
  const LocationPermissionException();
}
