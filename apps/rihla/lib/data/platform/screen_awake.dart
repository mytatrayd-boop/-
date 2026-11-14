import 'package:wakelock_plus/wakelock_plus.dart';

/// إبقاء الشاشة مضاءة أثناء التسجيل. خلف واجهة (features لا تستدعي الأصلي).
abstract class ScreenAwake {
  Future<void> enable();
  Future<void> disable();
}

class WakelockScreenAwake implements ScreenAwake {
  const WakelockScreenAwake();
  @override
  Future<void> enable() => WakelockPlus.enable();
  @override
  Future<void> disable() => WakelockPlus.disable();
}

class FakeScreenAwake implements ScreenAwake {
  bool enabled = false;
  int enableCalls = 0;
  @override
  Future<void> enable() async {
    enabled = true;
    enableCalls++;
  }

  @override
  Future<void> disable() async => enabled = false;
}
