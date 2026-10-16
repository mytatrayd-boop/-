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
import '../storage/catalog_store.dart';
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

  /// العربي من الفهرس، والنقل اللاتيني منه أو من ملف الكتاب المحمّل (فهرس
  /// schema 2 بلا أسماء إنجليزية).
  LocalizedName get title => _name(entry?.title, installed?.title);
  LocalizedName get author => _name(entry?.author, installed?.author);

  static LocalizedName _name(LocalizedName? remote, LocalizedName? local) =>
      LocalizedName(ar: remote?.ar ?? local!.ar, en: remote?.en ?? local?.en);
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
    this.byId = const {},
    this.tasks = const {},
    this.catalogRevision = 0,
  });

  final CatalogStatus status;
  final CatalogNotice notice;

  /// كل كتب الفهرس مدموجة مع المحمّلة (المحمّل غير الموجود في الفهرس في
  /// آخرها). الشاشة تعرض صفحات من استعلام SQLite وتأخذ العنصر من [byId].
  final List<LibraryItem> items;
  final Map<String, LibraryItem> byId;
  final Map<String, BookTask> tasks;

  /// يزيد كلما تغيّر الفهرس أو الكتب المحمّلة: قوائم الصفحات تعيد الاستعلام.
  final int catalogRevision;

  /// الكتب المحمّلة (تبويب «المحمّلة» وإدارة الكتب في الإعدادات).
  List<LibraryItem> get installedItems =>
      items.where((i) => i.installed != null).toList();

  /// حجم نصوص الكتب المحمّلة كلها.
  int get installedBytes =>
      items.fold(0, (n, i) => n + (i.installed?.bytes ?? 0));

  /// التحميل يحتاج اتصالاً: يُعطَّل زر الكتب غير المحمّلة عند الانقطاع.
  bool get isOffline => notice == CatalogNotice.offline;

  LibraryItem? item(String id) => byId[id];

  LibraryState copyWith({
    CatalogStatus? status,
    CatalogNotice? notice,
    List<LibraryItem>? items,
    Map<String, BookTask>? tasks,
  }) => LibraryState(
    status: status ?? this.status,
    notice: notice ?? this.notice,
    items: items ?? this.items,
    byId: items == null ? byId : {for (final i in items) i.id: i},
    tasks: tasks ?? this.tasks,
    catalogRevision: items == null ? catalogRevision : catalogRevision + 1,
  );
}

final libraryControllerProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

/// أقل مدة بين جلبين تلقائيين للفهرس عند فتح المكتبة (§18.5).
const catalogRefreshInterval = Duration(hours: 6);

class LibraryController extends Notifier<LibraryState> {
  final _tokens = <String, CancelToken>{};
  final _entries = <String, CatalogBook>{};
  List<CatalogBook> _catalogBooks = const [];
  List<InstalledBook> _installed = const [];

  @override
  LibraryState build() {
    ref.onDispose(() {
      for (final t in _tokens.values) {
        t.cancel();
      }
    });
    Future.microtask(() => refresh(force: false));
    return const LibraryState(status: CatalogStatus.loading);
  }

  BookRepository get _books => ref.read(bookRepositoryProvider);

  /// يعرض الفهرس المحفوظ في SQLite فوراً ثم يجلب الجديد. [force] = false
  /// (عند فتح المكتبة) لا يجلب إن مرّ على آخر جلب أقل من 6 ساعات؛ السحب
  /// للتحديث و«إعادة المحاولة» يجلبان دائماً.
  Future<void> refresh({bool force = true}) async {
    if (!ref.mounted) return;
    if (state.items.isEmpty) {
      state = state.copyWith(
        status: CatalogStatus.loading,
        notice: CatalogNotice.none,
      );
    }
    await _loadInstalled();
    final store = ref.read(catalogStoreProvider);
    final repo = ref.read(catalogRepositoryProvider);
    final now = ref.read(clockProvider)().millisecondsSinceEpoch;
    var snapshot = await _loadSnapshot(store);
    if (snapshot == null) {
      // ترحيل: نسخة catalog.json القديمة تُعرض حتى يصل فهرس schema 2.
      final legacy = repo.readLegacyCache();
      if (legacy != null) {
        try {
          await store.replace(legacy, fetchedAt: 0);
        } on Exception {
          // العرض من الذاكرة يكفي.
        }
        snapshot = CatalogSnapshot(catalog: legacy, etag: null, fetchedAt: 0);
      }
    }
    _setCatalog(snapshot?.catalog);
    if (!ref.mounted) return;

    final current = snapshot != null && snapshot.catalog.schema == 2;
    final fresh =
        current &&
        now - snapshot.fetchedAt < catalogRefreshInterval.inMilliseconds;
    if (!force && fresh) {
      state = state.copyWith(
        status: CatalogStatus.ready,
        notice: CatalogNotice.none,
        items: _merge(),
      );
      return;
    }
    if (snapshot != null) {
      // يُعرض المحفوظ أثناء الجلب.
      state = state.copyWith(status: CatalogStatus.ready, items: _merge());
    }

    var notice = CatalogNotice.none;
    CatalogFailure? failure;
    try {
      final result = await repo.fetch(etag: current ? snapshot.etag : null);
      switch (result) {
        case CatalogFetched(:final catalog, :final etag):
          _setCatalog(catalog);
          try {
            await store.replace(catalog, etag: etag, fetchedAt: now);
            repo.deleteLegacyCache();
          } on Exception {
            // يُعرض من الذاكرة؛ يُعاد الحفظ في الجلب التالي.
          }
        case CatalogNotModified():
          try {
            await store.touch(now);
          } on Exception {
            // اختياري.
          }
      }
    } on CatalogFetchException catch (e) {
      failure = e.failure;
      notice = switch (e.failure) {
        CatalogFailure.network => CatalogNotice.offline,
        CatalogFailure.unsupportedSchema => CatalogNotice.updateApp,
        CatalogFailure.server =>
          snapshot != null ? CatalogNotice.stale : CatalogNotice.error,
      };
    }
    if (!ref.mounted) return;
    final items = _merge();
    final CatalogStatus status;
    if (_catalogBooks.isEmpty &&
        snapshot == null &&
        items.isEmpty &&
        failure != null) {
      status = failure == CatalogFailure.network
          ? CatalogStatus.offlineEmpty
          : CatalogStatus.errorEmpty;
    } else {
      status = CatalogStatus.ready;
    }
    state = state.copyWith(status: status, notice: notice, items: items);
  }

  Future<CatalogSnapshot?> _loadSnapshot(CatalogStore store) async {
    try {
      return await store.load();
    } on Exception {
      return null;
    }
  }

  void _setCatalog(Catalog? catalog) {
    _catalogBooks = catalog?.books ?? const [];
    _entries
      ..clear()
      ..addEntries(_catalogBooks.map((b) => MapEntry(b.id, b)));
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
    for (final e in _catalogBooks) {
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
    final entry = _entries[id];
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
