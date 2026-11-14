import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/share/share_service.dart';
import '../../l10n/app_localizations.dart';
import '../summary/summary_screen.dart' show tripSummaryProvider;
import 'trip_format.dart';
import 'trip_share.dart';
import 'widgets/route_map.dart';
import 'widgets/share_sheets.dart';

/// هل ملف فيديو الرحلة ما زال على الجوال.
final tripVideoExistsProvider = FutureProvider.autoDispose
    .family<bool, String?>((ref, path) async {
      if (path == null) return false;
      return ref.watch(shareServiceProvider).fileExists(path);
    });

/// تفاصيل الرحلة (DESIGN 7.4): المسار على الخريطة، المدة والمسافة والتاريخ،
/// تشغيل الفيديو، مشاركة، حذف بتأكيد.
class TripDetailsScreen extends ConsumerWidget {
  const TripDetailsScreen({super.key, required this.tripId});
  final String tripId;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(AppRoutes.home);

  Future<void> _play(BuildContext context, WidgetRef ref, TripRow t) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final r = await ref.read(tripSharerProvider).playVideo(t.videoPath);
    if (r != ShareOutcome.ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            r == ShareOutcome.noVideo ? l.tripVideoMissing : l.tripPlayFailed,
          ),
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(tripRepositoryProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('delete-dialog'),
        title: Text(l.tripDeleteTitle),
        content: Text(l.tripDeleteBody),
        actions: [
          TextButton(
            key: const ValueKey('delete-cancel'),
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.recordRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.tripDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.deleteTrip(tripId);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.tripDeleteFailed)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l.tripDeleted)));
    if (context.mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(tripSummaryProvider(tripId));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('trip-back'),
          icon: const BackButtonIcon(),
          onPressed: () => _back(context),
        ),
        title: Text(l.tripDetailsTitle),
      ),
      body: SafeArea(
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Failure(l: l, onBack: () => _back(context)),
          data: (d) {
            if (d == null) return _Failure(l: l, onBack: () => _back(context));
            final t = d.trip;
            final th = Theme.of(context).textTheme;
            final locale = Localizations.localeOf(context).toString();
            final hasVideo =
                ref.watch(tripVideoExistsProvider(t.videoPath)).value ?? false;
            final mapHeight = MediaQuery.sizeOf(context).height * 0.4;
            return ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                SizedBox(
                  height: mapHeight < 240 ? 240 : mapHeight,
                  child: d.points.isEmpty
                      ? Center(
                          child: Text(
                            l.tripNoRoute,
                            key: const ValueKey('trip-no-route'),
                          ),
                        )
                      : RouteMap(points: d.points),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l.tripDate}: ${formatTripDate(locale, t.startedAt)}',
                        key: const ValueKey('trip-date'),
                        style: th.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${l.summaryDuration}: ${formatTripDuration(t.durationSec)}',
                        key: const ValueKey('trip-duration'),
                        style: th.titleMedium,
                      ),
                      Text(
                        '${l.summaryDistance}: ${formatTripDistance(l, t.distanceM)}',
                        key: const ValueKey('trip-distance'),
                        style: th.titleMedium,
                      ),
                      if (t.status == TripStatus.interrupted)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            l.tripStatusInterrupted,
                            style: th.bodyMedium?.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (hasVideo)
                        SizedBox(
                          height: 56,
                          child: FilledButton.icon(
                            key: const ValueKey('trip-play'),
                            onPressed: () => _play(context, ref, t),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l.tripPlayVideo),
                          ),
                        )
                      else
                        Text(
                          l.tripVideoMissing,
                          key: const ValueKey('trip-video-missing'),
                          style: th.bodyMedium?.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          key: const ValueKey('trip-share'),
                          onPressed: () => showShareSheet(
                            context,
                            videoPath: t.videoPath,
                            points: d.points,
                            startedAt: t.startedAt,
                          ),
                          icon: const Icon(Icons.share),
                          label: Text(l.tripShare),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 56,
                        child: TextButton.icon(
                          key: const ValueKey('trip-delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.recordRed,
                          ),
                          onPressed: () => _delete(context, ref),
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l.tripDelete),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.l, required this.onBack});
  final AppLocalizations l;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l.summaryLoadError, key: const ValueKey('trip-error')),
        const SizedBox(height: 12),
        FilledButton(onPressed: onBack, child: Text(l.backToHome)),
      ],
    ),
  );
}
