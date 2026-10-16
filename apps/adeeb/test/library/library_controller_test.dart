import 'dart:async';

import 'package:adeeb/library/library_controller.dart';
import 'package:adeeb/library/library_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:flutter/foundation.dart';

import '../helpers/library_fixtures.dart';
import '../helpers/test_app.dart';

void main() {
  late TestEnv env;
  late ProviderContainer container;

  setUp(() {
    env = TestEnv();
    env.server.catalog = catalogJson([env.server.addBook(miniBook())]);
  });
  tearDown(() {
    container.dispose();
    env.dispose();
  });

  Future<LibraryState> load() async {
    container = env.container();
    container.read(libraryControllerProvider);
    await container.read(libraryControllerProvider.notifier).refresh();
    return container.read(libraryControllerProvider);
  }

  LibraryController controller() =>
      container.read(libraryControllerProvider.notifier);
  LibraryState state() => container.read(libraryControllerProvider);

  test('يعرض كتب الفهرس غير محمّلة', () async {
    final s = await load();
    expect(s.status, CatalogStatus.ready);
    expect(s.notice, CatalogNotice.none);
    expect(s.items.single.id, 'mini');
    expect(s.items.single.status, BookStatus.notInstalled);
  });

  test('أول تشغيل دون إنترنت ← offlineEmpty', () async {
    env.server.offline = true;
    final s = await load();
    expect(s.status, CatalogStatus.offlineEmpty);
  });

  test('فشل الخادم بلا نسخة محفوظة ← errorEmpty؛ ومع نسخة ← stale', () async {
    env.server.catalogStatus = 500;
    expect((await load()).status, CatalogStatus.errorEmpty);
    container.dispose();

    env.server.catalogStatus = 200;
    await load();
    container.dispose();
    env.server.catalogStatus = 500;
    final s = await load();
    expect(s.status, CatalogStatus.ready);
    expect(s.notice, CatalogNotice.stale);
    expect(s.items.single.id, 'mini');
  });

  test('schema أحدث بلا شيء محفوظ ← errorEmpty مع updateApp', () async {
    env.server.catalog = catalogJson([], schema: 3);
    final s = await load();
    expect(s.status, CatalogStatus.errorEmpty);
    expect(s.notice, CatalogNotice.updateApp);
  });

  test('فهرس فارغ ← ready بلا عناصر', () async {
    env.server.catalog = catalogJson([]);
    final s = await load();
    expect(s.status, CatalogStatus.ready);
    expect(s.items, isEmpty);
  });

  test(
    'تحميل ناجح ← محمّل، ويبقى متاحاً دون إنترنت بعد إعادة التشغيل',
    () async {
      await load();
      final states = <BookTask?>[];
      container.listen(
        libraryControllerProvider,
        (_, s) => states.add(s.tasks['mini']),
      );
      expect(await controller().download('mini'), DownloadOutcome.installed);
      expect(states.whereType<DownloadingTask>(), isNotEmpty);
      expect(states.whereType<PreparingTask>(), isNotEmpty);
      expect(state().tasks, isEmpty);
      expect(state().items.single.status, BookStatus.installed);

      // تشغيل جديد دون إنترنت ولا فهرس محفوظ: الكتاب المحمّل يبقى ظاهراً.
      container.dispose();
      env.dir
          .listSync()
          .where((f) => f.path.endsWith('catalog.json'))
          .forEach((f) => f.deleteSync());
      env.server.offline = true;
      final s = await load();
      expect(s.status, CatalogStatus.ready);
      expect(s.notice, CatalogNotice.offline);
      expect(s.items.single.status, BookStatus.installed);
      expect(
        (await container.read(bookChaptersProvider('mini').future)).length,
        2,
      );
    },
  );

  test('ملف تالف (sha256) ← FailedTask(integrity) والكتاب غير محمّل', () async {
    env.server.files.updateAll((k, v) => [...v]..[10] ^= 0xff);
    await load();
    expect(await controller().download('mini'), DownloadOutcome.failed);
    expect(
      (state().tasks['mini']! as FailedTask).failure,
      TaskFailure.integrity,
    );
    expect(state().items.single.status, BookStatus.notInstalled);
  });

  test(
    'انقطاع أثناء التحميل ← FailedTask(network) ثم إعادة المحاولة تنجح',
    () async {
      await load();
      final stream = StreamController<List<int>>();
      env.server.bookStream = stream;
      final future = controller().download('mini');
      stream
        ..add([1, 2])
        ..addError(http.ClientException('reset'));
      expect(await future, DownloadOutcome.failed);
      expect(
        (state().tasks['mini']! as FailedTask).failure,
        TaskFailure.network,
      );
      await stream.close();

      env.server.bookStream = null;
      expect(await controller().download('mini'), DownloadOutcome.installed);
      expect(state().tasks, isEmpty);
    },
  );

  test('الإلغاء يعيد الكتاب إلى «غير محمّل» بلا خطأ', () async {
    await load();
    final stream = StreamController<List<int>>();
    env.server.bookStream = stream;
    final future = controller().download('mini');
    stream.add([1, 2, 3]);
    await Future<void>.delayed(Duration.zero);
    expect(state().tasks['mini'], isA<DownloadingTask>());
    controller().cancel('mini');
    expect(await future, DownloadOutcome.cancelled);
    expect(state().tasks, isEmpty);
    expect(state().items.single.status, BookStatus.notInstalled);
    await stream.close();
  });

  test('إصدار أحدث في الفهرس ← تحديث متاح، والتحديث يعيد updated', () async {
    await load();
    await controller().download('mini');
    container.dispose();

    env.server.catalog = catalogJson([
      env.server.addBook(miniBook(version: 2)),
    ], catalogVersion: 2);
    await load();
    expect(state().items.single.status, BookStatus.updateAvailable);
    expect(await controller().download('mini'), DownloadOutcome.updated);
    expect(state().items.single.status, BookStatus.installed);
    expect(state().items.single.installed!.version, 2);
  });

  test('فشل الحذف يعيد false ويعيد قراءة الكتب من القاعدة', () async {
    await load();
    await controller().download('mini');
    container.dispose();
    // مستودع يحذف فعلاً ثم يرمي خطأ (فشل بعد التغيير).
    container = ProviderContainer(
      overrides: env.overrides(books: _ThrowAfterDelete(env.books)),
    );
    container.read(libraryControllerProvider);
    await controller().refresh();
    expect(state().items.single.status, BookStatus.installed);
    expect(await controller().delete('mini'), isFalse);
    expect(state().items.single.status, BookStatus.notInstalled);
  });

  test(
    'فشل الخادم بلا فهرس محفوظ مع كتب محمّلة ← لافتة الخطأ والكتب ظاهرة',
    () async {
      await env.preinstall(miniBook());
      env.server.catalogStatus = 500;
      final s = await load();
      expect(s.status, CatalogStatus.ready);
      expect(s.notice, CatalogNotice.error);
      expect(s.items.single.status, BookStatus.installed);
    },
  );

  test('الحذف يعيده إلى «غير محمّل»', () async {
    await load();
    await controller().download('mini');
    expect(await controller().delete('mini'), isTrue);
    expect(state().items.single.status, BookStatus.notInstalled);
    expect(await container.read(bookChaptersProvider('mini').future), isEmpty);
  });
}

class _ThrowAfterDelete implements BookRepository {
  _ThrowAfterDelete(this.inner);
  final BookRepository inner;

  @override
  Future<void> delete(String bookId) async {
    await inner.delete(bookId);
    throw Exception('simulated failure after delete');
  }

  @override
  Future<List<ChapterInfo>> chapters(String bookId) => inner.chapters(bookId);

  @override
  Future<void> install(Uint8List gz, CatalogBook entry) =>
      inner.install(gz, entry);

  @override
  Future<List<InstalledBook>> installed() => inner.installed();
}
