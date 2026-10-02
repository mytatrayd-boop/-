import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../location/city_locator.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';

/// الإعدادات (DESIGN 8.7). الآن قسم «المنطقة»: صف المدينة (SPEC الميزة 3،
/// بند 5) وصف «تحديد موقعي مرة أخرى» (الميزة 4، بند 6)، وقسم «البيانات
/// والمساعدة» فيه صف «المصادر» (الميزة 7، D27)؛ بقية الأقسام تُضاف مع ميزاتها.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const cityRowKey = Key('settingsCityRow');
  static const relocateRowKey = Key('settingsRelocateRow');
  static const sourcesRowKey = Key('settingsSourcesRow');

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
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
            key: SettingsScreen.cityRowKey,
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
          ListTile(
            key: SettingsScreen.relocateRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.my_location),
            title: Text(l10n.settingsRelocate),
            subtitle: _locating
                ? Semantics(
                    liveRegion: true,
                    child: Text(l10n.onboardingLocationLoading),
                  )
                : null,
            trailing: _locating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _locating ? null : _relocate,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 8),
            child: Semantics(
              header: true,
              child: Text(
                l10n.settingsSectionHelp,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          ListTile(
            key: SettingsScreen.sourcesRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.settingsSources),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.sources),
          ),
        ],
      ),
    );
  }

  /// قراءة واحدة ثم أقرب مدينة (DESIGN 8.7).
  Future<void> _relocate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final previousId = ref.read(settingsProvider).cityId;
    setState(() => _locating = true);

    String message;
    var offerPicker = false;
    try {
      final tables = await ref.read(tablesProvider.future);
      final result = await ref.read(cityLocatorProvider).locate(tables.cities);
      switch (result) {
        case LocateFound(:final city):
          await ref.read(settingsProvider.notifier).selectCity(city.id);
          message = city.id == previousId
              ? l10n.locationUnchanged(city.name.ar)
              : l10n.locationUpdated(
                  city.name.ar,
                  tables.region(city.regionId)?.name.ar ?? city.regionId,
                );
        case LocateOutOfRange():
          message = l10n.locationOutOfRange;
          offerPicker = true;
        case LocateDenied() || LocateUnavailable() || LocateTimeout():
          message = l10n.locationFailedSettings;
          offerPicker = true;
      }
    } on Exception {
      // فشل حفظ المدينة أو قراءة البيانات.
      message = l10n.citySaveError;
    }

    if (!mounted) return;
    setState(() => _locating = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: offerPicker
            ? SnackBarAction(
                label: l10n.locationChooseCity,
                onPressed: () => context.push(AppRoutes.city),
              )
            : null,
      ),
    );
  }
}
