import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/home_screen.dart';
import 'providers.dart';

abstract final class Routes {
  static const login = '/login';
  static const signup = '/signup';
  static const forgot = '/forgot';
  static const home = '/';

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
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    signedIn.dispose();
  });
  return router;
});
