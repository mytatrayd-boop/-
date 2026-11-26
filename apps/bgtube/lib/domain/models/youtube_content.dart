import 'video_ref.dart';

/// قناة يوتيوب كما تُعرض في النتائج (D29).
class ChannelSummary {
  const ChannelSummary({required this.id, required this.title, this.thumbUrl});

  final String id;
  final String title;
  final String? thumbUrl;

  @override
  bool operator ==(Object other) =>
      other is ChannelSummary && other.id == id && other.title == title && other.thumbUrl == thumbUrl;

  @override
  int get hashCode => Object.hash(id, title, thumbUrl);
}

/// عنصر من نتائج البحث: فيديو أو قناة.
sealed class SearchResult {
  const SearchResult();
}

class VideoResult extends SearchResult {
  const VideoResult(this.video);
  final VideoRef video;
}

/// قائمة تشغيل يوتيوب في المكتبة (`playlists.list?mine=true`، الميزة 5).
class PlaylistSummary {
  const PlaylistSummary({required this.id, required this.title, this.itemCount, this.thumbUrl});

  final String id;
  final String title;

  /// عدد العناصر كما يعلنه يوتيوب (قد يشمل الخاص والمحذوف).
  final int? itemCount;
  final String? thumbUrl;

  @override
  bool operator ==(Object other) =>
      other is PlaylistSummary &&
      other.id == id &&
      other.title == title &&
      other.itemCount == itemCount &&
      other.thumbUrl == thumbUrl;

  @override
  int get hashCode => Object.hash(id, title, itemCount, thumbUrl);
}

class ChannelResult extends SearchResult {
  const ChannelResult(this.channel);
  final ChannelSummary channel;
}

/// صفحة من نتائج الواجهة. [stale] = نسخة محفوظة منتهية الصلاحية خُدمت بدل الشبكة
/// (نفاد الحصة أو انقطاع)، فتعرض الواجهة «هذه نسخة محفوظة».
class ApiPage<T> {
  const ApiPage(this.items, {this.nextPageToken, this.stale = false, this.total});

  final List<T> items;
  final String? nextPageToken;
  final bool stale;

  /// العدد الكلي المعلن (`pageInfo.totalResults`) إن عُرف؛ لرسالة «أُضيف n من m».
  final int? total;

  bool get hasMore => nextPageToken != null;
}

/// وعاء الحصة (D29، توثيق search.list بعد 1 يونيو 2026): البحث له وعاء مستقل
/// (100 طلب يومياً، وحدة لكل طلب)، وباقي الطرق في الوعاء العام (10,000 وحدة).
enum QuotaBucket { general, search }

/// استهلاك وعاء واحد اليوم (يومه بتوقيت المحيط الهادئ).
class BucketUsage {
  const BucketUsage({required this.used, required this.limit, required this.stopAt});

  /// الوحدات المقدّرة المستهلكة اليوم.
  final int used;

  /// الحد اليومي.
  final int limit;

  /// حد التوقف المحلي (≤ الحد).
  final int stopAt;

  /// لا مزيد من الطلبات اليوم في هذا الوعاء.
  bool get exhausted => used >= stopAt;

  int get left => used >= stopAt ? 0 : stopAt - used;
}

/// تقدير الحصة اليوم للوعاءين.
class QuotaUsage {
  const QuotaUsage({required this.general, required this.search});

  final BucketUsage general;
  final BucketUsage search;

  BucketUsage of(QuotaBucket b) => b == QuotaBucket.search ? search : general;
}
