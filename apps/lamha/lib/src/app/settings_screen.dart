import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/prayer.dart';
import '../engine/settings.dart';
import '../engine/widget_theme.dart';
import 'places.dart';
import 'providers.dart';
import 'qibla_screen.dart';
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.loadError,
                    textAlign: TextAlign.right, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                // تفاصيل الخطأ ليرسلها المالك عند التجربة.
                SelectableText('$e',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
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
              systemColors: state.systemColors,
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
        Text(l.themeLabel, style: textTheme.titleMedium),
        const SizedBox(height: 8),
        _ThemePicker(
          selected: s.theme,
          system: state.systemColors,
          onPick: c.setTheme,
        ),
        const SizedBox(height: 12),
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
                // مكان من البحث أو الموقع ليس في القائمة: يظهر اسمه تلميحاً.
                value: state.cities.any((city) => city.id == s.cityId)
                    ? s.cityId
                    : null,
                hint: Text(s.cityName),
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
                final r = await c.useMyLocation(nearLabel: l.nearCity);
                switch (r) {
                  case LocationResult.named:
                    break;
                  case LocationResult.nearest:
                    toast(l.locationNearest);
                  case LocationResult.denied:
                    toast(l.locationDenied);
                  case LocationResult.failed:
                    toast(l.locationFailed);
                }
              },
            ),
          ],
        ),
        const _PlaceSearch(),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('qibla-button'),
          icon: const Icon(Icons.explore),
          label: Text(l.qiblaTitle),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            settings: const RouteSettings(name: QiblaScreen.routeName),
            builder: (_) => const QiblaScreen(),
          )),
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
        // شاشة القفل في أندرويد: إشعار ثابت اختياري (آيفون في ميزة لاحقة).
        if (defaultTargetPlatform == TargetPlatform.android) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('lock-notification'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.lockNotificationLabel),
            subtitle: Text(l.lockNotificationHint),
            value: s.lockNotification,
            onChanged: (v) async {
              if (v && !await _explainPermission(context, l)) return;
              if (!await c.setLockNotification(v)) toast(l.notificationDenied);
            },
          ),
        ],
        const SizedBox(height: 16),
        Text(l.dataLicense, style: textTheme.bodySmall),
      ],
    );
  }
}

/// رسالة تشرح سبب إذن الإشعارات قبل طلبه؛ تعيد true عند «متابعة».
Future<bool> _explainPermission(BuildContext context, AppLocalizations l) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.notificationPermissionTitle),
        content: Text(l.notificationPermissionBody),
        actions: [
          TextButton(
            key: const Key('permission-cancel'),
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l.cancelAction),
          ),
          FilledButton(
            key: const Key('permission-continue'),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.continueAction),
          ),
        ],
      ),
    ) ??
    false;

/// أزرار دائرية ملونة لسمات الودجت.
class _ThemePicker extends StatelessWidget {
  const _ThemePicker(
      {required this.selected, required this.system, required this.onPick});

  final WidgetTheme selected;
  final SystemColors? system;
  final ValueChanged<WidgetTheme> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final t in WidgetTheme.values)
          Tooltip(
            message: l.themeName(t.name),
            child: Semantics(
              button: true,
              selected: t == selected,
              label: l.themeName(t.name),
              child: InkResponse(
                key: Key('theme-${t.name}'),
                onTap: () => onPick(t),
                radius: 22,
                child: _swatch(t),
              ),
            ),
          ),
      ],
    );
  }

  Widget _swatch(WidgetTheme t) {
    final c = themeColors(t, system);
    final on = t == selected;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // ألوان النظام: نصفان (التمييز والخلفية) ليظهر أنها من الجهاز.
        gradient: t == WidgetTheme.system
            ? SweepGradient(colors: [
                Color(c.accent),
                Color(c.accent),
                Color(c.background),
                Color(c.background),
              ], stops: const [0, 0.5, 0.5, 1])
            : null,
        color: t == WidgetTheme.system ? null : Color(c.accent),
        border: Border.all(
            color: on ? Colors.white : Colors.white24, width: on ? 3 : 1),
      ),
      child: on
          ? const Icon(Icons.check, size: 18, color: Colors.black87)
          : null,
    );
  }
}

/// البحث عن مدينة أو محافظة (geocoding)، والنتائج للاختيار.
class _PlaceSearch extends ConsumerStatefulWidget {
  const _PlaceSearch();

  @override
  ConsumerState<_PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends ConsumerState<_PlaceSearch> {
  final _text = TextEditingController();
  var _busy = false;
  String? _message;
  var _results = const <Place>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _search(AppLocalizations l) async {
    final q = _text.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
      _results = const [];
    });
    try {
      final r =
          await ref.read(settingsControllerProvider.notifier).searchPlaces(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _message = r.isEmpty ? l.searchNoResults : null;
      });
    } catch (e) {
      debugPrint('search: $e');
      if (mounted) setState(() => _message = l.searchFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('city-search'),
          controller: _text,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(l),
          decoration: InputDecoration(
            hintText: l.searchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    key: const Key('city-search-button'),
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _search(l),
                  ),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_message!, key: const Key('city-search-message')),
          ),
        for (final (i, p) in _results.indexed)
          ListTile(
            key: Key('place-$i'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(p.name),
            onTap: () async {
              setState(() => _results = const []);
              _text.clear();
              await ref.read(settingsControllerProvider.notifier).setPlace(p);
            },
          ),
      ],
    );
  }
}
