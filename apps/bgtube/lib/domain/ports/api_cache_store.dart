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

  /// يمسح بيانات الحساب الخاصة (عند تسجيل الخروج).
  Future<void> deletePrivate();

  /// يحذف ما جُلب قبل [before] (تنظيف).
  Future<void> deleteOlderThan(DateTime before);
}

/// عدّاد الحصة اليومي (جدول `quota`). [day] مفتاح اليوم بتوقيت المحيط الهادئ.
abstract interface class QuotaStore {
  Future<int> unitsFor(String day);
  Future<void> add(String day, int units);

  /// يرفع عدّاد اليوم إلى [units] على الأقل (عند ردّ quotaExceeded).
  Future<void> raiseTo(String day, int units);
}
