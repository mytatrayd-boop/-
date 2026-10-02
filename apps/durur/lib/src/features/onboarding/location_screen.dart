import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/city.dart';
import '../../location/city_locator.dart';
import '../../providers.dart';
import '../../routing/app_router.dart';
import '../city_picker/city_picker_screen.dart';
import 'onboarding_layout.dart';

/// شرح الموقع ← إذن النظام ← نتيجة (DESIGN 8.2 ب وج، SPEC الميزة 4).
class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  static const allowKey = Key('locationAllow');
  static const manualKey = Key('locationManual');
  static const manualWhileLoadingKey = Key('locationManualWhileLoading');
  static const continueKey = Key('locationContinue');
  static const notMyCityKey = Key('locationNotMyCity');
  static const foundCardKey = Key('locationFoundCard');

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _locating = false;
  City? _found;

  /// يزيد مع كل محاولة أو خروج يدوي؛ نتيجة محاولة قديمة تُتجاهل ولا تُحفظ.
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final found = _found;
    return OnboardingLayout(
      icon: Icons.place_outlined,
      title: l10n.onboardingLocationTitle,
      body: l10n.onboardingLocationBody,
      extra: _locating
          ? _Loading(text: l10n.onboardingLocationLoading)
          : found == null
          ? null
          : _FoundCard(city: found, regionName: _regionName(found)),
      actions: _locating
          ? [
              TextButton(
                key: LocationScreen.manualWhileLoadingKey,
                style: OnboardingLayout.buttonStyle,
                onPressed: _manual,
                child: Text(l10n.onboardingLocationManualShort),
              ),
            ]
          : found != null
          ? [
              FilledButton(
                key: LocationScreen.continueKey,
                style: OnboardingLayout.buttonStyle,
                onPressed: () => context.go(AppRoutes.home),
                child: Text(l10n.commonContinue),
              ),
              TextButton(
                key: LocationScreen.notMyCityKey,
                style: OnboardingLayout.buttonStyle,
                onPressed: () => context.go(AppRoutes.onboardingCity),
                child: Text(l10n.onboardingLocationNotMyCity),
              ),
            ]
          : [
              FilledButton(
                key: LocationScreen.allowKey,
                style: OnboardingLayout.buttonStyle,
                onPressed: _locate,
                child: Text(l10n.onboardingLocationAllow),
              ),
              OutlinedButton(
                key: LocationScreen.manualKey,
                style: OnboardingLayout.buttonStyle,
                onPressed: _manual,
                child: Text(l10n.onboardingLocationManual),
              ),
            ],
    );
  }

  String _regionName(City city) =>
      ref.read(tablesProvider).value?.region(city.regionId)?.name.ar ??
      city.regionId;

  void _manual() {
    _attempt++;
    context.go(AppRoutes.onboardingCity);
  }

  Future<void> _locate() async {
    final attempt = ++_attempt;
    setState(() => _locating = true);
    final LocateResult result;
    try {
      final tables = await ref.read(tablesProvider.future);
      result = await ref.read(cityLocatorProvider).locate(tables.cities);
    } on Object {
      // تعذّر قراءة البيانات المضمّنة: القائمة تعرض الخطأ وزر إعادة المحاولة.
      if (mounted && attempt == _attempt) context.go(AppRoutes.onboardingCity);
      return;
    }
    if (!mounted || attempt != _attempt) return;

    final CityPickerNotice notice;
    switch (result) {
      case LocateFound(:final city):
        await _save(city, attempt);
        return;
      case LocateDenied():
        notice = CityPickerNotice.denied;
      case LocateUnavailable():
        notice = CityPickerNotice.unavailable;
      case LocateTimeout():
        notice = CityPickerNotice.timeout;
      case LocateOutOfRange():
        notice = CityPickerNotice.outOfRange;
    }
    if (!mounted) return;
    context.go(AppRoutes.onboardingCityWith(notice));
  }

  Future<void> _save(City city, int attempt) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(settingsProvider.notifier).selectCity(city.id);
    } on Exception {
      if (!mounted || attempt != _attempt) return;
      setState(() => _locating = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.citySaveError),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _locating = false;
      _found = city;
    });
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FoundCard extends StatelessWidget {
  const _FoundCard({required this.city, required this.regionName});

  final City city;
  final String regionName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: LocationScreen.foundCardKey,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.onboardingLocationFound(city.name.ar),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(l10n.onboardingLocationRegion(regionName)),
            ],
          ),
        ),
      ),
    );
  }
}
