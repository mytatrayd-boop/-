import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// اللغة المختارة. null = تتبع النظام (والعربية إن لم تُدعم).
/// الحفظ الدائم والتبديل من الإعدادات في F11.
class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void set(Locale? locale) => state = locale;
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
