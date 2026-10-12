import 'dart:io';

import 'package:adeeb/app.dart';
import 'package:adeeb/ask/ask_providers.dart';
import 'package:adeeb/audio/listening_providers.dart';
import 'package:adeeb/core/app_config.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/library/library_providers.dart';
import 'package:adeeb/reader/passage_share.dart';
import 'package:adeeb/reader/reader_book.dart';
import 'package:adeeb/reader/reader_providers.dart';
import 'package:adeeb/search/search_providers.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:adeeb/storage/passage_retriever.dart';
import 'package:adeeb/storage/reading_repository.dart';
import 'package:adeeb/storage/search_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_ask_server.dart';
import 'fake_audio.dart';
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

  /// خادم «اسأل الأديب» الوهمي.
  final ask = FakeAskServer();

  /// عند true تفشل كتابات المفضلة (محاكاة قاعدة مشغولة أو تالفة).
  bool failFavoriteWrites = false;

  /// عند true يفشل حفظ الموضع.
  bool failPositionWrites = false;

  /// محرك النطق وجلسة الوسائط المُحاكيان (لا صوت فعلي ولا إشعار في الاختبار).
  final tts = FakeTtsEngine();
  final media = FakeMediaSession();

  /// ما أُرسل إلى قائمة المشاركة (بدل share_plus في الاختبار).
  final shared = <(String, String)>[];

  SqliteBookRepository get books =>
      SqliteBookRepository('${dir.path}/adeeb.db', useIsolate: false);

  SqliteReadingRepository get reading =>
      SqliteReadingRepository('${dir.path}/adeeb.db', useIsolate: false);

  /// بديل لمستودع البحث (مثلاً لمحاكاة خطأ)؛ وإلا SQLite الحقيقي.
  SearchRepository? searchOverride;

  SearchRepository get search =>
      searchOverride ??
      SqliteSearchRepository('${dir.path}/adeeb.db', useIsolate: false);

  List<Override> overrides({
    Locale locale = const Locale('ar'),
    BookRepository? books,
  }) => [
    storageDirectoryProvider.overrideWithValue(dir),
    appConfigProvider.overrideWithValue(
      const AppConfig(
        libraryBaseUrl: testBaseUrl,
        askApiBaseUrl: testAskBaseUrl,
      ),
    ),
    askHttpClientProvider.overrideWithValue(ask.client()),
    passageRetrieverProvider.overrideWithValue(
      SqlitePassageRetriever('${dir.path}/adeeb.db', useIsolate: false),
    ),
    httpClientProvider.overrideWithValue(server.client()),
    bookRepositoryProvider.overrideWithValue(books ?? this.books),
    searchRepositoryProvider.overrideWithValue(search),
    readingRepositoryProvider.overrideWithValue(
      FlakyReadingRepository(
        reading,
        () => failFavoriteWrites,
        () => failPositionWrites,
      ),
    ),
    shareTextProvider.overrideWithValue(
      (text, subject) async => shared.add((text, subject)),
    ),
    appLocaleProvider.overrideWithValue(locale),
    ttsEngineProvider.overrideWithValue(tts),
    mediaSessionProvider.overrideWithValue(media),
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

/// يمرّر كل شيء إلى المستودع الحقيقي، ويُفشل كتابات المفضلة عند الطلب.
class FlakyReadingRepository implements ReadingRepository {
  FlakyReadingRepository(this._inner, this._fail, this._failPosition);

  final ReadingRepository _inner;
  final bool Function() _fail;
  final bool Function() _failPosition;

  void _check() {
    if (_fail()) throw const FileSystemException('محاكاة فشل الكتابة');
  }

  @override
  Future<ReaderBook?> loadBook(String bookId) => _inner.loadBook(bookId);

  @override
  Future<String> resolveParagraph(String paragraphId) =>
      _inner.resolveParagraph(paragraphId);

  @override
  Future<void> savePosition(String bookId, String paragraphId) async {
    if (_failPosition()) throw const FileSystemException('محاكاة فشل الكتابة');
    return _inner.savePosition(bookId, paragraphId);
  }

  @override
  Future<ReadingPosition?> position(String bookId) => _inner.position(bookId);

  @override
  Future<ReadingPosition?> latestPosition() => _inner.latestPosition();

  @override
  Future<List<FavoriteItem>> favorites() => _inner.favorites();

  @override
  Future<void> addFavorite(
    String bookId,
    String paragraphId, {
    int? createdAt,
  }) async {
    _check();
    return _inner.addFavorite(bookId, paragraphId, createdAt: createdAt);
  }

  @override
  Future<void> removeFavorite(String paragraphId) async {
    _check();
    return _inner.removeFavorite(paragraphId);
  }
}
