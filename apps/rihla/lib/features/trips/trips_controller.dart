import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/repositories/trip_repository.dart';

/// كل الرحلات، الأحدث أولاً (تتحدث تلقائياً مع القاعدة).
final tripsProvider = StreamProvider.autoDispose<List<TripRow>>(
  (ref) => ref.watch(tripRepositoryProvider).watchTrips(),
);
