import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'router.dart';

/// الهيكل للمسجّل: NavigationBar سفلي وزر الكاميرا البارز (DESIGN §2).
/// الإعدادات بلا زر الكاميرا (DESIGN §2: الـ FAB في الرئيسية والسجل).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final index = location.startsWith(Routes.history)
        ? 1
        : location.startsWith(Routes.settings)
        ? 2
        : 0;
    return Scaffold(
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: index == 2
          ? null
          : FloatingActionButton.large(
              key: const Key('fab_camera'),
              tooltip: l.openCamera,
              shape: const CircleBorder(),
              onPressed: () => context.push(Routes.capture),
              child: const Icon(Icons.photo_camera_outlined, size: 36),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            context.go(const [Routes.home, Routes.history, Routes.settings][i]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: l.navHistory,
          ),
          NavigationDestination(
            key: const Key('nav_settings'),
            icon: const Icon(Icons.settings_outlined),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}
