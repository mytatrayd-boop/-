import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/db/app_database.dart';
import '../../l10n/app_localizations.dart';
import 'trip_format.dart';
import 'trips_controller.dart';

/// «رحلاتي» (DESIGN 7.3): الشاشة الأولى، طولية. قائمة الرحلات وزر كبير لرحلة جديدة.
class TripsScreen extends ConsumerWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final trips = ref.watch(tripsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.tripsTitle),
        actions: [
          IconButton(
            key: const ValueKey('trips-settings'),
            tooltip: l.openSettings,
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: trips.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.tripsLoadError,
                        key: const ValueKey('trips-error'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const ValueKey('trips-retry'),
                        onPressed: () => ref.invalidate(tripsProvider),
                        child: Text(l.retry),
                      ),
                    ],
                  ),
                ),
                data: (list) => list.isEmpty
                    ? _Empty(l: l)
                    : ListView.separated(
                        key: const ValueKey('trips-list'),
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => TripCard(trip: list[i]),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton.icon(
                  key: const ValueKey('trips-new'),
                  onPressed: () => context.push(AppRoutes.record),
                  icon: const Icon(Icons.fiber_manual_record),
                  label: Text(l.tripsNew),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route, size: 72, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            l.tripsEmpty,
            key: const ValueKey('trips-empty'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(l.tripsEmptyHint, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip});
  final TripRow trip;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final th = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final status = switch (trip.status) {
      TripStatus.completed => l.tripStatusCompleted,
      TripStatus.interrupted => l.tripStatusInterrupted,
      TripStatus.recording => l.tripStatusRecording,
    };
    final ok = trip.status == TripStatus.completed;
    return Card(
      key: ValueKey('trip-card-${trip.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.tripFor(trip.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatTripDate(locale, trip.startedAt),
                style: th.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.straighten, size: 18),
                  const SizedBox(width: 4),
                  Text(formatTripDistance(l, trip.distanceM)),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text(formatTripDuration(trip.durationSec)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(status),
                    avatar: Icon(
                      ok ? Icons.check_circle : Icons.warning_amber,
                      size: 18,
                      color: ok ? AppColors.emerald : AppColors.warning,
                    ),
                  ),
                  if (trip.videoPath == null)
                    Chip(label: Text(l.tripNoVideoChip)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
