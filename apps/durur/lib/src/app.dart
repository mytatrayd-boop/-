import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/app_localizations.dart';
import 'routing/app_router.dart';

/// جذر التطبيق: العربية فقط في النسخة الأولى، واتجاه من اليمين لليسار.
class DururApp extends StatelessWidget {
  const DururApp({super.key});

  static const Locale arabic = Locale('ar');

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: arabic,
      supportedLocales: const [arabic],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E3F)),
      ),
      routerConfig: appRouter,
    );
  }
}
