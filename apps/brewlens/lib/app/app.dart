import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../widgets/demo_banner.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class BrewLensApp extends ConsumerWidget {
  const BrewLensApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(appConfigProvider).isDemo;
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: ref.watch(localeProvider),
      supportedLocales: supportedLocales,
      localeListResolutionCallback: (locales, _) => resolveLocale(locales),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          isDemo ? DemoBannerFrame(child: child!) : child!,
    );
  }
}
