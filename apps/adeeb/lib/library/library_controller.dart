/// حالة شاشة المكتبة: الفهرس (من الشبكة أو النسخة المحفوظة) مدموجاً مع الكتب
/// المحمّلة، ومهام التحميل الجارية لكل كتاب (DESIGN §7).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/listening_providers.dart';
import '../core/formatters.dart';
import '../reader/reader_providers.dart';
import '../storage/book_repository.dart';
import 'book_downloader.dart';
import 'catalog.dart';
import 'catalog_repository.dart';
import 'library_providers.dart';

enum CatalogStatus {
  /// أول جلب ولا شيء يُعرض بعد.
  loading,

  /// توجد قائمة (قد تكون فارغة).
  ready,

  /// لا اتصال، ولا فهرس محفوظ، ولا كتب محمّلة.
  offlineEmpty,

  /// فشل الجلب لسبب غير الاتصال ولا شيء محفوظ.
  errorEmpty,
}

enum CatalogNotice {
  none,

  /// «أنت دون إنترنت — الكتب المحمّلة متاحة».
  offline,

  /// فشل الجلب وتُعرض نسخة محفوظة: «قد لا تكون القائمة محدّثة».
  stale,

  /// الفهرس بصيغة أحدث من التطبيق: «حدّث التطبيق».
  updateApp,

  /// فشل الجلب لسبب غير الاتصال ولا نسخة محفوظة، وتُعرض الكتب المحمّلة فقط:
  /// «تعذّر تحميل قائمة الكتب…».
  error,
}

enum BookStatus { notInstalled, installed, updateAvailable }

enum TaskFailure { network, integrity, other }

sealed class BookTask {
  const BookTask();
}

class DownloadingTask extends BookTask {
  const DownloadingTask(this.fraction);
  final double fraction;
}

/// يُستورد في قاعدة البيانات («يُجهَّز للبحث…»).
class PreparingTask extends BookTask {
  const PreparingTask();
}

class FailedTask extends BookTask {
  const FailedTask(this.failure);
  final TaskFailure failure;
}

enum DownloadOutcome { installed, updated, cancelled, failed }

class LibraryItem {
  const LibraryItem({this.entry, this.installed})
    : assert(entry != null || installed != null);

  final CatalogBook? entry;
  final InstalledBook? installed;

  String get id => entry?.id ?? installed!.id;
  LocalizedName get title => entry?.title ?? installed!.title;
  LocalizedName get author => entry?.author ?? installed!.author;
  int? get authorDeathHijri =>
      entry?.authorDeathHijri ?? installed?.authorDeathHijri;
  String get sourceName => entry?.sourceName ?? installed!.sourceName;
  String get license => entry?.license ?? installed!.license;

  /// حجم التحميل من الفهرس، أو حجم النص المحفوظ إن لم يكن في الفهرس.
  int get displaySize => entry?.sizeBytes ?? installed!.bytes;

  BookStatus get status {
    final local = installed;
    if (local == null) return BookStatus.notInstalled;
    final remote = entry;
    if (remote != null && remote.version > local.version) {
      return BookStatus.updateAvailable;
    }
    return BookStatus.installed;
  }
}

class LibraryState {
  const LibraryState({
    required this.status,
    this.notice = CatalogNotice.none,
    this.items = const [],
    this.tasks = const {},
  });

  final CatalogStatus status;
  final CatalogNotice notice;
  final List<LibraryItem> items;
  final Map<String, BookTask> tasks;

  /// التحميل يحتاج اتصالاً: يُعطَّل زر الكتب غير المحمّلة عند الانقطاع.
  bool get isOffline => notice == CatalogNotice.offline;

  LibraryItem? item(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  LibraryState copyWith({
    CatalogStatus? status,
    CatalogNotice? notice,
    List<LibraryItem>? items,
    Map<String, BookTask>? tasks,
  }) => LibraryState(
    status: status ?? this.status,
    notice: notice ?? this.notice,
    items: items ?? this.items,
    tasks: tasks ?? this.tasks,
  );
}

final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

class LibraryController extends Notifier<LibraryState> {
  final _tokens = <String, CancelToken>{};
  Catalog? _catalog;
  List<InstalledBook> _installed = const [];

  @override
  LibraryState build() {
    ref.onDispose(() {
      for (final t in _tokens.values) {
        t.cancel();
      }
    });
    Future.microtask(refresh);
    return const LibraryState(status: CatalogStatus.loading);
  }

  BookRepository get _books => ref.read(bookRepositoryProvider);

  Future<void> refresh() async {
    if (!ref.mounted) return;
    if (state.items.isEmpty) {
      state = state.copyWith(
        status: CatalogStatus.loading,
        notice: CatalogNotice.none,
      );
    }
    await _loadInstalled();
    final repo = ref.read(catalogRepositoryProvider);
    var notice = CatalogNotice.none;
    CatalogFailure? failure;
    try {
      _catalog = await repo.fetch();
    } on CatalogFetchException catch (e) {
      failure = e.failure;
      _catalog = repo.readCache();
      notice = switch (e.failure) {
        CatalogFailure.network => CatalogNotice.offline,
        CatalogFailure.unsupportedSchema => CatalogNotice.updateApp,
        CatalogFailure.server =>
          _catalog != null ? CatalogNotice.stale : CatalogNotice.error,
      };
    }
    if (!ref.mounted) return;
    final items = _merge();
    final CatalogStatus status;
    if (_catalog == null && items.isEmpty && failure != null) {
      status = failure == CatalogFailure.network
          ? CatalogStatus.offlineEmpty
          : CatalogStatus.errorEmpty;
    } else {
      status = CatalogStatus.ready;
    }
    state = state.copyWith(status: status, notice: notice, items: items);
  }

