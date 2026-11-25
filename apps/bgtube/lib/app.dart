import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'core/theme.dart';
import 'features/player/player_screen.dart';
import 'features/settings/locale_controller.dart';
import 'l10n/gen/app_localizations.dart';

class BgtubeApp extends ConsumerWidget {
  const BgtubeApp({super.key, this.locale});

  /// تجاوز صريح (للاختبارات). الأصل: اللغة المحفوظة من الإعدادات، وإلا لغة
  /// الجهاز، وإلا العربية.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      theme: buildDarkTheme(),
      themeMode: ThemeMode.dark,
      locale: locale ?? ref.watch(localeProvider),
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
