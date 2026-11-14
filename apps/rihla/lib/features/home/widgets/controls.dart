import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../home_controller.dart';

const _overlay = Color(0xD9182026); // surface1 بشفافية 85%

/// شريط علوي رفيع: الإعدادات (قبل البدء)، مؤشر التسجيل + المؤقت، المسافة،
/// حالة GPS، كتم.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.state, required this.onSettings});
  final HomeState state;
  final VoidCallback onSettings;

  static String formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60)),
        s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme.bodyMedium;
    final gps = state.fix == null
        ? (l.gpsSearching, AppColors.textSecondary)
        : state.weakGps
        ? (l.gpsWeak, AppColors.warning)
        : (l.gpsGood, AppColors.emerald);
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: _overlay,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
          if (!state.recording)
            IconButton(
              key: const ValueKey('open-settings'),
              tooltip: l.settingsTitle,
              icon: const Icon(Icons.settings_outlined),
              onPressed: onSettings,
            ),
          if (state.recording)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: const ValueKey('rec-dot'),
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.recordRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatElapsed(state.elapsed),
                  key: const ValueKey('rec-timer'),
                  style: t,
                ),
              ],
            ),
          Text(
            l.hudDistanceKm((state.distanceM / 1000).toStringAsFixed(2)),
            key: const ValueKey('hud-distance'),
            style: t,
          ),
          Text(
            gps.$1,
            key: const ValueKey('hud-gps'),
            style: t?.copyWith(color: gps.$2),
          ),
          if (state.muted)
            Text(l.audioMutedChip, key: const ValueKey('hud-muted'), style: t),
        ],
      ),
    );
  }
}

/// نصف الكاميرا: المعاينة، أو الحالة (تحضير/خطأ)، ورسالة سبب تعطيل البدء.
class CameraHalf extends StatelessWidget {
  const CameraHalf({
    super.key,
    required this.status,
    required this.preview,
    required this.blocker,
    required this.canStart,
    required this.recording,
    required this.onRetryCamera,
    required this.onOpenPermissions,
  });

  final CameraStatus status;
  final Widget? preview;
  final StartBlocker? blocker;
  final bool canStart;
  final bool recording;
  final VoidCallback onRetryCamera;
  final VoidCallback onOpenPermissions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final reason = recording
        ? null
        : switch (blocker) {
            StartBlocker.permissions => l.permStartBlocked,
            StartBlocker.cameraOpening => l.cameraOpening,
            StartBlocker.cameraError => l.cameraError,
            StartBlocker.waitingGps => l.mapLocating,
            null => null,
          };
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: AppColors.surface1,
          child: preview ?? const SizedBox.expand(),
        ),
        if (reason != null)
          Align(
            alignment: Alignment.bottomCenter,
            // مساحة لشريط التحكم على الحافة اليمنى.
            child: Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 16 + 88 + 16,
                top: 64, // تحت الشريط العلوي
                bottom: 12,
              ),
              child: Container(
                key: const ValueKey('start-blocker'),
                padding: const EdgeInsetsDirectional.all(12),
                decoration: BoxDecoration(
                  color: _overlay,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reason,
                        style: t.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (blocker == StartBlocker.cameraError)
                        TextButton(
                          key: const ValueKey('camera-retry'),
                          onPressed: onRetryCamera,
                          child: Text(l.permRetry),
                        ),
                      if (blocker == StartBlocker.permissions)
                        TextButton(
                          key: const ValueKey('open-permissions'),
                          onPressed: onOpenPermissions,
                          child: Text(l.homeOpenPermissions),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// شريط التحكم العمودي: بدء/إيقاف 88dp، كتم 64dp، جودة 64dp، مسافات 16dp.
class ControlStrip extends StatelessWidget {
  const ControlStrip({
    super.key,
    required this.recording,
    required this.canStart,
    required this.muted,
    required this.quality,
    required this.onStartStop,
    required this.onToggleMute,
    required this.onQuality,
  });

  final bool recording;
  final bool canStart;
  final bool muted;
  final VideoQuality quality;
  final VoidCallback onStartStop;
  final VoidCallback onToggleMute;
  final ValueChanged<VideoQuality> onQuality;

  static String qualityLabel(VideoQuality q) =>
      q == VideoQuality.p720 ? '720p' : '1080p';

  Future<void> _pickQuality(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final q = await showModalBottomSheet<VideoQuality>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Text(
                l.qualityTitle,
                style: Theme.of(c).textTheme.titleMedium,
              ),
            ),
            for (final v in VideoQuality.values)
              ListTile(
                key: ValueKey('quality-${v.name}'),
                minTileHeight: 64,
                title: Text(qualityLabel(v)),
                trailing: v == quality ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(c).pop(v),
              ),
          ],
        ),
      ),
    );
    if (q != null) onQuality(q);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final startEnabled = recording || canStart;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: startEnabled,
          label: recording ? l.stopTrip : l.startTrip,
          child: Opacity(
            opacity: startEnabled ? 1 : 0.4,
            child: GestureDetector(
              key: ValueKey(recording ? 'stop-button' : 'start-button'),
              onTap: startEnabled ? onStartStop : null,
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.recordRed,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: recording
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: ColoredBox(color: Colors.white),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _BigButton(
          key: const ValueKey('mute-button'),
          semanticLabel: muted ? l.unmute : l.mute,
          icon: muted ? Icons.mic_off : Icons.mic,
          caption: muted ? l.audioMuted : l.audioOn,
          onTap: onToggleMute,
        ),
        const SizedBox(height: 16),
        _BigButton(
          key: const ValueKey('quality-button'),
          semanticLabel: l.qualityTitle,
          icon: Icons.high_quality_outlined,
          caption: qualityLabel(quality),
          onTap: recording ? null : () => _pickQuality(context),
        ),
      ],
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.caption,
    required this.onTap,
  });
  final String semanticLabel;
  final IconData icon;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: semanticLabel,
    child: Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: _overlay,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 64,
            height: 64,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        caption,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('offline-banner'),
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.warning,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.ink),
    ),
  );
}
