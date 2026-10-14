import 'package:adeeb/ask/ask_providers.dart';
import 'package:adeeb/settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('حسب الجهاز: الإنجليزية لجهاز إنجليزي، والعربية لغير ذلك', () {
    expect(
      resolveAppLocale(AppLanguage.system, const Locale('en', 'US')),
      const Locale('en'),
    );
    expect(
      resolveAppLocale(AppLanguage.system, const Locale('ar', 'EG')),
      const Locale('ar'),
    );
    expect(
      resolveAppLocale(AppLanguage.system, const Locale('fr')),
      const Locale('ar'),
    );
    expect(
      resolveAppLocale(AppLanguage.ar, const Locale('en')),
      const Locale('ar'),
    );
    expect(
      resolveAppLocale(AppLanguage.en, const Locale('ar')),
      const Locale('en'),
    );
  });

  test('اللغة والمظهر يُحفظان ويُقرآن بعد إعادة التشغيل', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    addTearDown(first.dispose);
    final s = await first.read(appSettingsProvider.future);
    expect(s.language, AppLanguage.system);
    expect(s.themeMode, ThemeMode.system);
    await first.read(appSettingsProvider.notifier).setLanguage(AppLanguage.en);
    await first.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);

    final second = ProviderContainer();
    addTearDown(second.dispose);
    final restored = await second.read(appSettingsProvider.future);
    expect(restored.language, AppLanguage.en);
    expect(restored.themeMode, ThemeMode.dark);
  });

  test('قيمة محفوظة غير معروفة تعود إلى الافتراضي', () async {
    SharedPreferences.setMockInitialValues({
      AppSettingsController.languageKey: 'fr',
      AppSettingsController.themeKey: 'sepia',
    });
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = await c.read(appSettingsProvider.future);
    expect(s.language, AppLanguage.system);
    expect(s.themeMode, ThemeMode.system);
  });

  test('إعادة ضبط تأكيد العمر تحذفه', () async {
    SharedPreferences.setMockInitialValues({ageConfirmedKey: true});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(ageConfirmedProvider.future), isTrue);
    await c.read(ageConfirmedProvider.notifier).reset();
    expect(c.read(ageConfirmedProvider).value, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ageConfirmedKey), isNull);
  });
}
