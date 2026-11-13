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

  /// وضع تحريك إطار الخلفية (DECISIONS ٣٠): يظهر محرر الإطار وحده، والعناصر لا تتأثر.
  bool _framing = false;

  /// حول المعاينة: اللوحة السفلية تقف تحت حدّها فلا تحجب الودجت (طلب المالك ١١/١١/٢٠٢٦).
  final _previewKey = GlobalKey();

  /// ارتفاع محتوى اللوحة: ما تحت المعاينة ناقص مقبض اللوحة، بين ١٦٠ و٤٤٠ (المعاينة أكبر الآن، ومحتوى
  /// اللوحة يُمرَّر).
  double _sheetHeight() {
    final screen = MediaQuery.sizeOf(context).height;
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    final bottom = box == null || !box.hasSize
        ? screen * 0.5
        : box.localToGlobal(Offset(0, box.size.height)).dy;
    return (screen - bottom - kMinInteractiveDimension - 8).clamp(160.0, 440.0);
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

  /// المعاينة بمحرر التخطيط الحر، مصغّرة لتتسع مكانها.
  Widget _preview(AppState state, Key key, {ValueChanged<WidgetElement>? onTap}) {
    final layout = state.settings.layout;
    final c = ref.read(settingsControllerProvider.notifier);
    final tap = onTap ?? _edit;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox.fromSize(
        size: previewWidgetSize + const Offset(32, 32),
        child: RepaintBoundary(
          key: key,
          child: WidgetPreview(
            schedule: state.schedule,
            now: ref.read(clockProvider)(),
            backgroundPath: state.backgroundPath,
            systemColors: state.systemColors,
            onTileTap: tap,
            selected: _open,
            floatOverlay: (box) {
              if (_framing) {
                return FrameEditor(
                  box: box,
                  frame: state.settings.frame ?? const FloatRect(0, 0, 1, 1),
                  onChange: c.setFrame,
                  onReset: state.settings.frame == null ? null : () => c.setFrame(null),
                );
              }
              final floats = {
                for (final t in layout)
                  if (t.visible && t.float != null) t.id: t.float!,
              };
              if (floats.isEmpty) return const SizedBox.shrink();
              return FloatEditor(
                box: box,
                floats: floats,
                selected: _open,
                onTap: tap,
                onChange: c.setFloat,
              );
            },
            overlay: (grid) => _framing ? const SizedBox.shrink() : FreeEditor(
              grid: grid,
              rects: rectsOf(layout),
              selected: _open,
              onTap: tap,
              onPlace: c.placeTile,
            ),
          ),
        ),
      ),
    );
  }

  /// المعاينة بكامل الشاشة للسحب والتكبير بدقة؛ الضغط على مربع يفتح لوحته فوقها.
  Future<void> _fullscreen() => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => Consumer(
            builder: (context, ref, _) {
              final l = AppLocalizations.of(context);
              final state = ref.watch(settingsControllerProvider).value;
              return Scaffold(
                appBar: AppBar(title: Text(l.customizeTitle)),
                body: state == null
                    ? const Center(child: CircularProgressIndicator())
                    : SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Center(
                            child: _preview(
                              state,
                              const Key('fullscreen-preview'),
                              onTap: (e) => showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                isScrollControlled: true,
                                barrierColor: Colors.black26,
                                builder: (_) => TileSheet(id: e, height: 360),
                              ),
                            ),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(settingsControllerProvider).value;
    final c = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.customizeTitle),
        actions: [
          IconButton(
            key: const Key('frame-toggle'),
            icon: Icon(_framing ? Icons.check : Icons.crop_free),
            tooltip: _framing ? l.frameDone : l.frameEdit,
            onPressed: state == null ? null : () => setState(() => _framing = !_framing),
          ),
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
    // ما لا يتسع في الشبكة (أسفلها) لا يظهر في الودجت.
    // المربع العائم خارج الشبكة فلا «يتجاوز» أسفلها: لا تحذير له.
    final placed = {
      for (final e in rectsOf(layout).entries)
        if (e.value.bottom <= freeRows) e.key.name,
      for (final t in layout)
        if (t.floating) t.id.name,
    };
    // المعاينة بعرض الشاشة وحولها خلفية ١٦، وتصغر لتأخذ ٥٥٪ من ارتفاع الشاشة حداً أقصى (كانت ٤٠٪ فصغرت
    // جداً على آيفون الصغير، ملاحظة المالك ١١/١١/٢٠٢٦). زر «ملء الشاشة» يفتحها بكامل الشاشة للتعديل.
    final visibleCount = layout.where((t) => t.visible).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          key: _previewKey,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.55,
            ),
            child: Stack(
              children: [
                Center(child: _preview(state, const Key('customize-preview'))),
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: IconButton.filledTonal(
                    key: const Key('preview-fullscreen'),
                    tooltip: l.previewFullscreen,
                    icon: const Icon(Icons.fullscreen),
                    onPressed: _fullscreen,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ReorderableListView.builder(
            key: const Key('tile-list'),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 16),
            // التلميح والألوان الجاهزة تتحرك مع القائمة فتبقى المساحة للمعاينة.
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
              ],
            ),
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
    // ما لا يتسع في الشبكة (أسفلها) لا يظهر في الودجت.
    // المربع العائم خارج الشبكة فلا «يتجاوز» أسفلها: لا تحذير له.
    final placed = {
      for (final e in rectsOf(layout).entries)
        if (e.value.bottom <= freeRows) e.key.name,
      for (final t in layout)
        if (t.floating) t.id.name,
    };
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
    WidgetElement.weekday,
    WidgetElement.cityTemp,
    WidgetElement.hijri,
    WidgetElement.gregorian,
    WidgetElement.prayerTimes,
    WidgetElement.deposit,
  }.contains(e);

  static bool hasSub(WidgetElement e) => !const {
    WidgetElement.weather,
    WidgetElement.weekday,
    WidgetElement.cityTemp,
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
        if (size && id == WidgetElement.dayWeather)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: const Key('split-day-weather'),
                icon: const Icon(Icons.call_split),
                label: Text(l.splitDayWeather),
                onPressed: () => c.splitDayWeather(),
              ),
            ),
          ),
        if (size) ...[
          toggle('float-toggle', l.tileFloatLabel, tile.floating, (v) => c.setFloating(id, v)),
          if (tile.floating)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(l.tileFloatHint, textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
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

/// محرر التخطيط الحر فوق المعاينة (طلب المالك ١١/١١/٢٠٢٦): كل عنصر ظاهر صندوق على الشبكة؛ الضغط
/// يفتح لوحته، والسحب يحرّكه، ومقبض الزاوية السفلى (يسار في RTL) يكبّره ويصغّره. يُثبَّت على
/// الخلايا عند الإفلات، وما يتداخل ينزل ثم يصعد الجميع (placeTile).
/// محرر المربعات العائمة (DECISIONS ٢٩): سحب المربع يحرّكه، ومقابضه الأربعة تغيّر مقاسه (كل زاوية تحرك
/// ضلعيها فقط، فيكبر أو يصغر في أي اتجاه). فوق المربعات كلها، فلا يتأثر بالرصّ. يحفظ عند الإفلات.
class FloatEditor extends StatefulWidget {
  const FloatEditor({
    super.key,
    required this.box,
    required this.floats,
    required this.selected,
    required this.onTap,
    required this.onChange,
  });

  /// مقاس الودجت كاملاً بالبكسل.
  final Size box;
  final Map<WidgetElement, FloatRect> floats;
  final WidgetElement? selected;
  final ValueChanged<WidgetElement> onTap;
  final Future<void> Function(WidgetElement id, FloatRect r, {bool commit}) onChange;

  @override
  State<FloatEditor> createState() => _FloatEditorState();
}

class _FloatEditorState extends State<FloatEditor> {
  WidgetElement? _active;

  /// المربع الذي تظهر مقابضه (آخر ما لُمس أو سُحب).
  WidgetElement? _sel;

  /// الزاوية المسحوبة، أو null للتحريك.
  ({bool left, bool top})? _corner;
  late ({double right, double top, double width, double height}) _start;
  var _total = Offset.zero;

  ({double right, double top, double width, double height}) _px(WidgetElement id) =>
      widget.floats[id]!.within(widget.box.width, widget.box.height);

  void _begin(WidgetElement id, ({bool left, bool top})? corner) {
    _start = _px(id);
    _total = Offset.zero;
    setState(() {
      _active = id;
      _sel = id;
      _corner = corner;
    });
  }

  /// الإزاحة على الشاشة: اليمين يُعدّ من الحافة اليمنى فتُطرح إزاحة x. كل زاوية تحرك ضلعيها على الشاشة.
  void _update(Offset d) {
    final id = _active;
    if (id == null) return;
    _total += d;
    final w = widget.box.width, h = widget.box.height;
    var left = w - _start.right - _start.width;
    var right = w - _start.right;
    var top = _start.top;
    var bottom = _start.top + _start.height;
    final minW = FloatRect.minW * w, minH = FloatRect.minH * h;
    final c = _corner;
    if (c == null) {
      left += _total.dx;
      right += _total.dx;
      top += _total.dy;
      bottom += _total.dy;
    } else {
      if (c.left) {
        left = (left + _total.dx).clamp(0.0, right - minW).toDouble();
      } else {
        right = (right + _total.dx).clamp(left + minW, w).toDouble();
      }
      if (c.top) {
        top = (top + _total.dy).clamp(0.0, bottom - minH).toDouble();
      } else {
        bottom = (bottom + _total.dy).clamp(top + minH, h).toDouble();
      }
    }
    widget.onChange(id, FloatRect.fromPixels(w - right, top, right - left, bottom - top, w, h), commit: false);
  }

  Future<void> _end() async {
    final id = _active;
    setState(() => _active = null);
    if (id != null && widget.floats[id] != null) await widget.onChange(id, widget.floats[id]!);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sel = _sel ?? widget.selected;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final id in widget.floats.keys)
          Builder(builder: (context) {
            final f = _px(id);
            final active = id == sel || id == _active;
            return Positioned(
              right: f.right,
              top: f.top,
              width: f.width,
              height: f.height,
              child: GestureDetector(
                key: Key('float-box-${id.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _sel = id);
                  widget.onTap(id);
                },
                onPanStart: (_) => _begin(id, null),
                onPanUpdate: (d) => _update(d.delta),
                onPanEnd: (_) => _end(),
                onPanCancel: () => setState(() => _active = null),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: active ? scheme.primary : Colors.white38, width: active ? 2 : 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            );
          }),
        // مقابض المحدد فوق كل المربعات العائمة.
        if (sel != null && widget.floats[sel] != null)
          for (final corner in const [
            (left: true, top: false),
            (left: false, top: false),
            (left: true, top: true),
            (left: false, top: true),
          ])
            Builder(builder: (context) {
              final f = _px(sel);
              final leftEdge = widget.box.width - f.right - f.width;
              return Positioned(
                // مركز المقبض داخل الزاوية بـ ٨ فيبقى قابلاً للمس على حافة الودجت.
                left: (corner.left ? leftEdge + 8 : leftEdge + f.width - 8) - 22,
                top: (corner.top ? f.top + 8 : f.top + f.height - 8) - 22,
                width: 44,
                height: 44,
                child: GestureDetector(
                  key: Key('float-handle-${corner.top ? 't' : 'b'}${corner.left ? 'l' : 'r'}-${sel.name}'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _begin(sel, corner),
                  onPanUpdate: (d) => _update(d.delta),
                  onPanEnd: (_) => _end(),
                  onPanCancel: () => setState(() => _active = null),
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ),
              );
            }),
      ],
    );
  }
}

/// محرر إطار الخلفية (DECISIONS ٣٠): يحرّك لوحة الخلفية وحدها ويكبّرها ويصغّرها (السحب للتحريك، والمقابض
/// الأربعة للمقاس، كل زاوية تحرك ضلعيها). العناصر الداخلية لا تتحرك ولا يتغير مقاسها. يحفظ عند الإفلات.
class FrameEditor extends StatefulWidget {
  const FrameEditor({super.key, required this.box, required this.frame, required this.onChange, this.onReset});

  final Size box;
  final FloatRect frame;
  final Future<void> Function(FloatRect? r, {bool commit}) onChange;

  /// يعيد الإطار ليملأ الودجت؛ null إن لم يكن محرّكاً.
  final VoidCallback? onReset;

  @override
  State<FrameEditor> createState() => _FrameEditorState();
}

class _FrameEditorState extends State<FrameEditor> {
  ({bool left, bool top})? _corner;
  bool _dragging = false;
  late ({double right, double top, double width, double height}) _start;
  var _total = Offset.zero;

  ({double right, double top, double width, double height}) get _px => widget.frame.within(widget.box.width, widget.box.height);

  void _begin(({bool left, bool top})? corner) {
    _start = _px;
    _total = Offset.zero;
    setState(() {
      _dragging = true;
      _corner = corner;
    });
  }

  void _update(Offset d) {
    _total += d;
    final w = widget.box.width, h = widget.box.height;
    var left = w - _start.right - _start.width;
    var right = w - _start.right;
    var top = _start.top;
    var bottom = _start.top + _start.height;
    final minW = 0.3 * w, minH = 0.2 * h;
    final c = _corner;
    if (c == null) {
      left += _total.dx;
      right += _total.dx;
      top += _total.dy;
      bottom += _total.dy;
    } else {
      if (c.left) {
        left = (left + _total.dx).clamp(0.0, right - minW).toDouble();
      } else {
        right = (right + _total.dx).clamp(left + minW, w).toDouble();
      }
      if (c.top) {
        top = (top + _total.dy).clamp(0.0, bottom - minH).toDouble();
      } else {
        bottom = (bottom + _total.dy).clamp(top + minH, h).toDouble();
      }
    }
    widget.onChange(FloatRect.fromPixels(w - right, top, right - left, bottom - top, w, h), commit: false);
  }

  Future<void> _end() async {
    setState(() => _dragging = false);
    await widget.onChange(widget.frame);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = _px;
    final leftEdge = widget.box.width - f.right - f.width;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: f.right,
          top: f.top,
          width: f.width,
          height: f.height,
          child: GestureDetector(
            key: const Key('frame-box'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => _begin(null),
            onPanUpdate: (d) => _update(d.delta),
            onPanEnd: (_) => _end(),
            onPanCancel: () => setState(() => _dragging = false),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.primary, width: _dragging ? 3 : 2),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        for (final corner in const [
          (left: true, top: false),
          (left: false, top: false),
          (left: true, top: true),
          (left: false, top: true),
        ])
          Positioned(
            // مركز المقبض داخل الزاوية بـ ١٠ فيبقى قابلاً للمس حين يملأ الإطار الودجت كلها.
            left: (corner.left ? leftEdge + 10 : leftEdge + f.width - 10) - 22,
            top: (corner.top ? f.top + 10 : f.top + f.height - 10) - 22,
            width: 44,
            height: 44,
            child: GestureDetector(
              key: Key('frame-handle-${corner.top ? 't' : 'b'}${corner.left ? 'l' : 'r'}'),
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => _begin(corner),
              onPanUpdate: (d) => _update(d.delta),
              onPanEnd: (_) => _end(),
              onPanCancel: () => setState(() => _dragging = false),
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
        if (widget.onReset != null)
          Positioned(
            right: 8,
            bottom: 8,
            child: FilledButton.tonalIcon(
              key: const Key('frame-reset'),
              onPressed: widget.onReset,
              icon: const Icon(Icons.fullscreen),
              label: Text(AppLocalizations.of(context).frameReset),
            ),
          ),
      ],
    );
  }
}

class FreeEditor extends StatefulWidget {
  const FreeEditor({
    super.key,
    required this.grid,
    required this.rects,
    required this.selected,
    required this.onTap,
    required this.onPlace,
  });

  /// مقاس شبكة المربعات بالبكسل.
  final Size grid;
  final Map<WidgetElement, GridRect> rects;
  final WidgetElement? selected;
  final ValueChanged<WidgetElement> onTap;

  /// يعيد false إذا رُفض الموضع.
  final Future<bool> Function(WidgetElement id, GridRect target) onPlace;

  @override
  State<FreeEditor> createState() => _FreeEditorState();
}

class _FreeEditorState extends State<FreeEditor> {
  WidgetElement? _active;

  /// المربع الذي تظهر مقابضه الأربعة (آخر ما ضُغط أو سُحب، أو المفتوحة لوحته).
  WidgetElement? _sel;

  /// الزاوية المسحوبة للتكبير، أو null للتحريك.
  ({bool left, bool top})? _corner;
  Offset _delta = Offset.zero;

  double get _cw => widget.grid.width / freeCols;
  double get _ch => widget.grid.height / freeRows;

  /// المستطيل بالبكسل: x يُعدّ من اليمين.
  Rect _px(GridRect r) => Rect.fromLTWH((freeCols - r.x - r.w) * _cw, r.y * _ch, r.w * _cw, r.h * _ch);

  /// موضع الإفلات على الخلايا من الإزاحة. [_corner]: المقبض المسحوب (left/top بالبكسل على الشاشة)،
  /// وكل زاوية تحرك ضلعيها فقط، فيكبر المربع أو يصغر في أي اتجاه.
  GridRect _target(GridRect r) {
    final dx = (_delta.dx / _cw).round();
    final dy = (_delta.dy / _ch).round();
    final corner = _corner;
    if (corner == null) {
      return GridRect((r.x - dx).clamp(0, freeCols - r.w), (r.y + dy).clamp(0, freeRows - 1), r.w, r.h);
    }
    // x يُعدّ من اليمين: الضلع الأيسر على الشاشة هو x+w، والأيمن هو x.
    var x = r.x, y = r.y, right = r.x + r.w, bottom = r.y + r.h;
    if (corner.left) {
      right = (right - dx).clamp(x + 1, freeCols);
    } else {
      x = (x - dx).clamp(0, right - 1);
    }
    if (corner.top) {
      y = (y + dy).clamp(0, bottom - 1);
    } else {
      bottom = (bottom + dy).clamp(y + 1, y + freeRows);
    }
    return GridRect(x, y, right - x, bottom - y);
  }

  Future<void> _end() async {
    final id = _active;
    if (id == null) return;
    final target = _target(widget.rects[id]!);
    setState(() {
      _active = null;
      _delta = Offset.zero;
    });
    if (target == widget.rects[id]) return;
    final ok = await widget.onPlace(id, target);
    if (!ok && mounted) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.freeLayoutRejected)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final e in widget.rects.entries)
          if (e.value.bottom <= freeRows) ...[
            Positioned.fromRect(
              rect: _px(e.value).deflate(2),
              child: GestureDetector(
                key: Key('free-box-${e.key.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _sel = e.key);
                  widget.onTap(e.key);
                },
                onPanStart: (_) => setState(() {
                  _active = e.key;
                  _sel = e.key;
                  _corner = null;
                  _delta = Offset.zero;
                }),
                onPanUpdate: (d) => setState(() => _delta += d.delta),
                onPanEnd: (_) => _end(),
                onPanCancel: () => setState(() => _active = null),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: e.key == (_sel ?? widget.selected) || e.key == _active ? scheme.primary : Colors.white38,
                      width: e.key == (_sel ?? widget.selected) || e.key == _active ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        // مقابض التكبير الأربعة للمربع المحدد فقط، فوق كل المربعات فلا يغطيها جار ولا تتداخل مقابض
        // مربعين في زاوية مشتركة (منطقة لمس ٤٤، ونقطة ١٨). أسماؤها: free-handle-<العنصر> للزاوية السفلى
        // اليسرى، وfree-handle-<الزاوية>-<العنصر> للبقية.
        for (final e in widget.rects.entries)
          if (e.key == (_sel ?? widget.selected) && e.value.bottom <= freeRows)
          for (final corner in const [
            (left: true, top: false),
            (left: false, top: false),
            (left: true, top: true),
            (left: false, top: true),
          ])
            Positioned(
              // مركز المقبض داخل الزاوية بـ ٨ فيبقى قابلاً للمس على حافة الشبكة.
              left: (corner.left ? _px(e.value).left + 8 : _px(e.value).right - 8) - 22,
              top: (corner.top ? _px(e.value).top + 8 : _px(e.value).bottom - 8) - 22,
              width: 44,
              height: 44,
              child: GestureDetector(
                key: Key(corner.left && !corner.top
                    ? 'free-handle-${e.key.name}'
                    : 'free-handle-${corner.top ? 't' : 'b'}${corner.left ? 'l' : 'r'}-${e.key.name}'),
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => setState(() {
                  _active = e.key;
                  _corner = corner;
                  _delta = Offset.zero;
                }),
                onPanUpdate: (d) => setState(() => _delta += d.delta),
                onPanEnd: (_) => _end(),
                onPanCancel: () => setState(() => _active = null),
                child: Center(
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
        // الإطار الشبحي حيث سيستقر العنصر.
        if (_active != null && widget.rects[_active] != null)
          Positioned.fromRect(
            key: const Key('free-ghost'),
            rect: _px(_target(widget.rects[_active]!)).deflate(2),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.25),
                  border: Border.all(color: scheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
