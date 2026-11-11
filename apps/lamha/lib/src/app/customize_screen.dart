import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../engine/arabic.dart';
import '../engine/widget_layout.dart';
import 'providers.dart';
import 'widget_preview.dart';

/// شاشة «الودجت» الواحدة (١٠/١١/٢٠٢٦، اعتمدها المالك): المعاينة ثابتة في الأعلى، ثم «ألوان جاهزة»،
/// ثم قائمة العناصر (مقبض سحب، والاسم، ومفتاح إظهار). الضغط على عنصر في القائمة أو في المعاينة يفتح
/// لوحة سفلية بثلاثة تبويبات: الحجم، والألوان، والمحتوى.
class CustomizeScreen extends ConsumerStatefulWidget {
  const CustomizeScreen({super.key});

  static const routeName = '/customize';

  @override
  ConsumerState<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends ConsumerState<CustomizeScreen> {
  /// العنصر المفتوحة لوحته (يُميَّز في المعاينة).
  WidgetElement? _open;

  /// حول المعاينة: اللوحة السفلية تقف تحت حدّها فلا تحجب الودجت (طلب المالك ١١/١١/٢٠٢٦).
  final _previewKey = GlobalKey();

  /// ارتفاع محتوى اللوحة: ما تحت المعاينة ناقص مقبض اللوحة، بين ٢٢٠ و٤٤٠.
  double _sheetHeight() {
    final screen = MediaQuery.sizeOf(context).height;
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    final bottom = box == null || !box.hasSize
        ? screen * 0.5
        : box.localToGlobal(Offset(0, box.size.height)).dy;
    return (screen - bottom - kMinInteractiveDimension - 8).clamp(220.0, 440.0);
  }

  Future<void> _edit(WidgetElement e) async {
    setState(() => _open = e);
    final height = _sheetHeight();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      barrierColor: Colors.black26,
      builder: (_) => TileSheet(id: e, height: height),
    );
    if (mounted) setState(() => _open = null);
  }

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
    final placed = placedElements([
      for (final t in layout)
        if (t.visible) (id: t.id.name, span: t.span),
    ]);
    // المعاينة ٣٣٨×٣٥٤ وحولها خلفية ١٦، وتصغر لتأخذ ٤٠٪ من ارتفاع الشاشة حداً أقصى.
    final previewSize = previewWidgetSize + const Offset(32, 32);
    final visibleCount = layout.where((t) => t.visible).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: _previewKey,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
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
                    onTileTap: _edit,
                    selected: _open,
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
        _Presets(layout: layout),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            key: const Key('tile-list'),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: layout.length,
            onReorderItem: c.moveTile,
            itemBuilder: (context, i) {
              final t = layout[i];
              return _Row(
                key: ValueKey('tile-row-${t.id.name}'),
                index: i,
                tile: t,
                overflow: t.visible && !placed.contains(t.id.name),
                onTap: () => _edit(t.id),
                onVisible: (v) {
                  if (!v && visibleCount <= 1) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(l.tilesLastOne)));
                    return;
                  }
                  c.setVisible(t.id, v);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// صف عنصر: مقبض السحب، والاسم (باهت إن كان مخفياً، وعلامة إن لم يتسع)، ومفتاح الإظهار.
class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.index,
    required this.tile,
    required this.overflow,
    required this.onTap,
    required this.onVisible,
  });

  final int index;
  final TileLayout tile;
  final bool overflow;
  final VoidCallback onTap;
  final ValueChanged<bool> onVisible;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final name = tile.id.name;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: Key('chip-tap-$name'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.drag_handle,
                    key: Key('tile-handle-$name'),
                    semanticLabel: l.dragHandle,
                  ),
                ),
              ),
              Expanded(
                child: Opacity(
                  opacity: tile.visible ? 1 : 0.45,
                  child: Text(
                    l.elementName(name),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
              if (overflow)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.error_outline,
                    key: Key('chip-overflow-$name'),
                    size: 20,
                    color: scheme.error,
                    semanticLabel: l.tileOverflow,
                  ),
                ),
              Switch(
                key: Key('tile-switch-$name'),
                value: tile.visible,
                onChanged: onVisible,
              ),
              const Icon(Icons.chevron_left, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// «ألوان جاهزة»: كل دائرة لونان (رئيسي وفرعي) تُطبَّق على كل العناصر.
class _Presets extends ConsumerWidget {
  const _Presets({required this.layout});

  final List<TileLayout> layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsControllerProvider.notifier);
    bool active(TileColor? p, TileColor? s) =>
        layout.every((t) => t.primaryColor == p && t.secondaryColor == s);
    return SizedBox(
      height: 76,
      child: ListView(
        key: const Key('color-presets'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          Center(
            child: Text(
              l.colorPresetsLabel,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(width: 8),
          for (final p in colorPresets)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Semantics(
                button: true,
                selected: active(p.primary, p.secondary),
                label: l.colorPresetName(p.name),
                child: InkResponse(
                  key: Key('preset-${p.name}'),
                  radius: 26,
                  onTap: () => c.applyColors(p.primary, p.secondary),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PresetDot(
                        primary: p.primary,
                        secondary: p.secondary,
                        selected: active(p.primary, p.secondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.colorPresetName(p.name),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// دائرة نصفها اللون الرئيسي ونصفها الفرعي؛ «تلقائي» بأيقونة.
class _PresetDot extends StatelessWidget {
  const _PresetDot({
    required this.primary,
    required this.secondary,
    required this.selected,
  });

  final TileColor? primary;
  final TileColor? secondary;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: primary == null
            ? null
            : LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                stops: const [0.5, 0.5],
                colors: [Color(primary!.argb), Color(secondary!.argb)],
              ),
        border: Border.all(
          color: selected ? Colors.white : Colors.white24,
          width: selected ? 3 : 1,
        ),
      ),
      child: primary == null ? const Icon(Icons.auto_awesome, size: 16) : null,
    );
  }
}

/// اللوحة السفلية لعنصر: اسمه ومفتاح إظهاره، ثم تبويبات الحجم والألوان والمحتوى.
class TileSheet extends ConsumerWidget {
  const TileSheet({super.key, required this.id, this.height = 400});

  final WidgetElement id;

  /// ارتفاع المحتوى (يحسبه [CustomizeScreen] ليبقى تحت المعاينة).
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(settingsControllerProvider).value;
    if (state == null) return const SizedBox.shrink();
    final layout = state.settings.layout;
    final tile = layout.firstWhere((t) => t.id == id);
    final placed = placedElements([
      for (final t in layout)
        if (t.visible) (id: t.id.name, span: t.span),
    ]);
    return SizedBox(
      key: const Key('tile-panel'),
      height: height,
      child: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Header(tile: tile),
            ),
            if (tile.visible && !placed.contains(tile.id.name))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l.tileOverflow,
                  key: Key('overflow-${tile.id.name}'),
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TabBar(
              tabs: [
                Tab(key: const Key('tab-size'), text: l.tabSize),
                Tab(key: const Key('tab-colors'), text: l.tabColors),
                Tab(key: const Key('tab-content'), text: l.tabContent),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final section in TileSection.values)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: TileSettings(tile: tile, section: section),
                    ),
                ],
              ),
            ),
          ],
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
    final layout =
        ref.watch(settingsControllerProvider).value?.settings.layout ??
        const [];
    final last = tile.visible && layout.where((t) => t.visible).length <= 1;
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
          // آخر عنصر ظاهر لا يُخفى.
          onChanged: last
              ? null
              : (v) => ref
                    .read(settingsControllerProvider.notifier)
                    .setVisible(tile.id, v),
        ),
      ],
    );
  }
}

