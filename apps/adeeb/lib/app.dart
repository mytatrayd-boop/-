import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'audio/mini_player.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';
import 'library/library_providers.dart';
import 'router.dart';

class AdeebApp extends ConsumerStatefulWidget {
  const AdeebApp({super.key});

  @override
  ConsumerState<AdeebApp> createState() => _AdeebAppState();
}

class _AdeebAppState extends ConsumerState<AdeebApp> {
  final _navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  late final GoRouter _router = createRouter(navigatorKey: _navigatorKey);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: _router,
      // المشغّل المصغّر أسفل كل الشاشات ما دامت هناك جلسة استماع.
      builder: (context, child) => ListeningHost(
        navigatorKey: _navigatorKey,
        router: _router,
        child: child ?? const SizedBox.shrink(),
      ),
      locale: ref.watch(appLocaleProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      debugShowCheckedModeBanner: false,
    );
  }
}
