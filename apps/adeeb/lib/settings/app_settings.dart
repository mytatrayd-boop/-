import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/reader_settings.dart';

/// لغة الواجهة المختارة في الإعدادات (DESIGN §13.1).
enum AppLanguage { system, ar, en }

/// اللغة الفعلية: «حسب الجهاز» = الإنجليزية إن كانت لغة الجهاز إنجليزية،
/// وإلا العربية (العربية أولاً).
Locale resolveAppLocale(AppLanguage language, Locale device) =>
    switch (language) {
      AppLanguage.ar => const Locale('ar'),
      AppLanguage.en => const Locale('en'),
      AppLanguage.system =>
        device.languageCode == 'en' ? const Locale('en') : const Locale('ar'),
    };

class AppSettings {
  const AppSettings({
    this.language = AppLanguage.system,
    this.themeMode = ThemeMode.system,
  });

  final AppLanguage language;
  final ThemeMode themeMode;
}

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

/// اللغة والمظهر، محفوظان في shared_preferences ويُطبَّقان فوراً.
class AppSettingsController extends AsyncNotifier<AppSettings> {
  static const languageKey = 'app.language';
  static const themeKey = 'app.theme_mode';

  @override
  Future<AppSettings> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final language = prefs.getString(languageKey);
    final theme = prefs.getString(themeKey);
    return AppSettings(
      language:
          AppLanguage.values.where((l) => l.name == language).firstOrNull ??
          AppLanguage.system,
      themeMode:
          ThemeMode.values.where((m) => m.name == theme).firstOrNull ??
          ThemeMode.system,
    );
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Future<void> setLanguage(AppLanguage language) async {
    state = AsyncData(
      AppSettings(language: language, themeMode: _current.themeMode),
    );
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(languageKey, language.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData(
      AppSettings(language: _current.language, themeMode: mode),
    );
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setString(themeKey, mode.name);
  }
}
