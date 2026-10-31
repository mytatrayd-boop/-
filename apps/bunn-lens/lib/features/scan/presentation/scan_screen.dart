import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../domain/analysis.dart';
import '../../../domain/scan.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../scan_flow.dart';
import '../scan_providers.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(scanFlowProvider);
    ref.listen(scanFlowProvider, (_, next) {
      if (next is ScanDone) {
        ref.read(scanFlowProvider.notifier).reset();
        context.go('${AppRoutes.scan}/result/${next.scanId}');
      }
    });
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: SafeArea(
        child: switch (state) {
          ScanIdle() || ScanDone() => const _IdleView(),
          ScanPreview(:final bytes) => _PreviewView(bytes: bytes),
          ScanAnalyzing(:final bytes) => _AnalyzingView(bytes: bytes),
          ScanFailed() => _FailedView(state: state),
        },
      ),
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView();

  Future<void> _pick(BuildContext context, WidgetRef ref, PickSource source) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(imagePortProvider).pick(source);
      if (bytes != null) ref.read(scanFlowProvider.notifier).preview(bytes);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.scanPickFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = ref.watch(scanTypeProvider);
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(l10n.scanTypePick, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<ScanType>(
          segments: [
            ButtonSegment(value: ScanType.bean, label: Text(l10n.scanTypeBean), icon: const Icon(Icons.grain)),
            ButtonSegment(value: ScanType.coffee, label: Text(l10n.scanTypeCoffee), icon: const Icon(Icons.local_cafe_outlined)),
          ],
          selected: {type},
          onSelectionChanged: (s) => ref.read(scanTypeProvider.notifier).set(s.first),
        ),
        const SizedBox(height: 16),
        Text(type == ScanType.bean ? l10n.scanGuide : l10n.scanGuideCoffee, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _pick(context, ref, PickSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.scanTakePhoto),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pick(context, ref, PickSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(l10n.scanFromGallery),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsetsDirectional.all(12),
          decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Text(l10n.scanDisclaimer, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

Widget _photo(Uint8List bytes) => ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(aspectRatio: 4 / 3, child: Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)),
    );

class _PreviewView extends ConsumerWidget {
  const _PreviewView({required this.bytes});
  final Uint8List bytes;

  Future<void> _use(BuildContext context, WidgetRef ref) async {
    final store = ref.read(disclosureStoreProvider);
    if (!await store.accepted()) {
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final l10n = AppLocalizations.of(ctx);
          return AlertDialog(
            title: Text(l10n.scanDisclosureTitle),
            content: Text(l10n.scanDisclosureBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.scanDisclosureAccept)),
            ],
          );
        },
      );
      if (ok != true) return;
      await store.accept();
    }
    unawaited(ref.read(scanFlowProvider.notifier).analyze(bytes));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        Text(l10n.scanPreviewTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _photo(bytes),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => _use(context, ref), child: Text(l10n.scanUsePhoto)),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () => ref.read(scanFlowProvider.notifier).reset(), child: Text(l10n.scanRetake)),
      ],
    );
  }
}

class _AnalyzingView extends ConsumerStatefulWidget {
  const _AnalyzingView({required this.bytes});
  final Uint8List bytes;

  @override
  ConsumerState<_AnalyzingView> createState() => _AnalyzingViewState();
}

class _AnalyzingViewState extends ConsumerState<_AnalyzingView> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [l10n.scanAnalyzing1, l10n.scanAnalyzing2, l10n.scanAnalyzing3];
    final slow = _seconds >= 10;
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        _photo(widget.bytes),
        const SizedBox(height: 32),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Center(
          child: Text(slow ? l10n.scanAnalyzingSlow : steps[(_seconds ~/ 3) % steps.length],
              key: const Key('analyzing-text')),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
            onPressed: () => ref.read(scanFlowProvider.notifier).reset(), child: Text(l10n.scanCancel)),
      ],
    );
  }
}

class _FailedView extends ConsumerWidget {
  const _FailedView({required this.state});
  final ScanFailed state;

  String _message(AppLocalizations l10n) {
    if (state.unclear) return l10n.scanErrUnclear;
    return switch (state.error) {
      AnalysisError.offline => l10n.scanErrOffline,
      AnalysisError.busy => l10n.scanErrBusy,
      AnalysisError.quotaExhausted => l10n.scanErrQuota,
      AnalysisError.unauthorized => l10n.scanErrUnauthorized,
      _ => l10n.scanErrUnknown,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canRetry = !state.unclear && state.error != AnalysisError.quotaExhausted;
    final flow = ref.read(scanFlowProvider.notifier);
    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        _photo(state.bytes),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsetsDirectional.all(16),
          decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_message(l10n),
                  style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onErrorContainer)),
              const SizedBox(height: 8),
              Text(l10n.scanNotCounted,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (canRetry) ...[
          FilledButton(onPressed: () => flow.analyze(state.bytes), child: Text(l10n.retry)),
          const SizedBox(height: 12),
        ],
        OutlinedButton(onPressed: flow.reset, child: Text(l10n.scanRetakePhoto)),
      ],
    );
  }
}
