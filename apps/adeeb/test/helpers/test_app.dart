import 'dart:io';

import 'package:adeeb/app.dart';
import 'package:adeeb/core/app_config.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/library/library_providers.dart';
import 'package:adeeb/reader/passage_share.dart';
import 'package:adeeb/reader/reader_providers.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:adeeb/storage/reading_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'library_fixtures.dart';

/// بيئة اختبار: مجلد مؤقت حقيقي، وSQLite حقيقي في الـ isolate نفسه، وخادم وهمي.
class TestEnv {
  /// [resetPreferences] = false يحاكي إعادة تشغيل التطبيق مع بقاء الإعدادات.
  TestEnv({bool resetPreferences = true})
    : dir = Directory.systemTemp.createTempSync('adeeb_widget_') {
    if (resetPreferences) SharedPreferences.setMockInitialValues({});
  }

  final Directory dir;
  final server = FakeLibraryServer();

  /// ما أُرسل إلى قائمة المشاركة (بدل share_plus في الاختبار).
  final shared = <(String, String)>[];

  SqliteBookRepository get books =>
      SqliteBookRepository('${dir.path}/adeeb.db', useIsolate: false);

  SqliteReadingRepository get reading =>
      SqliteReadingRepository('${dir.path}/adeeb.db', useIsolate: false);

  List<Override> overrides({
    Locale locale = const Locale('ar'),
    BookRepository? books,
  }) => [
    storageDirectoryProvider.overrideWithValue(dir),
    appConfigProvider.overrideWithValue(
      const AppConfig(libraryBaseUrl: testBaseUrl),
    ),
    httpClientProvider.overrideWithValue(server.client()),
    bookRepositoryProvider.overrideWithValue(books ?? this.books),
    readingRepositoryProvider.overrideWithValue(reading),
    shareTextProvider.overrideWithValue(
      (text, subject) async => shared.add((text, subject)),
    ),
    appLocaleProvider.overrideWithValue(locale),
  ];

  ProviderContainer container() => ProviderContainer(overrides: overrides());

  Widget app({Locale locale = const Locale('ar')}) => ProviderScope(
    overrides: overrides(locale: locale),
    child: const AdeebApp(),
  );

  /// يثبّت كتاباً مباشرة في القاعدة (كأنه حُمّل سابقاً).
  Future<void> preinstall(Map<String, Object?> book) {
    final gz = gzJson(book);
    final entry = parseCatalog(catalogJson([catalogEntry(book, gz)]))
        .books
        .single;
    return books.install(gz, entry);
  }

  void dispose() => dir.deleteSync(recursive: true);
}
