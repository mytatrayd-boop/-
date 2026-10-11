import 'dart:io';

import 'package:adeeb/app.dart';
import 'package:adeeb/core/app_config.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/library/library_providers.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

import 'library_fixtures.dart';

/// بيئة اختبار: مجلد مؤقت حقيقي، وSQLite حقيقي في الـ isolate نفسه، وخادم وهمي.
class TestEnv {
  TestEnv() : dir = Directory.systemTemp.createTempSync('adeeb_widget_');

  final Directory dir;
  final server = FakeLibraryServer();

  SqliteBookRepository get books => SqliteBookRepository('${dir.path}/adeeb.db', useIsolate: false);

  List<Override> overrides({Locale locale = const Locale('ar'), BookRepository? books}) => [
        storageDirectoryProvider.overrideWithValue(dir),
        appConfigProvider.overrideWithValue(const AppConfig(libraryBaseUrl: testBaseUrl)),
        httpClientProvider.overrideWithValue(server.client()),
        bookRepositoryProvider.overrideWithValue(books ?? this.books),
        appLocaleProvider.overrideWithValue(locale),
      ];

  ProviderContainer container() => ProviderContainer(overrides: overrides());

  Widget app({Locale locale = const Locale('ar')}) =>
      ProviderScope(overrides: overrides(locale: locale), child: const AdeebApp());

  /// يثبّت كتاباً مباشرة في القاعدة (كأنه حُمّل سابقاً).
  Future<void> preinstall(Map<String, Object?> book) {
    final gz = gzJson(book);
    final entry = parseCatalog(catalogJson([catalogEntry(book, gz)])).books.single;
    return books.install(gz, entry);
  }

  void dispose() => dir.deleteSync(recursive: true);
}
