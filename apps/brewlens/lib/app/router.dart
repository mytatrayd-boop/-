import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/result/result_screen.dart';
import '../features/review_detail/review_detail_screen.dart';
import 'main_shell.dart';
import 'providers.dart';

abstract final class Routes {
  static const login = '/login';
  static const signup = '/signup';
  static const forgot = '/forgot';
  static const home = '/';
  static const capture = '/capture';
  static const result = '/result';
  static const history = '/history';
  static const historyFavorites = '/history?tab=favorites';
  static const paywall = '/paywall';

  static String reviewPath(String id) => '/review/$id';

  static const _public = {login, signup, forgot};

  static bool isPublic(String path) => _public.contains(path);
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// redirect حسب الجلسة: لا وصول لغير شاشات الحساب بلا جلسة (F2 معيار 6).
String? authRedirect({required bool signedIn, required String path}) {
  final public = Routes.isPublic(path);
  if (!signedIn && !public) return Routes.login;
  if (signedIn && public) return Routes.home;
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final signedIn = ValueNotifier<bool>(ref.read(sessionProvider) != null);
  ref.listen(sessionProvider, (_, next) => signedIn.value = next != null);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: signedIn,
    redirect: (context, state) =>
        authRedirect(signedIn: signedIn.value, path: state.uri.path),
    routes: [
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: Routes.forgot,
        builder: (_, state) => ForgotPasswordScreen(
          initialEmail: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (_, state, child) => MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: Routes.history,
            pageBuilder: (_, state) => NoTransitionPage(
              key: ValueKey(state.uri.toString()),
              child: HistoryScreen(
                initialTab: state.uri.queryParameters['tab'] == 'favorites' ? 1 : 0,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: Routes.capture,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const CaptureScreen(),
      ),
      GoRoute(
        path: Routes.result,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const ResultScreen(),
      ),
      GoRoute(
        path: '/review/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => ReviewDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.paywall,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => const MaterialPage(fullscreenDialog: true, child: PaywallScreen()),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    signedIn.dispose();
  });
  return router;
});