  Future<void> _loadInstalled() async {
    try {
      _installed = await _books.installed();
    } on Exception {
      _installed = const [];
    }
  }

  List<LibraryItem> _merge() {
    final local = {for (final b in _installed) b.id: b};
    final items = <LibraryItem>[];
    for (final e in _catalog?.books ?? const <CatalogBook>[]) {
      items.add(LibraryItem(entry: e, installed: local.remove(e.id)));
    }
    for (final b in local.values) {
      items.add(LibraryItem(installed: b));
    }
    return items;
  }

  void _setTask(String id, BookTask? task) {
    if (!ref.mounted) return;
    final tasks = Map<String, BookTask>.of(state.tasks);
    if (task == null) {
      tasks.remove(id);
    } else {
      tasks[id] = task;
    }
    state = state.copyWith(tasks: tasks);
  }

  /// يحمّل الإصدار الذي في الفهرس (تحميل أول أو تحديث).
  Future<DownloadOutcome> download(String id) async {
    final entry = _catalog?.byId(id);
    final url = entry == null
        ? null
        : ref.read(catalogRepositoryProvider).bookUrl(entry);
    if (entry == null || url == null || _tokens.containsKey(id)) {
      return DownloadOutcome.failed;
    }
    final wasInstalled = _installed.any((b) => b.id == id);
    final token = CancelToken();
    _tokens[id] = token;
    _setTask(id, const DownloadingTask(0));
    var lastPercent = 0;
    try {
      final bytes = await ref
          .read(bookDownloaderProvider)
          .download(
            url,
            expectedSha256: entry.sha256,
            expectedSize: entry.sizeBytes,
            cancel: token,
            onProgress: (received, total) {
              final percent = percentOf(received / total);
              if (percent != lastPercent && !token.isCancelled) {
                lastPercent = percent;
                _setTask(id, DownloadingTask(received / total));
              }
            },
          );
      if (token.isCancelled) throw const DownloadCancelledException();
      _setTask(id, const PreparingTask());
      await _books.install(bytes, entry);
      await _loadInstalled();
      if (!ref.mounted) return DownloadOutcome.failed;
      ref.invalidate(bookChaptersProvider(id));
      // المفضلة والموضع نُقلا عبر redirects داخل الاستيراد؛ يُعاد عرضهما.
      ref.read(installRevisionProvider.notifier).bump(id);
      final tasks = Map<String, BookTask>.of(state.tasks)..remove(id);
      state = state.copyWith(
        items: _merge(),
        tasks: tasks,
        // نجاح التحميل يعني عودة الاتصال.
        notice: state.notice == CatalogNotice.offline
            ? CatalogNotice.none
            : null,
      );
      return wasInstalled ? DownloadOutcome.updated : DownloadOutcome.installed;
    } on DownloadCancelledException {
      _setTask(id, null);
      return DownloadOutcome.cancelled;
    } on BookDownloadException catch (e) {
      _setTask(
        id,
        FailedTask(switch (e.failure) {
          DownloadFailure.network => TaskFailure.network,
          DownloadFailure.integrity => TaskFailure.integrity,
          DownloadFailure.server => TaskFailure.other,
        }),
      );
      return DownloadOutcome.failed;
    } on LibraryFormatException {
      _setTask(id, const FailedTask(TaskFailure.integrity));
      return DownloadOutcome.failed;
    } on UnsupportedSchemaException {
      _setTask(id, const FailedTask(TaskFailure.integrity));
      return DownloadOutcome.failed;
    } on Exception {
      _setTask(id, const FailedTask(TaskFailure.other));
      return DownloadOutcome.failed;
    } finally {
      _tokens.remove(id);
    }
  }

  /// يوقف التحميل دون حوار ويعيد الكتاب إلى حالته السابقة.
  void cancel(String id) => _tokens[id]?.cancel();

  /// يحذف الكتاب من الجهاز. يعيد true عند النجاح.
  Future<bool> delete(String id) async {
    cancel(id);
    // الكتاب المسموع يُحذف: يتوقف الاستماع ويُحفظ الموضع قبل الحذف.
    final player = ref.read(listeningPlayerProvider);
    if (player.state.bookId == id) await player.stop();
    var ok = true;
    try {
      await _books.delete(id);
    } on Exception {
      ok = false;
    }
    // تُعاد قراءة الكتب المحمّلة في كل الأحوال: الواجهة تعكس ما في القاعدة فعلاً.
    await _loadInstalled();
    if (!ref.mounted) return ok;
    ref.invalidate(bookChaptersProvider(id));
    ref.read(installRevisionProvider.notifier).bump(id);
    final tasks = Map<String, BookTask>.of(state.tasks)..remove(id);
    state = state.copyWith(items: _merge(), tasks: tasks);
    return ok;
  }
}
