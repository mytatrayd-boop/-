import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';

/// الهيكل للمسجّل: NavigationBar سفلي وزر الكاميرا البارز (DESIGN §2).
/// وجهة الإعدادات تُضاف في الدفعة ج.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final index = location.startsWith(Routes.history) ? 1 : 0;
    return Scaffold(
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        key: const Key('fab_camera'),
        tooltip: l.openCamera,
        shape: const CircleBorder(),
        onPressed: () => context.push(Routes.capture),
        child: const Icon(Icons.photo_camera_outlined, size: 36),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(i == 0 ? Routes.home : Routes.history),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), label: l.navHome),
          NavigationDestination(icon: const Icon(Icons.history), label: l.navHistory),
        ],
      ),
    );
  }
}
