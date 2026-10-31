import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// اللغة الافتراضية عربية (RTL أولاً). اختيار المستخدم يُربط في ميزة الإعدادات لاحقاً.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => const Locale('ar');

  void set(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);
