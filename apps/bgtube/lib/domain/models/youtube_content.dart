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

class ChannelResult extends SearchResult {
  const ChannelResult(this.channel);
  final ChannelSummary channel;
}

/// صفحة من نتائج الواجهة. [stale] = نسخة محفوظة منتهية الصلاحية خُدمت بدل الشبكة
/// (نفاد الحصة أو انقطاع)، فتعرض الواجهة «هذه نسخة محفوظة».
class ApiPage<T> {
  const ApiPage(this.items, {this.nextPageToken, this.stale = false});

  final List<T> items;
  final String? nextPageToken;
  final bool stale;

  bool get hasMore => nextPageToken != null;
}

/// تقدير استهلاك الحصة اليوم (يومها بتوقيت المحيط الهادئ).
class QuotaUsage {
  const QuotaUsage({required this.used, required this.limit, required this.exhausted, required this.searchesLeft});

  /// الوحدات المقدّرة المستهلكة اليوم.
  final int used;

  /// الحد اليومي (10,000 افتراضياً).
  final int limit;

  /// لا مزيد من الطلبات اليوم (تجاوز 95% أو ردّ quotaExceeded).
  final bool exhausted;

  /// عدد عمليات البحث (≈100 وحدة) الممكنة قبل حد التوقف.
  final int searchesLeft;
}
