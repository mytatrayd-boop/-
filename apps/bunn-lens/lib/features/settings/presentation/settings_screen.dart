import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/widgets/placeholder_body.dart';
import '../../../l10n/gen/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(l10n.cafesTitle),
            subtitle: Text(l10n.settingsCafesSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.cafes),
          ),
          const Expanded(child: PlaceholderBody(icon: Icons.settings_outlined)),
        ],
      ),
    );
  }
}
