import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'routing/app_router.dart';

/// جذر التطبيق: العربية فقط في النسخة الأولى، واتجاه من اليمين لليسار.
class DururApp extends StatefulWidget {
  const DururApp({super.key});

  static const Locale arabic = Locale('ar');

  @override
  State<DururApp> createState() => _DururAppState();
}

class _DururAppState extends State<DururApp> {
  // موجّه لكل نسخة من التطبيق (لا حالة مشتركة بين الاختبارات).
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: DururApp.arabic,
      supportedLocales: const [DururApp.arabic],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E3F)),
      ),
      routerConfig: _router,
    );
  }
}
