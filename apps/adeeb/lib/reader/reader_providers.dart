import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/library_providers.dart';
import '../storage/reading_repository.dart';
import 'reader_book.dart';

/// أخطاء القراءة من القاعدة لا تُعاد تلقائياً: الواجهة تعرض «تعذّر فتح الكتاب».
Duration? _noRetry(int _, Object _) => null;

final readingRepositoryProvider = Provider<ReadingRepository>(
  (ref) => SqliteReadingRepository(
    '${ref.watch(storageDirectoryProvider).path}/adeeb.db',
  ),
);

/// يزيد عند أي تغيير في المفضلة أو آخر موضع أو الكتب المحمّلة، فتُعاد قراءة
/// ما يعتمد عليها (بطاقة «تابع القراءة»، تبويب المفضلة، صفحة الكتاب).
final readingRevisionProvider = NotifierProvider<ReadingRevision, int>(
  ReadingRevision.new,
);

class ReadingRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    if (ref.mounted) state++;
  }
}

/// يزيد عند تثبيت كتاب أو تحديثه أو حذفه فقط (لا مع كل حفظ للموضع)، حتى لا
/// يُعاد تحميل نص الكتاب أثناء القراءة.
final installRevisionProvider = NotifierProvider<ReadingRevision, int>(
  ReadingRevision.new,
);

/// نص الكتاب للقارئ (null إن لم يكن محمّلاً).
final readerBookProvider = FutureProvider.autoDispose
    .family<ReaderBook?, String>((ref, bookId) {
      ref.watch(installRevisionProvider);
      return ref.watch(readingRepositoryProvider).loadBook(bookId);
    }, retry: _noRetry);

final bookPositionProvider = FutureProvider.autoDispose
    .family<ReadingPosition?, String>((ref, bookId) {
      ref.watch(readingRevisionProvider);
      ref.watch(installRevisionProvider);
      return ref.watch(readingRepositoryProvider).position(bookId);
    }, retry: _noRetry);

final continueReadingProvider = FutureProvider.autoDispose<ReadingPosition?>((
  ref,
) {
  ref.watch(readingRevisionProvider);
  ref.watch(installRevisionProvider);
  return ref.watch(readingRepositoryProvider).latestPosition();
}, retry: _noRetry);

final favoritesProvider = FutureProvider.autoDispose<List<FavoriteItem>>((ref) {
  ref.watch(readingRevisionProvider);
  ref.watch(installRevisionProvider);
  return ref.watch(readingRepositoryProvider).favorites();
}, retry: _noRetry);

/// معرّفات فقرات المفضلة (لكل الكتب).
final favoriteIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final list = ref.watch(favoritesProvider).value ?? const [];
  return {for (final f in list) f.paragraphId};
});

/// إجراءات المفضلة والموضع: تكتب في القاعدة ثم تُحدّث ما يعتمد عليها.
final readingActionsProvider = Provider<ReadingActions>(
  (ref) => ReadingActions(ref),
);

class ReadingActions {
  ReadingActions(this._ref);
  final Ref _ref;

  ReadingRepository get _repo => _ref.read(readingRepositoryProvider);

  void _changed() {
    if (_ref.mounted) _ref.read(readingRevisionProvider.notifier).bump();
  }

  Future<void> savePosition(String bookId, String paragraphId) async {
    await _repo.savePosition(bookId, paragraphId);
    _changed();
  }

  Future<void> addFavorite(
    String bookId,
    String paragraphId, {
    int? createdAt,
  }) async {
    await _repo.addFavorite(bookId, paragraphId, createdAt: createdAt);
    _changed();
  }

  Future<void> removeFavorite(String paragraphId) async {
    await _repo.removeFavorite(paragraphId);
    _changed();
  }
}
