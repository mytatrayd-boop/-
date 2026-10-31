import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../app/widgets/placeholder_body.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: const PlaceholderBody(icon: Icons.settings_outlined),
    );
  }
}
