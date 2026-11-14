import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../l10n/app_localizations.dart';

/// شاشة فارغة (F1). المحتوى الحقيقي في F5.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeTitle),
        actions: [
          IconButton(
            tooltip: l.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(16),
            child: Text(l.homeEmpty, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
