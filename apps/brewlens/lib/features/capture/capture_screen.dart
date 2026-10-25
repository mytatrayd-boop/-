import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/data_providers.dart';
import '../../app/failure_text.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../domain/models/analysis_result.dart';
import '../../domain/models/app_failure.dart';
import '../../domain/models/coffee_type.dart';
import '../../l10n/app_localizations.dart';
import '../../services/image_capture_service.dart';
import '../../widgets/usage_counter.dart';

/// الكاميرا (F5، DESIGN §3.5): نوع المشروب، كاميرا النظام أو المعرض عبر
/// image_picker (D17)، ثم التحليل. خلفية سوداء ثابتة في الثيمين.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  static const _black = Colors.black;
  static const _white = Colors.white;

  Uint8List? _image;
  var _busy = false;
  var _slow = false;
  var _cameraDenied = false;
  Timer? _slowTimer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // بعد منح الصلاحية من الإعدادات: نعيد تفعيل الالتقاط؛ الطلب التالي يتحقق.
    _lifecycle = AppLifecycleListener(onResume: () {
      if (mounted && _cameraDenied) setState(() => _cameraDenied = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLost());
  }

  /// صورة التُقطت قبل أن يُنهي أندرويد التطبيق (retrieveLostData).
  Future<void> _recoverLost() async {
    final bytes = await ref.read(imageCaptureServiceProvider).retrieveLost();
    if (bytes != null && mounted && !_busy) await _analyze(bytes);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<bool> _limitReached() async {
    try {
      final usage = await ref.read(usageProvider.future);
      return usage.remaining <= 0;
    } on Object {
      return false; // الخادم يقرر عند الإرسال.
    }
  }

  Future<void> _pick(CaptureSource source) async {
    if (_busy) return;
    if (await _limitReached()) {
      if (mounted) context.push(Routes.paywall);
      return;
    }
    final capture = ref.read(imageCaptureServiceProvider);
    Uint8List? bytes;
    // يمنع فتح المنتقي مرتين (already_active).
    setState(() => _busy = true);
    try {
      bytes = await capture.pick(source);
    } on CaptureAccessDenied catch (e) {
      if (!mounted) return;
      if (e.source == CaptureSource.camera) {
        setState(() => _cameraDenied = true);
      } else {
        await _showGalleryDenied();
      }
      return;
    } on Object catch (e) {
      if (mounted) _snack(failureText(AppLocalizations.of(context), e));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (bytes == null || !mounted) return;
    setState(() => _cameraDenied = false);
    await _analyze(bytes);
  }

  Future<void> _analyze(Uint8List bytes) async {
    final type = ref.read(lastCoffeeTypeProvider);
    final lang = Localizations.localeOf(context).languageCode;
    setState(() {
      _image = bytes;
      _busy = true;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _slow = true);
    });
    AnalysisResult? result;
    Object? error;
    try {
      result = await ref.read(analysisRepositoryProvider).analyze(bytes, type: type, languageCode: lang);
    } on Object catch (e) {
      error = e;
    }
    _slowTimer?.cancel();
    if (!mounted) return;
    ref.invalidate(usageProvider);
    setState(() => _busy = false);
    if (result != null && result.imageValid) {
      ref.read(pendingAnalysisProvider.notifier).set(
            PendingAnalysis(imageBytes: bytes, type: type, result: result),
          );
      context.pushReplacement(Routes.result);
      return;
    }
    if (result != null) {
      await _showRejected(AppFailure.invalidImage(result.reason ?? InvalidImageReason.other));
      return;
    }
    await _handleError(error!, bytes);
  }

  Future<void> _handleError(Object error, Uint8List bytes) async {
    final l = AppLocalizations.of(context);
    final code = error is AppFailure ? error.code : null;
    switch (code) {
      case FailureCode.limitReached:
        setState(() => _image = null);
        context.push(Routes.paywall);
      case FailureCode.fairUseReached:
        setState(() => _image = null);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l.failureFairUseReached),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.ok))],
          ),
        );
      case FailureCode.invalidImage:
        await _showRejected(error as AppFailure);
      case FailureCode.offline:
        // الصورة تبقى على الشاشة مع «إعادة الإرسال» بلا التقاط جديد.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l.failureOffline),
          action: SnackBarAction(
            label: l.resubmit,
            onPressed: () {
              if (mounted && !_busy) _analyze(bytes);
            },
          ),
        ));
      case FailureCode.analysisFailed || FailureCode.timeout || FailureCode.servicePaused:
        final resend = await _sheet(
          icon: Icons.cloud_off_outlined,
          message: l.failureServiceUnavailable,
          primary: l.resubmit,
          secondary: l.tryLater,
        );
        if (!mounted) return;
        if (resend ?? false) {
          await _analyze(bytes);
        } else {
          setState(() => _image = null);
        }
      default:
        setState(() => _image = null);
        _snack(failureText(l, error));
    }
  }

  Future<void> _showRejected(AppFailure failure) async {
    final l = AppLocalizations.of(context);
    await _sheet(
      icon: switch (failure.reason) {
        InvalidImageReason.tooDark => Icons.brightness_low,
        InvalidImageReason.blurry => Icons.blur_on,
        InvalidImageReason.noCupVisible => Icons.crop_free,
        _ => Icons.no_drinks_outlined,
      },
      message: failureText(l, failure),
      note: l.attemptNotCounted,
      primary: l.retakePhoto,
    );
    if (mounted) setState(() => _image = null);
  }

  /// ورقة سفلية بنمط واحد؛ true = الزر الرئيسي.
  Future<bool?> _sheet({
    required IconData icon,
    required String message,
    required String primary,
    String? note,
    String? secondary,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final text = Theme.of(context).textTheme;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(message, style: text.titleMedium, textAlign: TextAlign.center),
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Text(note,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(color: successColor(context))),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(primary)),
                  if (secondary != null)
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(secondary)),
                ],
              ),
            ),
          );
        },
      );

  Future<void> _showGalleryDenied() async {
    final l = AppLocalizations.of(context);
    final open = await _sheet(
      icon: Icons.photo_library_outlined,
      message: l.galleryDenied,
      primary: l.openSettings,
      secondary: l.cancel,
    );
    if (open ?? false) await ref.read(imageCaptureServiceProvider).openAppSettings();
  }

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final type = ref.watch(lastCoffeeTypeProvider);
    final usage = ref.watch(usageProvider).value;
    final simulator = ref.watch(rejectionSimulatorProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l.close,
                    color: _white,
                    onPressed: _busy ? null : () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(child: Center(child: usage == null ? const SizedBox.shrink() : UsageCounter(usage: usage))),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(child: _preview(l, text)),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  for (final t in CoffeeType.values)
                    ChoiceChip(
                      label: Text(coffeeTypeLabel(l, t)),
                      selected: t == type,
                      onSelected: _busy ? null : (_) => ref.read(lastCoffeeTypeProvider.notifier).set(t),
                    ),
                ],
              ),
            ),
            if (type.isVisualLimited)
              Container(
                margin: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                padding: const EdgeInsetsDirectional.all(8),
                decoration: BoxDecoration(
                  color: demoBannerBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l.visualLimitedNote,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: demoBannerForeground),
                ),
              ),
            if (simulator != null)
              _DemoRejectToggle(
                armed: simulator.rejectNext,
                label: l.demoSimulateRejection,
                onChanged: _busy
                    ? null
                    : (v) => setState(() => simulator.rejectNext = v),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GalleryButton(
                    tooltip: l.pickFromGallery,
                    onPressed: _busy ? null : () => _pick(CaptureSource.gallery),
                  ),
                  _ShutterButton(
                    tooltip: l.capturePhoto,
                    onPressed: _busy || _cameraDenied ? null : () => _pick(CaptureSource.camera),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(AppLocalizations l, TextTheme text) {
    final white = text.bodyLarge?.copyWith(color: _white);
    if (_cameraDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, size: 64, color: _white),
              const SizedBox(height: 16),
              Text(l.cameraDenied, style: white, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(imageCaptureServiceProvider).openAppSettings(),
                child: Text(l.openSettings),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: _white),
                onPressed: () => _pick(CaptureSource.gallery),
                child: Text(l.pickFromGallery),
              ),
            ],
          ),
        ),
      );
    }
    final image = _image;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (image != null)
                  Image.memory(image, fit: BoxFit.cover, gaplessPlayback: true)
                else
                  ColoredBox(
                    color: Colors.white10,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final d = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) * 0.7;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: d,
                              height: d,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white70, width: 2),
                              ),
                            ),
                            PositionedDirectional(
                              top: 12,
                              start: 16,
                              end: 16,
                              child: Text(l.cameraGuide, style: white, textAlign: TextAlign.center),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (_busy)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(height: 16),
                        Text(_slow ? l.analyzingLong : l.analyzing, style: white, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: InkResponse(
            key: const Key('shutter'),
            onTap: onPressed,
            radius: 44,
            child: Opacity(
              opacity: onPressed == null ? 0.38 : 1,
              child: Container(
                width: 80,
                height: 80,
                padding: const EdgeInsetsDirectional.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
}

class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 56,
        child: IconButton.outlined(
          key: const Key('gallery'),
          tooltip: tooltip,
          color: Colors.white,
          style: IconButton.styleFrom(
            side: const BorderSide(color: Colors.white70),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: onPressed,
          icon: const Icon(Icons.photo_library_outlined),
        ),
      );
}

class _DemoRejectToggle extends StatelessWidget {
  const _DemoRejectToggle({required this.armed, required this.label, required this.onChanged});

  final bool armed;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        key: const Key('demo_reject'),
        style: TextButton.styleFrom(foregroundColor: demoBannerBackground),
        onPressed: onChanged == null ? null : () => onChanged!(!armed),
        icon: Icon(armed ? Icons.check_box : Icons.check_box_outline_blank, size: 20),
        label: Text(label),
      );
}
