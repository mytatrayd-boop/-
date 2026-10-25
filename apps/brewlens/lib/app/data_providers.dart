import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../domain/models/analysis_result.dart';
import '../domain/models/coffee_type.dart';
import '../domain/models/review.dart';
import '../domain/models/shop.dart';
import 'providers.dart';

/// نتيجة تحليل لم تُحفظ بعد: تبقى في الذاكرة حتى «حفظ» (ARCHITECTURE §6).
class PendingAnalysis {
  const PendingAnalysis({required this.imageBytes, required this.type, required this.result});

  final Uint8List imageBytes;
  final CoffeeType type;
  final AnalysisResult result;
}

class PendingAnalysisNotifier extends Notifier<PendingAnalysis?> {
  @override
  PendingAnalysis? build() => null;

  void set(PendingAnalysis? value) => state = value;
}

final pendingAnalysisProvider =
    NotifierProvider<PendingAnalysisNotifier, PendingAnalysis?>(PendingAnalysisNotifier.new);

/// آخر نوع مشروب مختار (DESIGN §3.5: يُحفظ آخر اختيار).
class LastCoffeeTypeNotifier extends Notifier<CoffeeType> {
  static const key = 'last_coffee_type';

  @override
  CoffeeType build() {
    final wire = ref.watch(sharedPreferencesProvider).getString(key);
    try {
      return wire == null ? CoffeeType.espresso : CoffeeType.fromWire(wire);
    } on FormatException {
      return CoffeeType.espresso;
    }
  }

  Future<void> set(CoffeeType type) async {
    state = type;
    await ref.read(sharedPreferencesProvider).setString(key, type.wire);
  }
}

final lastCoffeeTypeProvider =
    NotifierProvider<LastCoffeeTypeNotifier, CoffeeType>(LastCoffeeTypeNotifier.new);

/// كل مقاهي المستخدم مع المفضلة والمتوسطات.
final shopsProvider = FutureProvider<List<Shop>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(shopsRepositoryProvider).list();
});

final favoritesProvider = FutureProvider<List<Shop>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(shopsRepositoryProvider).favorites();
});

/// آخر 5 تقييمات للرئيسية.
final recentReviewsProvider = FutureProvider<List<Review>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(reviewsRepositoryProvider).list(limit: 5);
});

final reviewProvider = FutureProvider.family<Review, String>((ref, id) {
  return ref.watch(reviewsRepositoryProvider).get(id);
});

/// بايتات صورة تقييم (المفتاح: المسار).
final reviewImageProvider = FutureProvider.family<Uint8List, Review>((ref, review) {
  return ref.watch(reviewsRepositoryProvider).imageBytes(review);
}, isAutoDispose: true);

/// صفحة السجل: دفعات 20 (SPEC F7 معيار 2).
class HistoryState {
  const HistoryState({required this.items, required this.hasMore, this.loadingMore = false});

  final List<Review> items;
  final bool hasMore;
  final bool loadingMore;
}

class HistoryNotifier extends AsyncNotifier<HistoryState> {
  static const pageSize = 20;

  @override
  Future<HistoryState> build() async {
    ref.watch(sessionProvider);
    final page = await ref.watch(reviewsRepositoryProvider).list(limit: pageSize);
    return HistoryState(items: page, hasMore: page.length == pageSize);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(HistoryState(items: current.items, hasMore: true, loadingMore: true));
    final page = await ref
        .read(reviewsRepositoryProvider)
        .list(offset: current.items.length, limit: pageSize);
    if (!ref.mounted) return;
    state = AsyncData(HistoryState(
      items: [...current.items, ...page],
      hasMore: page.length == pageSize,
    ));
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);

/// بعد أي حفظ/تعديل/حذف: إعادة جلب القوائم والعدّاد.
/// [keepReviewDetails]: بعد حذف تقييم لا يُعاد جلب تفاصيله (كان يظهر خطأ لحظي
/// أثناء إغلاق الشاشة).
void refreshCollections(Ref ref) => _invalidateAll(ref.invalidate);

void refreshCollectionsFromWidget(WidgetRef ref, {bool keepReviewDetails = false}) =>
    _invalidateAll(ref.invalidate, keepReviewDetails: keepReviewDetails);

void _invalidateAll(void Function(ProviderOrFamily) invalidate, {bool keepReviewDetails = false}) {
  invalidate(historyProvider);
  invalidate(recentReviewsProvider);
  invalidate(shopsProvider);
  invalidate(favoritesProvider);
  if (!keepReviewDetails) invalidate(reviewProvider);
  invalidate(usageProvider);
}
