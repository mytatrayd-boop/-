import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/widgets/placeholder_body.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../share/presentation/user_name_dialog.dart';
import '../../share/user_name.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userNameProvider).value ?? '';
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.draw_outlined),
            title: Text(l10n.settingsUserNameTitle),
            subtitle: Text(name.isEmpty ? l10n.settingsUserNameEmpty : name),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final entered = await showUserNameDialog(context,
                  title: l10n.settingsUserNameTitle, initial: name);
              if (entered != null) await ref.read(userNameProvider.notifier).setName(entered);
            },
          ),
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
