import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../engine/widget_layout.dart';
import 'providers.dart';
import 'widget_preview.dart';

/// شاشة «تخصيص الودجت» (الميزة ٥): معاينة حية بالحجم الحقيقي، وتحتها بطاقات المربعات قابلة
/// للسحب لإعادة الترتيب، ولكل مربع: الإظهار والعرض وحجم الخط واللونان. الضغط على مربع في
/// المعاينة يفتح إعداداته.
class CustomizeScreen extends ConsumerWidget {
  const CustomizeScreen({super.key});

  static const routeName = '/customize';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(settingsControllerProvider).value;
    final c = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.customizeTitle),
        actions: [
          TextButton.icon(
            key: const Key('reset-layout'),
            icon: const Icon(Icons.restart_alt),
            label: Text(l.resetLayout),
            onPressed: state == null ? null : c.resetLayout,
          ),
        ],
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : _Body(state: state),
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
    final layout = state.settings.layout;
    final placed = placedElements([
      for (final t in layout)
        if (t.visible) (id: t.id.name, span: t.span),
    ]);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: SizedBox(
            height: previewWidgetSize.height + 32,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                // بالحجم الحقيقي (٣٣٨×٣٥٤ وحولها خلفية ١٦)، ويصغر فقط إن ضاقت الشاشة.
                width: previewWidgetSize.width + 32,
                height: previewWidgetSize.height + 32,
                child: RepaintBoundary(
                  key: const Key('customize-preview'),
                  child: WidgetPreview(
                    schedule: state.schedule,
                    now: ref.read(clockProvider)(),
                    backgroundPath: state.backgroundPath,
                    systemColors: state.systemColors,
                    onTileTap: (e) => _openSheet(context, e),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            l.tileHint,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            key: const Key('tile-list'),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: layout.length,
            onReorderItem: c.moveTile,
            itemBuilder: (context, i) {
              final t = layout[i];
              return Card(
                key: ValueKey('card-${t.id.name}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        tile: t,
                        prefix: '',
                        handle: ReorderableDragStartListener(
                          key: Key('drag-${t.id.name}'),
                          index: i,
                          child: Tooltip(
                            message: l.dragHandle,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ),
                      ),
                      if (t.visible && !placed.contains(t.id.name))
                        Text(
                          l.tileOverflow,
                          key: Key('overflow-${t.id.name}'),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      TileSettings(tile: t, prefix: ''),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// إعدادات مربع من المعاينة، تتحدث مع كل تغيير.
  void _openSheet(BuildContext context, WidgetElement id) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(settingsControllerProvider).value;
          if (s == null) return const SizedBox.shrink();
          final t = s.settings.layout.firstWhere((t) => t.id == id);
          return SingleChildScrollView(
            key: const Key('tile-sheet'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(tile: t, prefix: 'sheet-'),
                TileSettings(tile: t, prefix: 'sheet-'),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// اسم المربع ومفتاح إظهاره.
class _Header extends ConsumerWidget {
  const _Header({required this.tile, required this.prefix, this.handle});

  final TileLayout tile;
  final String prefix;
  final Widget? handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        ?handle,
        Expanded(
          child: Text(
            l.elementName(tile.id.name),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(l.tileVisible),
        Switch(
          key: Key('${prefix}visible-${tile.id.name}'),
          value: tile.visible,
          onChanged: (v) => ref
              .read(settingsControllerProvider.notifier)
              .setVisible(tile.id, v),
        ),
      ],
    );
  }
}

/// العرض وحجم الخط واللونان لمربع واحد (في البطاقة وفي نافذة المعاينة).
class TileSettings extends ConsumerWidget {
  const TileSettings({super.key, required this.tile, required this.prefix});

  final TileLayout tile;

  /// بادئة المفاتيح ('' للبطاقة، 'sheet-' للنافذة).
  final String prefix;

  static const spanNames = {1: 'small', 2: 'medium', 3: 'wide'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsControllerProvider.notifier);
    final id = tile.id;
    final label = Theme.of(context).textTheme.labelLarge;
    Widget title(String s) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(s, textAlign: TextAlign.right, style: label),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title(l.tileSpanLabel),
        SegmentedButton<int>(
          key: Key('${prefix}span-${id.name}'),
          showSelectedIcon: false,
          segments: [
            for (final e in spanNames.entries)
              ButtonSegment(
                value: e.key,
                label: Text(
                  l.tileSpanName(e.value),
                  key: Key('${prefix}span-${id.name}-${e.key}'),
                ),
              ),
          ],
          selected: {tile.span},
          onSelectionChanged: (v) =>
              c.updateTile(id, (t) => t.copyWith(span: v.first)),
        ),
        title(l.tileFontLabel),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final f in FontScale.values)
              ChoiceChip(
                key: Key('${prefix}tilefont-${id.name}-${f.name}'),
                label: Text(l.fontScaleName(f.name)),
                selected: tile.fontScale == f,
                onSelected: (_) =>
                    c.updateTile(id, (t) => t.copyWith(fontScale: f)),
              ),
          ],
        ),
        title(l.primaryColorLabel),
        _ColorRow(
          keyPrefix: '${prefix}primary-${id.name}',
          selected: tile.primaryColor,
          onPick: (color) =>
              c.updateTile(id, (t) => t.copyWith(primaryColor: () => color)),
        ),
        title(l.secondaryColorLabel),
        _ColorRow(
          keyPrefix: '${prefix}secondary-${id.name}',
          selected: tile.secondaryColor,
          onPick: (color) =>
              c.updateTile(id, (t) => t.copyWith(secondaryColor: () => color)),
        ),
      ],
    );
  }
}

/// دوائر اللوحة الثابتة، وأولها «تلقائي» (حسب السمة).
class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.keyPrefix,
    required this.selected,
    required this.onPick,
  });

  final String keyPrefix;
  final TileColor? selected;
  final ValueChanged<TileColor?> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final color in <TileColor?>[null, ...TileColor.values])
          Tooltip(
            message: l.tileColorName(color?.name ?? 'auto'),
            child: Semantics(
              button: true,
              selected: color == selected,
              label: l.tileColorName(color?.name ?? 'auto'),
              child: InkResponse(
                key: Key('$keyPrefix-${color?.name ?? 'auto'}'),
                radius: 20,
                onTap: () => onPick(color),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color == null
                        ? Colors.transparent
                        : Color(color.argb),
                    border: Border.all(
                      color: color == selected ? Colors.white : Colors.white24,
                      width: color == selected ? 3 : 1,
                    ),
                  ),
                  child: color == null
                      ? const Icon(Icons.auto_awesome, size: 16)
                      : color == selected
                      ? const Icon(Icons.check, size: 16, color: Colors.black87)
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
