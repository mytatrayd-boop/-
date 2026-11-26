/// مخزن ردود الواجهة (جدول `api_cache`). المفتاح = الطلب المطبَّع بلا رموز.
class CachedResponse {
  const CachedResponse({required this.json, required this.fetchedAt, required this.ttl});

  final String json;
  final DateTime fetchedAt;
  final Duration ttl;

  bool isFresh(DateTime now) => now.difference(fetchedAt) < ttl;
}

abstract interface class ApiCacheStore {
  Future<CachedResponse?> read(String key);
  Future<void> write(String key, CachedResponse value, {required bool private});

  /// يمسح الكاش كله (الخروج، أو الإقلاع دون جلسة، أو دخول بعد انتهاء الجلسة):
  /// حتى القوائم العامة تكشف اشتراكات المستخدم وما بحث عنه.
  Future<void> deleteAll();

  /// يحذف ما جُلب قبل [before] (تنظيف).
  Future<void> deleteOlderThan(DateTime before);
}

/// عدّاد الحصة اليومي لكل وعاء (جدول `quota`). [day] مفتاح اليوم بتوقيت المحيط
/// الهادئ، و[bucket] اسم الوعاء (`general` أو `search`).
abstract interface class QuotaStore {
  Future<int> unitsFor(String day, String bucket);
  Future<void> add(String day, String bucket, int units);

  /// يرفع عدّاد الوعاء إلى [units] على الأقل (عند ردّ quotaExceeded).
  Future<void> raiseTo(String day, String bucket, int units);
}
