import 'package:go_router/go_router.dart';

import '../features/home/home_screen.dart';

/// المسارات. مسار صفحة العنصر (/item/:id) يُضاف في الميزة 7،
/// ويُستخدم أيضاً كحمولة (payload) للتنبيهات.
final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
  ],
);
