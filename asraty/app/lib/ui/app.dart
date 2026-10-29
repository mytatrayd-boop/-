import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backend/backend.dart';
import '../backend/reminders.dart';
import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'admin.dart';
import 'common.dart';
import 'member.dart';
import 'onboarding.dart';
import 'paywall.dart';
import 'prizes.dart';
import 'providers.dart';
import 'report_page.dart';
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
        if (s.signedIn) return build(Ctx(s));
        // Session ended while on an inner page (sign-out, deletion, removed by an admin):
        // show the sign-in screen right away and move back to the root route.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) GoRouter.of(context).go('/');
        });
        return const _Home();
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
      GoRoute(path: '/report', builder: (context, state) => Shell(child: signedIn(ReportRoute.new))),
      GoRoute(path: '/prizes', builder: (context, state) => Shell(child: signedIn(PrizesPage.new))),
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
    ref.watch(accessProvider);
    if (!s.signedIn) return const Onboarding();
    // iPhone builds with the subscription gate: a code or a subscription is needed (never in the demo).
    if (!ref.read(backendProvider).isDemo && !ref.read(accessProvider.notifier).allowed) return const PaywallPage();
    final c = Ctx(s);
    return c.me.role == Role.member ? MemberHome(c) : AdminHome(c);
  }
}

class AsratyApp extends ConsumerWidget {
  const AsratyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phone reminders follow the family's prayer settings and prizes.
    ref.listen(appStateProvider, (_, next) {
      final st = next.value;
      Reminders.sync(st?.signedIn == true ? st!.data : null, st?.signedIn == true ? st!.me : null);
    });
    // While the app is open, a prize's reminder or hand-over time asks the server
    // to act right away (it also does so on any other request).
    ref.listen(clockProvider, (prev, next) {
      final a = prev?.value, b = next.value;
      final d = ref.read(appStateProvider).value?.data;
      if (a == null || b == null || d == null) return;
      bool crossed(DateTime t) => t.isAfter(a) && !t.isAfter(b);
      if (d.prizes.any((p) => !p.awarded && (crossed(p.awardAt) || crossed(p.awardAt.subtract(const Duration(hours: 1)))))) {
        ref.read(backendProvider).tick().ignore();
      }
    });
    return _app(ref);
  }

  Widget _app(WidgetRef ref) => MaterialApp.router(
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
