import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rihla_recorder/rihla_recorder.dart';

import '../../data/settings/camera_rotation_store.dart';
import '../../l10n/app_localizations.dart';
import 'camera_rotation_controller.dart';
import 'camera_rotation_test_page.dart';

/// الإعدادات: تدوير الكاميرا (معايرة يدوية، FEEDBACK 3 البند 9) وتشخيص الكاميرا.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(16),
          children: const [_RotationSection(), SizedBox(height: 24), _DiagnosticsSection()],
        ),
      ),
    );
  }
}

/// أزرار الزوايا 0/90/180/270 (تُستعمل في الإعدادات وصفحة الاختبار).
class RotationChoices extends ConsumerWidget {
  const RotationChoices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final value = ref.watch(cameraRotationProvider);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in cameraRotationChoices)
          ChoiceChip(
            key: ValueKey('rotation-$d'),
            label: Text(l.rotationDegreesLabel(d)),
            selected: value == d,
            onSelected: (_) => ref.read(cameraRotationProvider.notifier).set(d),
          ),
      ],
    );
  }
}

class _RotationSection extends ConsumerWidget {
  const _RotationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.settingsCameraRotation, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l.settingsCameraRotationHint),
        const SizedBox(height: 12),
        const RotationChoices(),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('camera-test-button'),
          icon: const Icon(Icons.videocam),
          label: Text(l.cameraRotationTest),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CameraRotationTestPage()),
          ),
        ),
      ],
    );
  }
}

class _DiagnosticsSection extends ConsumerWidget {
  const _DiagnosticsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final info = ref.watch(orientationInfoProvider);
    final offset = ref.watch(cameraRotationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.cameraDiagTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l.cameraDiagHint),
        const SizedBox(height: 8),
        DiagnosticsTable(info: info, offset: offset),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              key: const ValueKey('diag-refresh'),
              onPressed: () => ref.read(orientationInfoProvider.notifier).refresh(),
              child: Text(l.cameraDiagRefresh),
            ),
            OutlinedButton(
              key: const ValueKey('diag-copy'),
              onPressed: () async {
                final text = (info ?? const OrientationInfo()).toText();
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.cameraDiagCopied)));
                }
              },
              child: Text(l.cameraDiagCopy),
            ),
          ],
        ),
      ],
    );
  }
}

/// جدول قيم التشخيص. الإزاحة المعروضة هي المحفوظة حالياً.
class DiagnosticsTable extends StatelessWidget {
  const DiagnosticsTable({super.key, required this.info, required this.offset});
  final OrientationInfo? info;
  final int offset;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String v(int? x) => x == null ? l.cameraDiagUnavailable : l.rotationDegreesLabel(x);
    final i = info;
    final rows = <(String, String)>[
      (l.cameraDiagSensor, v(i?.sensorRotation)),
      (l.cameraDiagDisplay, v(i?.displayRotation)),
      (l.cameraDiagCameraX, v(i?.rotationDegrees)),
      (l.cameraDiagComputed, v(i?.computedRotation)),
      (l.cameraDiagOffset, v(offset)),
      (l.cameraDiagFinal, v(i?.finalRotation)),
    ];
    return Column(
      key: const ValueKey('diag-table'),
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(r.$1)),
                Text(r.$2, textDirection: TextDirection.ltr),
              ],
            ),
          ),
      ],
    );
  }
}
