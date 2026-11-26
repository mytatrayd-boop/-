import '../models/video_ref.dart';
import '../models/youtube_content.dart';

/// YouTube Data API v3 (الطبقة الرسمية، D29). كل طلب يمر بالكاش وعدّاد الحصة.
/// الأخطاء `AppFailure`: notSignedIn، authExpired، searchQuotaExceeded (وعاء
/// البحث)، quotaExceeded (الوعاء العام)، insufficientPermissions، network،
/// rateLimited، apiFailed. [refresh] يتجاوز الكاش الصالح (سحب للتحديث فقط).
abstract interface class YouTubeApi {
  /// `search.list` (طلب من وعاء البحث: 100 يومياً) ثم مدد الفيديوهات دفعة واحدة
  /// (وحدة من الوعاء العام). كل صفحة طلب مستقل من وعاء البحث.
  Future<ApiPage<SearchResult>> search(String query, {String? pageToken});

  /// فيديوهات قناة عبر قائمة الرفع (وحدة لكل صفحة) لا عبر البحث.
  Future<ApiPage<VideoRef>> channelVideos(String channelId, {String? pageToken, bool refresh = false});

  /// أحدث فيديوهات اشتراكات المستخدم (الرئيسية). التكلفة في D29.
  Future<ApiPage<VideoRef>> subscriptionFeed({bool refresh = false});

  /// اسم قناة المستخدم (`channels.list?mine=true`، وحدة). null إن لم تكن له قناة.
  Future<String?> myChannelTitle();

  /// تقدير الحصة لليوم الحالي (بتوقيت المحيط الهادئ).
  Future<QuotaUsage> quotaToday();
}
