import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// توجيه الشاشة: التطبيق طولي، وشاشة التسجيل وحدها أفقية.
abstract class ScreenOrientation {
  Future<void> landscape();
  Future<void> portrait();
}

class SystemScreenOrientation implements ScreenOrientation {
  const SystemScreenOrientation();

  @override
  Future<void> landscape() => SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  @override
  Future<void> portrait() => SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}

class FakeScreenOrientation implements ScreenOrientation {
  final calls = <String>[];
  @override
  Future<void> landscape() async => calls.add('landscape');
  @override
  Future<void> portrait() async => calls.add('portrait');
}

final screenOrientationProvider = Provider<ScreenOrientation>(
  (_) => const SystemScreenOrientation(),
);
