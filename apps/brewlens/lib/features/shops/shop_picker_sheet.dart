import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/data_providers.dart';
import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models/shop.dart';
import '../../l10n/app_localizations.dart';
import '../../services/location_service.dart';

/// نتيجة ورقة اختيار المقهى: مقهى مختار، أو «بدون مقهى» (shop = null).
class ShopPick {
  const ShopPick(this.shop);

  final Shop? shop;
}

/// ورقة اختيار المقهى (F6 حسب D14، DESIGN §3.6). null = إغلاق بلا تغيير.
Future<ShopPick?> showShopPicker(BuildContext context, {Shop? current}) =>
    showModalBottomSheet<ShopPick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ShopPickerSheet(current: current),
      ),
    );

enum _LocationState { idle, locating, saved, failed }

class ShopPickerSheet extends ConsumerStatefulWidget {
  const ShopPickerSheet({super.key, this.current});

  final Shop? current;

  @override
  ConsumerState<ShopPickerSheet> createState() => _ShopPickerSheetState();
}

class _ShopPickerSheetState extends ConsumerState<ShopPickerSheet> {
  late final _name = TextEditingController(text: widget.current?.name ?? '');
  Shop? _selected;
  GeoPoint? _point;
  var _location = _LocationState.idle;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
    _name.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final selected = _selected;
    if (selected != null && normalizeShopName(selected.name) != normalizeShopName(_name.text)) {
      _selected = null;
    }
    setState(() {});
  }

  void _choose(Shop shop) {
    _name.value = TextEditingValue(
      text: shop.name,
      selection: TextSelection.collapsed(offset: shop.name.length),
    );
    setState(() => _selected = shop);
  }

  Future<void> _locate() async {
    setState(() => _location = _LocationState.locating);
    try {
      final point = await ref.read(locationServiceProvider).currentPosition();
      if (!mounted) return;
      setState(() {
        _point = point;
        _location = _LocationState.saved;
      });
    } on LocationUnavailable {
      if (mounted) setState(() => _location = _LocationState.failed);
    }
  }

  Future<void> _done() async {
    final l = AppLocalizations.of(context);
    final selected = _selected;
    // مقهى سابق بلا موقع جديد: يُربط مباشرة دون إنشاء سجل جديد.
    if (selected != null && _point == null) {
      Navigator.of(context).pop(ShopPick(selected));
      return;
    }
    setState(() => _saving = true);
    try {
      final shop = await ref.read(shopsRepositoryProvider).create(
            name: _name.text,
            latitude: _point?.latitude,
            longitude: _point?.longitude,
          );
      ref.invalidate(shopsProvider);
      ref.invalidate(favoritesProvider);
      if (mounted) Navigator.of(context).pop(ShopPick(shop));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shops = ref.watch(shopsProvider).value ?? const <Shop>[];
    final suggestions = suggestShops(shops, _name.text);
    final nameEmpty = _name.text.trim().isEmpty;
    final selectedHasLocation = _selected?.hasLocation ?? false;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('shop_name'),
            controller: _name,
            autofocus: true,
            maxLength: Shop.maxName,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l.shopNameLabel, counterText: ''),
          ),
          const SizedBox(height: 12),
          if (suggestions.isNotEmpty)
            Text(l.previousShops, style: text.titleMedium),
          Expanded(
            child: ListView(
              children: [
                for (final shop in suggestions)
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(Icons.storefront_outlined, color: scheme.onSurfaceVariant),
                    title: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: _selected?.id == shop.id,
                    trailing: shop.hasLocation
                        ? Icon(Icons.place, color: scheme.primary, semanticLabel: l.hasSavedLocation)
                        : null,
                    onTap: () => _choose(shop),
                  ),
              ],
            ),
          ),
          if (selectedHasLocation && _point == null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.place, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(l.usingSavedLocation)),
              ]),
            ),
          ..._locationSection(l, scheme),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('shop_done'),
            onPressed: nameEmpty || _saving || _location == _LocationState.locating ? null : _done,
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.done),
          ),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(const ShopPick(null)),
            child: Text(l.noShop),
          ),
        ],
      ),
    );
  }

  List<Widget> _locationSection(AppLocalizations l, ColorScheme scheme) {
    switch (_location) {
      case _LocationState.locating:
        return [
          Row(children: [
            const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Expanded(child: Text(l.locating)),
          ]),
        ];
      case _LocationState.saved:
        return [
          Row(children: [
            Icon(Icons.check_circle, color: successColor(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(l.locationSaved, style: TextStyle(color: successColor(context))),
            ),
            TextButton(
              onPressed: () => setState(() {
                _point = null;
                _location = _LocationState.idle;
              }),
              child: Text(l.remove),
            ),
          ]),
        ];
      case _LocationState.failed:
        return [
          Text(l.locationFailed, style: TextStyle(color: scheme.error)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => ref.read(locationServiceProvider).openSettings(),
              child: Text(l.enableLocation),
            ),
          ),
          _saveLocationButton(l),
        ];
      case _LocationState.idle:
        return [_saveLocationButton(l)];
    }
  }

  Widget _saveLocationButton(AppLocalizations l) => OutlinedButton.icon(
        key: const Key('save_location'),
        onPressed: _locate,
        icon: const Icon(Icons.my_location),
        label: Text(l.saveMyLocation, textAlign: TextAlign.center),
      );
}
