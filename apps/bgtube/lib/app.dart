import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'features/player/player_screen.dart';
import 'l10n/gen/app_localizations.dart';

class BgtubeApp extends StatelessWidget {
  const BgtubeApp({super.key, this.locale});

  /// null = لغة الجهاز (العربية افتراضياً إن لم تُدعم لغة الجهاز).
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      theme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      // العربية أولاً: أي لغة جهاز غير مدعومة تعود للعربية.
      localeResolutionCallback: (l, supported) {
        for (final s in supported) {
          if (s.languageCode == l?.languageCode) return s;
        }
        return const Locale('ar');
      },
      home: const PlayerScreen(),
    );
  }
}
