import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'providers.dart';
import 'widget_preview.dart';

/// شاشة «نوافذ الودجت» (طلب المالك ٣٠/١٠/٢٠٢٦): تفعيل كل نافذة في الشريط الأفقي أو إيقافها، وترتيبها
/// بسحب المقبض. المعاينة في الأعلى تتغير فوراً، والنوافذ المتبقية تتمدد لتملأ الودجت. الإعدادات
/// التفصيلية (الحجم والألوان) في «تخصيص الودجت».
class TilesScreen extends ConsumerWidget {
  const TilesScreen({super.key});

  static const routeName = '/tiles';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(settingsControllerProvider).value;
    final c = ref.read(settingsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tilesManageTitle),
        actions: [
          TextButton.icon(
            key: const Key('tiles-reset'),
            icon: const Icon(Icons.restart_alt),
            label: Text(l.resetLayout),
            onPressed: state == null ? null : c.resetLayout,
          ),
        ],
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, ref, state),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, AppState state) {
    final l = AppLocalizations.of(context);
    final c = ref.read(settingsControllerProvider.notifier);
    final layout = state.settings.layout;
    final shown = layout.where((t) => t.visible).length;
    final previewSize = previewWidgetSize + const Offset(32, 32);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.38,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox.fromSize(
                size: previewSize,
                child: RepaintBoundary(
                  key: const Key('tiles-preview'),
                  child: WidgetPreview(
                    schedule: state.schedule,
                    now: ref.read(clockProvider)(),
                    backgroundPath: state.backgroundPath,
                    systemColors: state.systemColors,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l.tilesManageHint,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            key: const Key('tiles-list'),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            itemCount: layout.length,
            onReorderItem: c.moveTile,
            itemBuilder: (context, i) {
              final t = layout[i];
              final name = t.id.name;
              return ListTile(
                key: ValueKey('tile-row-$name'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                // المقبض في بداية السطر (يمين في العربية) ثم الاسم ثم المفتاح.
                leading: ReorderableDragStartListener(
                  key: Key('tile-handle-$name'),
                  index: i,
                  child: Tooltip(
                    message: l.tilesDragHandle,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
                title: Text(
                  l.elementName(name),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: t.visible
                        ? null
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Switch(
                  key: Key('tile-switch-$name'),
                  value: t.visible,
                  onChanged: (on) {
                    // آخر نافذة ظاهرة لا تُطفأ: الودجت الفارغة بلا معنى.
                    if (!on && t.visible && shown == 1) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(content: Text(l.tilesLastOne)),
                        );
                      return;
                    }
                    c.setVisible(t.id, on);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
