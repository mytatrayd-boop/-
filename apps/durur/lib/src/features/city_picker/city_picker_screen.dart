import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/city.dart';
import '../../domain/city_search.dart';
import '../../domain/tables.dart';
import '../../providers.dart';

/// اختيار المدينة يدوياً (SPEC الميزة 3، DESIGN 8.3): بحث بالاسم العربي،
/// شرائح تصفية بالدولة، وقائمة مجمّعة حسب الدولة بعناوين لاصقة.
class CityPickerScreen extends ConsumerStatefulWidget {
  const CityPickerScreen({super.key});

  static const searchFieldKey = Key('citySearchField');
  static Key cityTileKey(String cityId) => Key('city-$cityId');
  static Key countryChipKey(Country? country) =>
      Key('countryChip-${country?.code ?? 'all'}');

  @override
  ConsumerState<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends ConsumerState<CityPickerScreen> {
  final _search = TextEditingController();
  Country? _country;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tables = ref.watch(tablesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cityPickerTitle)),
      body: switch (tables) {
        AsyncData(:final value) => _content(context, l10n, value),
        AsyncError() => _DataLoadError(
            onRetry: () => ref.invalidate(tablesProvider),
          ),
        // البيانات محلية فالتحميل لحظي (DESIGN 8.3: لا حالة تحميل).
        _ => const SizedBox.shrink(),
      },
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n, Tables tables) {
    final results =
        searchCities(tables.cities, query: _search.text, country: _country);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
          child: TextField(
            key: CityPickerScreen.searchFieldKey,
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.citySearchHint,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        _countryChips(l10n),
        Expanded(
          child: results.isEmpty
              ? _EmptyResults(onClear: _clearSearch)
              : _cityList(context, l10n, tables, results),
        ),
      ],
    );
  }

  Widget _countryChips(AppLocalizations l10n) {
    final options = <Country?>[null, ...Country.values];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final country = options[i];
          return Center(
            child: ChoiceChip(
              key: CityPickerScreen.countryChipKey(country),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              label: Text(
                country == null
                    ? l10n.cityFilterAll
                    : l10n.countryName(country.code),
              ),
              selected: _country == country,
              onSelected: (_) => setState(() => _country = country),
            ),
          );
        },
      ),
    );
  }

  Widget _cityList(
    BuildContext context,
    AppLocalizations l10n,
    Tables tables,
    List<City> results,
  ) {
    final selectedId = ref.watch(settingsProvider.select((s) => s.cityId));
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        for (final country in Country.values)
          if (results.any((c) => c.country == country))
            SliverMainAxisGroup(
              slivers: [
                PinnedHeaderSliver(
                  child: Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.countryName(country.code),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ),
                ),
                SliverList.list(
                  children: [
                    for (final city in results)
                      if (city.country == country)
                        _CityTile(
                          city: city,
                          regionName: _regionName(tables, city),
                          selected: city.id == selectedId,
                          onTap: _saving ? null : () => _select(city, tables),
                        ),
                  ],
                ),
              ],
            ),
      ],
    );
  }

  String _regionName(Tables tables, City city) =>
      tables.region(city.regionId)?.name.ar ?? city.regionId;

  void _clearSearch() {
    _search.clear();
    setState(() {});
  }

  Future<void> _select(City city, Tables tables) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).selectCity(city.id);
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.citySaveError),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l10n.commonRetry,
            onPressed: () => _select(city, tables),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.citySelected(city.name.ar, _regionName(tables, city)),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
    await navigator.maybePop();
  }
}

class _CityTile extends StatelessWidget {
  const _CityTile({
    required this.city,
    required this.regionName,
    required this.selected,
    required this.onTap,
  });

  final City city;
  final String regionName;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // DESIGN 4: صف بسطرين 64dp على الأقل.
    return ListTile(
      key: CityPickerScreen.cityTileKey(city.id),
      minTileHeight: 64,
      minVerticalPadding: 12,
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      selected: selected,
      title: Text(city.name.ar),
      subtitle: Text(l10n.cityRegionLabel(regionName)),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        children: [
          const ExcludeSemantics(child: Icon(Icons.search_off, size: 48)),
          const SizedBox(height: 16),
          Text(
            l10n.cityEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.cityEmptyBody,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onClear, child: Text(l10n.cityEmptyClear)),
        ],
      ),
    );
  }
}

/// تعذّر قراءة البيانات المضمّنة (DESIGN 8.1، نادر جداً).
class _DataLoadError extends StatelessWidget {
  const _DataLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        children: [
          Text(
            l10n.dataLoadErrorTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(l10n.dataLoadErrorBody, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}
