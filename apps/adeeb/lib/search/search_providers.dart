import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/library_providers.dart';
import '../reader/reader_providers.dart';
import '../storage/book_repository.dart';
import '../storage/search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SqliteSearchRepository(
    '${ref.watch(storageDirectoryProvider).path}/adeeb.db',
  ),
);

/// الكتب المحمّلة لشرائح نطاق البحث؛ تُعاد قراءتها عند تثبيت كتاب أو حذفه.
final searchableBooksProvider = FutureProvider.autoDispose<List<InstalledBook>>(
  (ref) {
    ref.watch(installRevisionProvider);
    return ref.watch(bookRepositoryProvider).installed();
  },
);