/// تبويبات لوحة العنصر.
enum TileSection { size, colors, content }

/// العرض وحجم الخط ومفتاحا العنوان والسطر الفرعي واللونان لمربع واحد.
class TileSettings extends ConsumerWidget {
  const TileSettings({super.key, required this.tile, required this.section});

  final TileLayout tile;
  final TileSection section;

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
    final size = section == TileSection.size;
    final colors = section == TileSection.colors;
    final content = section == TileSection.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (size && id == WidgetElement.qibla) ...[
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
        ] else if (size) ...[
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
        if (size) ...[
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
        ],
        if (content && !hasTitle(id) && !hasSub(id))
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(l.tileNoContent, textAlign: TextAlign.right),
          ),
        if (content && hasTitle(id))
          toggle(
            'showtitle-${id.name}',
            l.tileShowTitle,
            tile.showTitle,
            (v) => c.updateTile(id, (t) => t.copyWith(showTitle: v)),
          ),
        if (content && hasSub(id))
          toggle(
            'showsub-${id.name}',
            l.tileShowSub,
            tile.showSub,
            (v) => c.updateTile(id, (t) => t.copyWith(showSub: v)),
          ),
        if (colors) ...[
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
            onPick: (color) => c.updateTile(
              id,
              (t) => t.copyWith(secondaryColor: () => color),
            ),
          ),
        ],
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
