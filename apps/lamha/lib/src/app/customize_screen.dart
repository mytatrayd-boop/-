import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/widget_layout.dart';
import 'providers.dart';
import 'widget_preview.dart';

/// شاشة «تخصيص الودجت» (الميزة ٥ب): من الأعلى المعاينة (حتى ٤٥٪ من الارتفاع)، ثم إعدادات المربع
/// المختار، ثم شريط عرضي بعناصر الودجت بترتيبها: الضغط يختار، والضغط المطوّل ثم السحب يعيد الترتيب.
class CustomizeScreen extends ConsumerStatefulWidget {
  const CustomizeScreen({super.key});

  static const routeName = '/customize';

  @override
  ConsumerState<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends ConsumerState<CustomizeScreen> {
  /// المربع المختار؛ null = أول عنصر في الترتيب.
  WidgetElement? _selected;

  @override
  Widget build(BuildContext context) {
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
          : _body(context, state),
    );
  }

  Widget _body(BuildContext context, AppState state) {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsControllerProvider.notifier);
    final layout = state.settings.layout;
    final selected = _selected ?? layout.first.id;
    final tile = layout.firstWhere((t) => t.id == selected);
    final placed = placedElements([
      for (final t in layout)
        if (t.visible) (id: t.id.name, span: t.span),
    ]);
    void select(WidgetElement e) => setState(() => _selected = e);
    // المعاينة ٣٣٨×٣٥٤ وحولها خلفية ١٦، وتصغر لتأخذ ٤٥٪ من ارتفاع الشاشة حداً أقصى.
    final previewSize = previewWidgetSize + const Offset(32, 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.45,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.fromSize(
                size: previewSize,
                child: RepaintBoundary(
                  key: const Key('customize-preview'),
                  child: WidgetPreview(
                    schedule: state.schedule,
                    now: ref.read(clockProvider)(),
                    backgroundPath: state.backgroundPath,
                    systemColors: state.systemColors,
                    onTileTap: select,
                    selected: selected,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Text(
            l.tileHint,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('tile-panel'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(tile: tile),
                if (tile.visible && !placed.contains(tile.id.name))
                  Text(
                    l.tileOverflow,
                    key: Key('overflow-${tile.id.name}'),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                TileSettings(tile: tile),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 64,
          child: ReorderableListView.builder(
            key: const Key('tile-list'),
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            itemCount: layout.length,
            onReorderItem: c.moveTile,
            itemBuilder: (context, i) {
              final t = layout[i];
              return ReorderableDelayedDragStartListener(
                key: ValueKey('chip-${t.id.name}'),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Chip(
                    tile: t,
                    selected: t.id == selected,
                    overflow: t.visible && !placed.contains(t.id.name),
                    onTap: () => select(t.id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// رقاقة عنصر في الشريط: المختار بلون التمييز، والمخفي باهت، وما لا يتسع عليه علامة.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.tile,
    required this.selected,
    required this.overflow,
    required this.onTap,
  });

  final TileLayout tile;
  final bool selected;
  final bool overflow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    // بلا Tooltip: الضغط المطوّل للسحب.
    return Semantics(
      hint: l.dragHandle,
      child: Opacity(
        opacity: tile.visible ? 1 : 0.45,
        child: Material(
          color: selected ? scheme.primary : scheme.surfaceContainerHighest,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: InkWell(
            key: Key('chip-tap-${tile.id.name}'),
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (overflow) ...[
                    Icon(
                      Icons.error_outline,
                      key: Key('chip-overflow-${tile.id.name}'),
                      size: 18,
                      color: selected ? fg : scheme.error,
                      semanticLabel: l.tileOverflow,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (!tile.visible) ...[
                    Icon(Icons.visibility_off, size: 16, color: fg),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    l.elementName(tile.id.name),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// اسم المربع ومفتاح إظهاره.
class _Header extends ConsumerWidget {
  const _Header({required this.tile});

  final TileLayout tile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l.elementName(tile.id.name),
            key: const Key('panel-name'),
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Text(l.tileVisible),
        Switch(
          key: Key('visible-${tile.id.name}'),
          value: tile.visible,
          onChanged: (v) => ref
              .read(settingsControllerProvider.notifier)
              .setVisible(tile.id, v),
        ),
      ],
    );
  }
}

/// العرض وحجم الخط ومفتاحا العنوان والسطر الفرعي واللونان لمربع واحد.
class TileSettings extends ConsumerWidget {
  const TileSettings({super.key, required this.tile});

  final TileLayout tile;

  static const spanNames = {1: 'small', 2: 'medium', 3: 'wide'};

  /// مربعات لها عنوان (مربعات المعلومات)، ولها سطر فرعي (وكذلك اليوم تحت الساعة والميلادي).
  /// الميزة ٦: عنوان القبلة كلمة «القبلة» في دائرتها، ووصف الموسم «في الوسم:». الإيداعات بلا عنوان
  /// (طلب المالك: حُذف «متبقي على:»). والسطر الفرعي لليوم والطقس سطرا المدينة والحرارة، وللأعمدة الأوقات والأيام،
  /// ولوصف الموسم النقاط بعد الأولى.
  static bool hasTitle(WidgetElement e) => !const {
    WidgetElement.clock,
    WidgetElement.dates,
    WidgetElement.weather,
    WidgetElement.dayWeather,
    WidgetElement.hijri,
    WidgetElement.gregorian,
    WidgetElement.prayerTimes,
    WidgetElement.deposit,
  }.contains(e);

  static bool hasSub(WidgetElement e) => !const {
    WidgetElement.weather,
    WidgetElement.qibla,
    WidgetElement.hijri,
    WidgetElement.gregorian,
  }.contains(e);

  /// «١.٥» بالأرقام العربية (خط Tajawal بلا الفاصلة العشرية العربية ٫).
  static String scaleText(double v) => formatDigits(v.toStringAsFixed(1));

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
    Widget toggle(String key, String text, bool value, ValueChanged<bool> on) =>
        Row(
          children: [
            Expanded(child: Text(text, textAlign: TextAlign.right)),
            Switch(key: Key(key), value: value, onChanged: on),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (id == WidgetElement.qibla) ...[
          // أيقونة القبلة: شريط بدرجات دقيقة بدل صغير/وسط/عريض، والمعاينة فورية أثناء السحب،
          // والحفظ للودجت عند الإفلات. عرض الخانة يتبع الحجم تلقائياً (qiblaSpanFor).
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.qiblaIconSizeLabel,
                    textAlign: TextAlign.right,
                    style: label,
                  ),
                ),
                Text(
                  l.percent(formatDigits((tile.iconScale * 100).round())),
                  key: const Key('qibla-icon-value'),
                  textAlign: TextAlign.right,
                  style: label,
                ),
              ],
            ),
          ),
          Slider(
            key: const Key('qibla-icon-size'),
            min: tileIconMin,
            max: tileIconMax,
            divisions: ((tileIconMax - tileIconMin) / tileIconStep).round(),
            value: tile.iconScale,
            label: l.percent(formatDigits((tile.iconScale * 100).round())),
            onChanged: (v) => c.setQiblaIconScale(v, commit: false),
            onChangeEnd: (v) => c.setQiblaIconScale(v),
          ),
        ] else ...[
          title(l.tileSpanLabel),
          SegmentedButton<int>(
            key: Key('span-${id.name}'),
            showSelectedIcon: false,
            segments: [
              for (final e in spanNames.entries)
                ButtonSegment(
                  value: e.key,
                  label: Text(
                    l.tileSpanName(e.value),
                    key: Key('span-${id.name}-${e.key}'),
                  ),
                ),
            ],
            selected: {tile.span},
            onSelectionChanged: (v) =>
                c.updateTile(id, (t) => t.copyWith(span: v.first)),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.tileFontLabel,
                  textAlign: TextAlign.right,
                  style: label,
                ),
              ),
              Text(
                scaleText(tile.fontScale),
                key: Key('tilefont-value-${id.name}'),
                textAlign: TextAlign.right,
                style: label,
              ),
            ],
          ),
        ),
        Slider(
          key: Key('tilefont-${id.name}'),
          min: tileFontMin,
          max: tileFontMax,
          divisions: ((tileFontMax - tileFontMin) / tileFontStep).round(),
          value: tile.fontScale,
          label: scaleText(tile.fontScale),
          onChanged: (v) => c.updateTile(id, (t) => t.copyWith(fontScale: v)),
        ),
        if (hasTitle(id))
          toggle(
            'showtitle-${id.name}',
            l.tileShowTitle,
            tile.showTitle,
            (v) => c.updateTile(id, (t) => t.copyWith(showTitle: v)),
          ),
        if (hasSub(id))
          toggle(
            'showsub-${id.name}',
            l.tileShowSub,
            tile.showSub,
            (v) => c.updateTile(id, (t) => t.copyWith(showSub: v)),
          ),
        title(l.primaryColorLabel),
        _ColorRow(
          keyPrefix: 'primary-${id.name}',
          selected: tile.primaryColor,
          onPick: (color) =>
              c.updateTile(id, (t) => t.copyWith(primaryColor: () => color)),
        ),
        title(l.secondaryColorLabel),
        _ColorRow(
          keyPrefix: 'secondary-${id.name}',
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
