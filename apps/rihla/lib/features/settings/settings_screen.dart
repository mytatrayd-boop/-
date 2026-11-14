import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';

/// شاشة فارغة (F1). المحتوى في F11.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(16),
            child: Text(l.settingsEmpty, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
