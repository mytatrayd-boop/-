import 'dart:async';

import 'package:durur/src/location/location_service.dart';

/// خدمة موقع وهمية تسجّل كل نداء (بلا مكتبات محاكاة، ARCHITECTURE §3).
class FakeLocationService implements LocationService {
  FakeLocationService({
    this.serviceEnabled = true,
    this.permission = LocationAccess.granted,
    this.afterRequest = LocationAccess.granted,
    this.position,
    this.error,
    this.pending,
  });

  /// إحداثيات قريبة من مركز الرياض.
  static const riyadh = ApproximatePosition(24.70, 46.70);

  /// قرب مسقط.
  static const muscat = ApproximatePosition(23.60, 58.50);

  /// لندن: خارج الخليج.
  static const london = ApproximatePosition(51.5074, -0.1278);

  bool serviceEnabled;
  LocationAccess permission;
  LocationAccess afterRequest;
  ApproximatePosition? position;

  /// يُرمى عند القراءة بدل إرجاع [position].
  Object? error;

  /// إن وُجد: القراءة تنتظره (لاختبار التأخر والإلغاء).
  Completer<ApproximatePosition>? pending;

  int serviceChecks = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int reads = 0;
  Duration? lastTimeLimit;

  int get totalCalls =>
      serviceChecks + permissionChecks + permissionRequests + reads;

  @override
  Future<bool> isServiceEnabled() async {
    serviceChecks++;
    return serviceEnabled;
  }

  @override
  Future<LocationAccess> checkPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<LocationAccess> requestPermission() async {
    permissionRequests++;
    permission = afterRequest;
    return afterRequest;
  }

  @override
  Future<ApproximatePosition> getApproximatePosition({
    required Duration timeLimit,
  }) async {
    reads++;
    lastTimeLimit = timeLimit;
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return position ?? riyadh;
  }
}
