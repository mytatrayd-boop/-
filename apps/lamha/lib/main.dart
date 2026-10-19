import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'src/app/settings_screen.dart';

void main() {
  // بلا إعادة محاولة تلقائية: الخطأ يظهر للمستخدم بدل دوّامة تحميل لا تنتهي.
  runApp(ProviderScope(retry: (_, _) => null, child: const LamhaApp()));
}

/// العربية فقط في النسخة الأولى (SPEC ٨)، ومن اليمين لليسار.
class LamhaApp extends StatelessWidget {
  const LamhaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Tajawal',
        colorSchemeSeed: const Color(0xFFD6AA5C),
      ),
      home: const SettingsScreen(),
    );
  }
}
