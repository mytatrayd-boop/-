import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/prayer.dart';
import '../engine/settings.dart';
import 'providers.dart';
import 'widget_preview.dart';

/// شاشة الإعدادات الوحيدة (SPEC ٧، DESIGN «تطبيق الإعدادات»).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.loadError, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                // تفاصيل الخطأ ليرسلها المالك عند التجربة.
                SelectableText('$e',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('retry-button'),
                  onPressed: () => ref.invalidate(settingsControllerProvider),
                  child: Text(l.retry),
                ),
              ],
            ),
          ),
        ),
        data: (s) => _Body(state: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsControllerProvider.notifier);
    final s = state.settings;
    void toast(String m) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AspectRatio(
          aspectRatio: (previewWidgetSize.width + 32) /
              (previewWidgetSize.height + 32),
          child: RepaintBoundary(
            key: const Key('preview'),
            child: WidgetPreview(
              schedule: state.schedule,
              now: ref.read(clockProvider)(),
              backgroundPath: state.backgroundPath,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(l.opacityLabel, style: textTheme.titleMedium),
            const Spacer(),
            // الشريط يعرض الشفافية: ١٠٠٪ = خلفية شفافة تماماً (opacity = 0).
            Text(l.percent(arabicDigits(100 - s.opacity))),
          ],
        ),
        Slider(
          key: const Key('opacity-slider'),
          value: (100 - s.opacity).toDouble(),
          max: 100,
          divisions: 100,
          onChanged: (v) => c.setOpacity(100 - v.round(), commit: false),
          onChangeEnd: (v) => c.setOpacity(100 - v.round()),
        ),
        if (defaultTargetPlatform == TargetPlatform.iOS)
          OutlinedButton.icon(
            key: const Key('background-button'),
            icon: const Icon(Icons.wallpaper),
            label: Text(l.backgroundButton),
            onPressed: () async {
              try {
                if (await c.pickBackground()) toast(l.backgroundSaved);
              } catch (_) {
                // حاوية App Group غير متاحة، أو القناة غير مسجلة، أو رُفض إذن الصور.
                toast(l.backgroundError);
              }
            },
          ),
        const SizedBox(height: 16),
        Text(l.cityLabel, style: textTheme.titleMedium),
        Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                key: const Key('city-dropdown'),
                isExpanded: true,
                value: s.cityId,
                items: [
                  for (final city in state.cities)
                    DropdownMenuItem(value: city.id, child: Text(city.name)),
                ],
                onChanged: (id) => c.setCity(
                    state.cities.firstWhere((city) => city.id == id)),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              key: const Key('my-location'),
              icon: const Icon(Icons.my_location),
              label: Text(l.myLocation),
              onPressed: () async {
                final r = await c.useMyLocation();
                if (r == LocationResult.unavailable) toast(l.locationDenied);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.prayerMethodLabel, style: textTheme.titleMedium),
        DropdownButton<String>(
          key: const Key('method-dropdown'),
          isExpanded: true,
          value: s.prayerMethod,
          items: [
            for (final id in prayerMethods.keys)
              DropdownMenuItem(value: id, child: Text(l.prayerMethodName(id))),
          ],
          onChanged: (id) => c.setPrayerMethod(id!),
        ),
        const SizedBox(height: 16),
        Text(l.visibleSection, style: textTheme.titleMedium),
        for (final e in WidgetElement.values) ...[
          SwitchListTile(
            key: Key('switch-${e.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.elementName(e.name)),
            value: s.visible.contains(e),
            onChanged: (v) => c.setVisible(e, v),
          ),
          if (e == WidgetElement.deposit)
            for (final r in state.data.deposits.rules)
              SwitchListTile(
                key: Key('deposit-${r.id}'),
                contentPadding: const EdgeInsetsDirectional.only(start: 24),
                dense: true,
                title: Text(r.name),
                value: s.deposits.contains(r.id),
                onChanged: (v) async {
                  if (!await c.setDeposit(r.id, v)) {
                    toast(l.lastDepositMessage);
                  }
                },
              ),
        ],
        const SizedBox(height: 16),
        Text(l.dataLicense, style: textTheme.bodySmall),
      ],
    );
  }
}
