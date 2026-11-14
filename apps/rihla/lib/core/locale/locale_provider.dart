import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// اللغة المختارة. null = تتبع النظام. العربية افتراضية إن لم تُدعم لغة النظام.
/// الحفظ الدائم والتبديل من الإعدادات في F11.
final localeProvider = StateProvider<Locale?>((ref) => null);
