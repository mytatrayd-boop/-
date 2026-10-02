import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';

/// الإعدادات (DESIGN 8.7). الآن قسم «المنطقة» بصف المدينة فقط (SPEC الميزة 3،
/// بند 5)؛ بقية الأقسام تُضاف مع ميزاتها.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const cityRowKey = Key('settingsCityRow');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final city = ref.watch(currentCityProvider);
    final region = ref.watch(currentRegionProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                l10n.settingsSectionRegion,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          ListTile(
            key: cityRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.place_outlined),
            title: Text(l10n.settingsCity),
            subtitle: Text(
              city == null || region == null
                  ? l10n.cityPickerTitle
                  : l10n.settingsCityValue(city.name.ar, region.name.ar),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.city),
          ),
        ],
      ),
    );
  }
}
