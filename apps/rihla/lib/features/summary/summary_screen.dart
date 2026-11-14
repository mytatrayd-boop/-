import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/geo/geo_point.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/trip_repository.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_controller.dart';
import '../home/widgets/controls.dart';
import '../home/widgets/recording_map.dart';

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
/// المشاركة وعرض الرحلة تأتي في F8/F9، فزر "عرض الرحلة" معطّل الآن.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.tripId, this.reason});
  final String tripId;
  final String? reason;

  String _interruptText(AppLocalizations l) => switch (reason) {
    'background' => l.summaryInterruptedBackground,
    'cameraError' => l.summaryInterruptedCamera,
    'writeError' => l.summaryInterruptedWrite,
    'lowStorage' => l.summaryInterruptedStorage,
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
            final String note = t.videoPath == null
                ? l.summaryVideoFailed
                : interrupted
                ? _interruptText(l)
                : l.summaryVideoSaved;
            final warn = t.videoPath == null || interrupted;
            final th = Theme.of(context).textTheme;
            return Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  flex: 3,
                  child: _RouteMap(points: d.points),
                ),
                Expanded(
                  flex: 2,
                  child: Directionality(
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
                          Text(
                            note,
                            key: const ValueKey('summary-note'),
                            style: th.bodyMedium?.copyWith(
                              color: warn ? AppColors.warning : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton(
                              key: const ValueKey('summary-new-trip'),
                              onPressed: () => context.go(AppRoutes.home),
                              child: Text(l.summaryNewTrip),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              key: const ValueKey('summary-view-trip'),
                              // السجل وتفاصيل الرحلة في F8/F9.
                              onPressed: null,
                              child: Text(l.summaryViewTrip),
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _RouteMap extends ConsumerWidget {
  const _RouteMap({required this.points});
  final List<GeoPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ll = [for (final p in points) LatLng(p.lat, p.lng)];
    final fit = ll.length >= 2
        ? CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(ll),
            padding: const EdgeInsets.all(32),
            maxZoom: 17,
          )
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: ll.isEmpty ? const LatLng(0, 0) : ll.first,
            initialZoom: ll.isEmpty ? 2 : 16,
            initialCameraFit: fit,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            ref.watch(mapTilesProvider).buildLayer(context),
            if (ll.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: ll,
                    strokeWidth: 6,
                    color: AppColors.amber,
                    borderStrokeWidth: 2,
                    borderColor: AppColors.ink,
                  ),
                ],
              ),
            if (ll.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(point: ll.first, width: 20, height: 20, child: const _Dot(AppColors.emerald)),
                  if (ll.length >= 2)
                    Marker(point: ll.last, width: 20, height: 20, child: const _Dot(AppColors.recordRed)),
                ],
              ),
          ],
        ),
        const Positioned(right: 0, bottom: 0, child: MapAttribution()),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
  );
}
