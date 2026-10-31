import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/gen/app_localizations.dart';

/// الهيكل ذو شريط التنقل السفلي: فحص، السجل، المفضلة، الإعدادات.
/// ترتيب التبويبات يتبع اتجاه الواجهة (يبدأ من اليمين في العربية).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.center_focus_strong_outlined),
            selectedIcon: const Icon(Icons.center_focus_strong),
            label: l10n.tabScan,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: l10n.tabHistory,
          ),
          NavigationDestination(
            icon: const Icon(Icons.star_border),
            selectedIcon: const Icon(Icons.star),
            label: l10n.tabFavorites,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
