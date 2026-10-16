import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../settings/app_settings.dart';
import '../storage/book_repository.dart';
import '../storage/catalog_store.dart';
import 'book_downloader.dart';
import 'catalog_repository.dart';

/// لغة الواجهة الفعلية من الإعدادات (DESIGN §13.1). قبل قراءة الإعدادات
/// تُفترض «حسب الجهاز».
final appLocaleProvider = Provider<Locale>(
  (ref) => resolveAppLocale(
    ref.watch(appSettingsProvider).value?.language ?? AppLanguage.system,
    WidgetsBinding.instance.platformDispatcher.locale,
  ),
);

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// مجلد دعم التطبيق (قاعدة البيانات ونسخة الفهرس). يُحقن في main والاختبارات.
final storageDirectoryProvider = Provider<Directory>(
  (ref) =>
      throw UnimplementedError('storageDirectoryProvider must be overridden'),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(
    client: ref.watch(httpClientProvider),
    baseUri: ref.watch(appConfigProvider).libraryBaseUri,
    legacyCacheFile: File(
      '${ref.watch(storageDirectoryProvider).path}/catalog.json',
    ),
  ),
);

/// الفهرس المستورد في SQLite (§18.5).
final catalogStoreProvider = Provider<CatalogStore>(
  (ref) => SqliteCatalogStore(
    '${ref.watch(storageDirectoryProvider).path}/adeeb.db',
  ),
);

/// الساعة (قابلة للاستبدال في الاختبار) لتقليل جلب الفهرس.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final bookDownloaderProvider = Provider<BookDownloader>(
  (ref) => BookDownloader(ref.watch(httpClientProvider)),
);

final bookRepositoryProvider = Provider<BookRepository>(
  (ref) => SqliteBookRepository(
    '${ref.watch(storageDirectoryProvider).path}/adeeb.db',
  ),
);

/// أبواب كتاب محمّل لصفحة الكتاب.
final bookChaptersProvider = FutureProvider.autoDispose
    .family<List<ChapterInfo>, String>(
      (ref, bookId) => ref.watch(bookRepositoryProvider).chapters(bookId),
    );
