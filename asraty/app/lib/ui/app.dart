import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backend/backend.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'admin.dart';
import 'common.dart';
import 'member.dart';
import 'onboarding.dart';
import 'providers.dart';
import 'settings.dart';
import 'shell.dart';
import 'theme.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(appStateProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  AppState st() => ref.read(appStateProvider).value ?? const AppState();

  Widget signedIn(Widget Function(Ctx c) build) => Consumer(builder: (context, ref, _) {
        final s = ref.watch(appStateProvider).value ?? const AppState();
        return s.signedIn ? build(Ctx(s)) : const SizedBox();
      });

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final s = st();
      if (state.matchedLocation == '/') return null;
      if (!s.signedIn) return '/';
      if (state.matchedLocation.startsWith('/admin') && s.me!.role == Role.member) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Shell(child: _Home())),
      GoRoute(
        path: '/admin/:page',
        builder: (context, state) => Shell(child: signedIn((c) => AdminPage(state.pathParameters['page']!, c))),
      ),
      GoRoute(path: '/settings', builder: (context, state) => Shell(child: signedIn(SettingsPage.new))),
    ],
  );
});

class _Home extends ConsumerWidget {
  const _Home();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appStateProvider).value ?? const AppState();
    if (s.session != null && !s.signedIn) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [const CircularProgressIndicator(), const SizedBox(height: 12), Muted(context.t.loading)]),
      );
    }
    if (!s.signedIn) return const Onboarding();
    final c = Ctx(s);
    return c.me.role == Role.member ? MemberHome(c) : AdminHome(c);
  }
}

class AsratyApp extends ConsumerWidget {
  const AsratyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        onGenerateTitle: (c) => L10n.of(c).appName,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ref.watch(themeModeProvider),
        routerConfig: ref.watch(_routerProvider),
        // Cap very large system font sizes (common on Honor/Huawei) so rows keep room for their text.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
          ),
          child: Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      );
}
