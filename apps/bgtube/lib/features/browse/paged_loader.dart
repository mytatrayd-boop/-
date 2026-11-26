import 'package:flutter/foundation.dart';

import '../../core/app_failure.dart';
import '../../domain/models/youtube_content.dart';

/// يجلب صفحة: [pageToken] null للأولى، و[refresh] للسحب للتحديث فقط.
typedef PageFetcher<T> = Future<ApiPage<T>> Function(String? pageToken, bool refresh);

/// حالة قائمة من الواجهة مع «تحميل المزيد». لا تحديث تلقائي: لا يجلب إلا عند
/// [load] أو [loadMore] صراحة. الأحدث يفوز (طلب قديم يُهمل ناتجه).
class PagedLoader<T> extends ChangeNotifier {
  PagedLoader(this._fetch);

  final PageFetcher<T> _fetch;

  List<T> items = const [];
  String? _next;
  bool loading = false;
  bool loadingMore = false;
  bool loaded = false;
  bool stale = false;
  AppFailure? failure;
  AppFailure? moreFailure;
  int _gen = 0;
  bool _disposed = false;

  bool get hasMore => _next != null;

  static AppFailure _asFailure(Object e) =>
      e is AppFailure ? e : AppFailure(FailureKind.apiFailed, e.runtimeType.toString());

  Future<void> load({bool refresh = false}) async {
    final g = ++_gen;
    loading = true;
    failure = null;
    moreFailure = null;
    _notify();
    try {
      final page = await _fetch(null, refresh);
      if (g != _gen) return;
      items = List.unmodifiable(page.items);
      // صفحة فارغة: لا طلب لما بعدها حتى لو أعاد الخادم رمزاً.
      _next = page.items.isEmpty ? null : page.nextPageToken;
      stale = page.stale;
      loaded = true;
    } catch (e) {
      if (g != _gen) return;
      // تبقى العناصر السابقة ظاهرة إن وُجدت.
      failure = _asFailure(e);
    }
    loading = false;
    loadingMore = false;
    _notify();
  }

  Future<void> loadMore() async {
    final token = _next;
    if (token == null || loading || loadingMore) return;
    final g = _gen;
    loadingMore = true;
    moreFailure = null;
    _notify();
    try {
      final page = await _fetch(token, false);
      if (g != _gen) return;
      items = List.unmodifiable([...items, ...page.items]);
      _next = page.items.isEmpty ? null : page.nextPageToken;
      stale = stale || page.stale;
    } catch (e) {
      if (g != _gen) return;
      moreFailure = _asFailure(e);
    }
    loadingMore = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
