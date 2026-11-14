import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/locale/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class RihlaApp extends ConsumerWidget {
  const RihlaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // العربية أولاً: إن لم تُدعم لغة النظام تُستخدم العربية.
      localeResolutionCallback: (l, supported) {
        for (final s in supported) {
          if (s.languageCode == l?.languageCode) return s;
        }
        return supported.first;
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
