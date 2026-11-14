import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/geo/geo_point.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../trips/widgets/route_map.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../l10n/app_localizations.dart';
import 'gallery_save_controller.dart';
import '../home/widgets/controls.dart';

class TripSummaryData {
  const TripSummaryData(this.trip, this.points);
  final TripRow trip;
  final List<GeoPoint> points;
}

final tripSummaryProvider = FutureProvider.autoDispose
    .family<TripSummaryData?, String>((ref, id) async {
      final repo = ref.watch(tripRepositoryProvider);
      final trip = await repo.getTrip(id);
      if (trip == null) return null;
      return TripSummaryData(trip, await repo.getPoints(id));
    });

/// شاشة الملخص بعد الإيقاف (DESIGN 7.5): المدة والمسافة والمسار ومتابعة.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.tripId, this.reason});
  final String tripId;
  final String? reason;

  String _interruptText(AppLocalizations l) => switch (reason) {
    'background' => l.summaryInterruptedBackground,
    'cameraError' => l.summaryInterruptedCamera,
    'writeError' => l.summaryInterruptedWrite,
    'lowStorage' => l.summaryInterruptedStorage,
    'dbError' => l.summaryDbError,
    _ => l.summaryInterruptedOther,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(tripSummaryProvider(tripId));
    return Scaffold(
      body: SafeArea(
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _Failure(text: l.summaryLoadError),
          data: (d) {
            if (d == null) return _Failure(text: l.summaryLoadError);
            final t = d.trip;
            final interrupted = t.status == TripStatus.interrupted;
            final gallery = ref.watch(gallerySaveProvider(tripId));
            final String? note = t.videoPath == null
                ? (reason == 'dbError'
                      ? _interruptText(l)
                      : l.summaryVideoFailed)
                : (interrupted || reason == 'dbError')
                ? _interruptText(l)
                : null;
            final galleryFailed = gallery == GallerySaveStatus.failed;
            final warn = t.videoPath == null || interrupted || galleryFailed;
            final th = Theme.of(context).textTheme;
            final map = RouteMap(points: d.points);
            final panel = Directionality(
              textDirection: Directionality.of(context),
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          warn ? Icons.warning_amber : Icons.check_circle,
                          color: warn ? AppColors.warning : AppColors.emerald,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l.summarySaved, style: th.titleLarge),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${l.summaryDuration}: ${TopBar.formatElapsed(Duration(seconds: t.durationSec))}',
                      key: const ValueKey('summary-duration'),
                      style: th.titleMedium,
                    ),
                    Text(
                      '${l.summaryDistance}: ${l.hudDistanceKm((t.distanceM / 1000).toStringAsFixed(2))}',
                      key: const ValueKey('summary-distance'),
                      style: th.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (note != null)
                      Text(
                        note,
                        key: const ValueKey('summary-note'),
                        style: th.bodyMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    if (gallery != GallerySaveStatus.none) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (gallery == GallerySaveStatus.saving)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          if (gallery == GallerySaveStatus.saving)
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              switch (gallery) {
                                GallerySaveStatus.saved =>
                                  l.summaryGallerySaved,
                                GallerySaveStatus.failed =>
                                  l.summaryGalleryFailed,
                                _ => l.summaryGallerySaving,
                              },
                              key: const ValueKey('summary-gallery'),
                              style: th.bodyMedium?.copyWith(
                                color: galleryFailed ? AppColors.warning : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (galleryFailed)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(top: 8),
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              key: const ValueKey('summary-gallery-retry'),
                              onPressed: () => ref
                                  .read(gallerySaveProvider(tripId).notifier)
                                  .retry(),
                              child: Text(l.summaryGalleryRetry),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        key: const ValueKey('summary-new-trip'),
                        onPressed: () => context.go(AppRoutes.record),
                        child: Text(l.summaryNewTrip),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        key: const ValueKey('summary-view-trip'),
                        onPressed: () => context.go(AppRoutes.tripFor(tripId)),
                        child: Text(l.summaryViewTrip),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        key: const ValueKey('summary-my-trips'),
                        onPressed: () => context.go(AppRoutes.home),
                        child: Text(l.tripsTitle),
                      ),
                    ),
                  ],
                ),
              ),
            );
            // طولي (الافتراضي): الخريطة أعلى واللوحة أسفلها. عريض: جنباً إلى جنب.
            return LayoutBuilder(
              builder: (context, c) => c.maxWidth > c.maxHeight
                  ? Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        Expanded(flex: 3, child: map),
                        Expanded(flex: 2, child: panel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 2, child: map),
                        Expanded(flex: 3, child: panel),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, key: const ValueKey('summary-error')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text(AppLocalizations.of(context).backToHome),
        ),
      ],
    ),
  );
}
