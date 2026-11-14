import 'package:flutter/foundation.dart';

/// سجل تشخيص خفيف (يظهر في `adb logcat -s flutter`). لا بيانات شخصية:
/// أعداد ومعرّفات رحلات فقط، بلا إحداثيات.
void rlog(String message) => debugPrint('[rihla] $message');
