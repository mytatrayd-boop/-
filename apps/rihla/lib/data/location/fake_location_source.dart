import 'dart:async';

import 'location_source.dart';

/// نسخة مزيّفة: تدفع القراءات يدوياً من الاختبار.
class FakeLocationSource implements LocationSource {
  final _ctrl = StreamController<LocationFix>.broadcast();
  int listeners = 0;

  void push(LocationFix f) => _ctrl.add(f);

  void pushAt(
    double lat,
    double lng, {
    double accuracy = 5,
    double? heading,
    DateTime? time,
  }) => push(
    LocationFix(
      lat: lat,
      lng: lng,
      accuracyM: accuracy,
      headingDeg: heading,
      time: time ?? DateTime.utc(2026, 1, 1),
    ),
  );

  @override
  Stream<LocationFix> fixes() => Stream.multi((c) {
    listeners++;
    final sub = _ctrl.stream.listen(c.add);
    c.onCancel = () {
      listeners--;
      return sub.cancel();
    };
  });
}
