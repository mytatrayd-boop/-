import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/scan.dart';

/// null = الكل.
class HistoryFilter extends Notifier<ScanType?> {
  @override
  ScanType? build() => null;

  void set(ScanType? type) => state = type;
}

final historyFilterProvider = NotifierProvider<HistoryFilter, ScanType?>(HistoryFilter.new);

final historyScansProvider = StreamProvider.autoDispose<List<Scan>>((ref) {
  final type = ref.watch(historyFilterProvider);
  return ref.watch(scanRepositoryProvider).watchAll(type: type);
});

final scanDetailProvider = StreamProvider.autoDispose.family<Scan?, int>(
  (ref, id) => ref.watch(scanRepositoryProvider).watchById(id),
);

/// مرشح تبويب المفضلة (مستقل عن مرشح السجل). null = الكل.
class FavoritesFilter extends Notifier<ScanType?> {
  @override
  ScanType? build() => null;

  void set(ScanType? type) => state = type;
}

final favoritesFilterProvider =
    NotifierProvider<FavoritesFilter, ScanType?>(FavoritesFilter.new);

final favoriteScansProvider = StreamProvider.autoDispose<List<Scan>>((ref) {
  final type = ref.watch(favoritesFilterProvider);
  return ref.watch(scanRepositoryProvider).watchAll(type: type, favoritesOnly: true);
});
