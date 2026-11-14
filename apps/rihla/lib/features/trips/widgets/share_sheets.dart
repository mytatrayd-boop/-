import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/geo/geo_point.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/share/share_service.dart';
import '../../../l10n/app_localizations.dart';
import '../trip_share.dart';

final tripSharerProvider = Provider<TripSharer>(
  (ref) => TripSharer(ref.watch(shareServiceProvider)),
);

String shareOutcomeMessage(AppLocalizations l, ShareOutcome o) => switch (o) {
  ShareOutcome.ok => '',
  ShareOutcome.noRoute => l.shareNoRoute,
  ShareOutcome.noVideo => l.shareVideoMissing,
  ShareOutcome.failed => l.shareFailed,
  ShareOutcome.openFailed => l.openMapsFailed,
};

/// الورقة الأولى (DESIGN 7.6): «إرسال الفيديو» و«إرسال مساري على الخريطة».
Future<void> showShareSheet(
  BuildContext context, {
  required String? videoPath,
  required List<GeoPoint> points,
  required DateTime startedAt,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _ShareSheet(videoPath: videoPath, points: points, startedAt: startedAt),
);

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({
    required this.videoPath,
    required this.points,
    required this.startedAt,
  });
  final String? videoPath;
  final List<GeoPoint> points;
  final DateTime startedAt;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  bool _busy = false;
  late final Future<bool> _videoExists = widget.videoPath == null
      ? Future.value(false)
      : ref.read(shareServiceProvider).fileExists(widget.videoPath!);

  Future<void> _sendVideo(AppLocalizations l) async {
    final sharer = ref.read(tripSharerProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await sharer.shareVideo(widget.videoPath);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != ShareOutcome.ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(shareOutcomeMessage(l, r))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.shareTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: _videoExists,
              builder: (_, snap) {
                final has = snap.data ?? false;
                return _OptionCard(
                  key: const ValueKey('share-video'),
                  icon: Icons.videocam,
                  title: l.shareVideoTitle,
                  subtitle: has ? l.shareVideoDesc : l.shareVideoMissing,
                  footnote: has ? l.shareVideoWarning : null,
                  busy: _busy,
                  onTap: has && !_busy ? () => _sendVideo(l) : null,
                );
              },
            ),
            const SizedBox(height: 12),
            _OptionCard(
              key: const ValueKey('share-route'),
              icon: Icons.route,
              title: l.shareRouteTitle,
              subtitle: l.shareRouteDesc,
              onTap: () => showRouteShareSheet(
                context,
                points: widget.points,
                startedAt: widget.startedAt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.footnote,
    this.busy = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String? footnote;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                busy
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Icon(
                        icon,
                        size: 32,
                        color: onTap == null
                            ? AppColors.textSecondary
                            : AppColors.amber,
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: th.titleMedium),
                      Text(subtitle, style: th.bodyMedium),
                      if (footnote != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            footnote!,
                            key: const ValueKey('share-video-warning'),
                            style: th.bodySmall?.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
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

/// الورقة الفرعية: رابط خرائط جوجل (مشاركة نصاً + فتح) وملف GPX.
Future<void> showRouteShareSheet(
  BuildContext context, {
  required List<GeoPoint> points,
  required DateTime startedAt,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _RouteShareSheet(points: points, startedAt: startedAt),
);

class _RouteShareSheet extends ConsumerStatefulWidget {
  const _RouteShareSheet({required this.points, required this.startedAt});
  final List<GeoPoint> points;
  final DateTime startedAt;

  @override
  ConsumerState<_RouteShareSheet> createState() => _RouteShareSheetState();
}

class _RouteShareSheetState extends ConsumerState<_RouteShareSheet> {
  bool _busy = false;

  Future<void> _run(
    AppLocalizations l,
    Future<ShareOutcome> Function(TripSharer s) action,
  ) async {
    final sharer = ref.read(tripSharerProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final r = await action(sharer);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != ShareOutcome.ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(shareOutcomeMessage(l, r))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final th = Theme.of(context).textTheme;
    final hasRoute = widget.points.where((p) => p.isValid).isNotEmpty;
    final name =
        'rihla-${widget.startedAt.toUtc().toIso8601String().substring(0, 10)}';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.shareRouteTitle, style: th.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.shareLinkTitle, style: th.titleMedium),
                    Text(l.shareLinkNote, style: th.bodySmall),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        key: const ValueKey('share-link-share'),
                        onPressed: hasRoute && !_busy
                            ? () => _run(
                                l,
                                (s) => s.shareLink(
                                  widget.points,
                                  (u) => l.shareLinkMessage(u),
                                ),
                              )
                            : null,
                        child: Text(l.shareLinkShare),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        key: const ValueKey('share-link-open'),
                        onPressed: hasRoute && !_busy
                            ? () => _run(l, (s) => s.openInMaps(widget.points))
                            : null,
                        child: Text(l.shareLinkOpen),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.shareGpxTitle, style: th.titleMedium),
                    Text(l.shareGpxDesc, style: th.bodySmall),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        key: const ValueKey('share-gpx'),
                        onPressed: hasRoute && !_busy
                            ? () => _run(
                                l,
                                (s) => s.shareGpx(
                                  widget.points,
                                  name: name,
                                  time: widget.startedAt,
                                ),
                              )
                            : null,
                        child: Text(l.shareGpxShare),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
