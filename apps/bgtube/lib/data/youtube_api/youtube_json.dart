/// تحويل ردود YouTube Data API v3 إلى نماذج domain. دوال صرفة قابلة للاختبار
/// بـ JSON ثابتة.
library;

import '../../domain/models/video_ref.dart';
import '../../domain/models/youtube_content.dart';

typedef Json = Map<String, dynamic>;

List<Json> itemsOf(Json body) =>
    [for (final i in (body['items'] as List<dynamic>? ?? const [])) if (i is Map<String, dynamic>) i];

String? nextTokenOf(Json body) {
  final t = body['nextPageToken'];
  return t is String && t.isNotEmpty ? t : null;
}

Object? _at(Object? node, List<String> path) {
  var n = node;
  for (final k in path) {
    if (n is! Map) return null;
    n = n[k];
  }
  return n;
}

String? _str(Object? node, List<String> path) {
  final v = _at(node, path);
  return v is String && v.isNotEmpty ? v : null;
}

/// أفضل صورة متاحة بالترتيب المفضّل.
String? thumbOf(Json snippet, {List<String> prefer = const ['medium', 'high', 'default']}) {
  for (final k in prefer) {
    final u = _str(snippet, ['thumbnails', k, 'url']);
    if (u != null) return u;
  }
  return null;
}

final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);');

/// عناوين search.list تصل بترميز HTML (&#39; و&amp;...).
String unescapeHtml(String s) => s.replaceAllMapped(_entity, (m) {
      final e = m[1]!;
      switch (e) {
        case 'amp':
          return '&';
        case 'lt':
          return '<';
        case 'gt':
          return '>';
        case 'quot':
          return '"';
        case 'apos':
          return "'";
      }
      final code = e.startsWith('#x') ? int.tryParse(e.substring(2), radix: 16) : int.tryParse(e.substring(1));
      if (code == null || code <= 0 || code > 0x10FFFF) return m[0]!;
      return String.fromCharCode(code);
    });

final _isoDuration = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$');

/// مدة ISO 8601 (PT1H2M3S). صفر (بث مباشر/قادم) أو صيغة غير معروفة = null.
Duration? parseIsoDuration(String? s) {
  if (s == null) return null;
  final m = _isoDuration.firstMatch(s);
  if (m == null) return null;
  int g(int i) => int.tryParse(m[i] ?? '') ?? 0;
  final d = Duration(days: g(1), hours: g(2), minutes: g(3), seconds: g(4));
  return d == Duration.zero ? null : d;
}

/// نتائج search.list (فيديوهات وقنوات؛ غيرها يُهمل). المدد تُضاف لاحقاً.
List<SearchResult> parseSearchItems(Json body) {
  final out = <SearchResult>[];
  for (final item in itemsOf(body)) {
    final snippet = item['snippet'];
    if (snippet is! Map<String, dynamic>) continue;
    final title = _str(snippet, ['title']);
    if (title == null) continue;
    switch (_str(item, ['id', 'kind'])) {
      case 'youtube#video':
        final id = _str(item, ['id', 'videoId']);
        if (id == null) continue;
        final channel = _str(snippet, ['channelTitle']);
        out.add(VideoResult(VideoRef(
          videoId: id,
          title: unescapeHtml(title),
          author: channel == null ? null : unescapeHtml(channel),
          thumbUrl: thumbOf(snippet),
        )));
      case 'youtube#channel':
        final id = _str(item, ['id', 'channelId']);
        if (id == null) continue;
        out.add(ChannelResult(ChannelSummary(
          id: id,
          title: unescapeHtml(title),
          thumbUrl: thumbOf(snippet, prefer: const ['default', 'medium', 'high']),
        )));
    }
  }
  return out;
}

/// مقطع من playlistItems.list مع تاريخ نشره (للترتيب في الرئيسية).
class PlaylistVideo {
  const PlaylistVideo(this.ref, this.publishedAt);
  final VideoRef ref;
  final DateTime? publishedAt;
}

/// عناصر قائمة (الرفع). الخاص والمحذوف لا يحمل `videoPublishedAt` ولا مالكاً فيُهمل.
List<PlaylistVideo> parsePlaylistItems(Json body) {
  final out = <PlaylistVideo>[];
  for (final item in itemsOf(body)) {
    final snippet = item['snippet'];
    if (snippet is! Map<String, dynamic>) continue;
    final id = _str(snippet, ['resourceId', 'videoId']);
    final title = _str(snippet, ['title']);
    final published = _str(item, ['contentDetails', 'videoPublishedAt']);
    final owner = _str(snippet, ['videoOwnerChannelTitle']);
    if (id == null || title == null || (published == null && owner == null)) continue;
    out.add(PlaylistVideo(
      VideoRef(videoId: id, title: unescapeHtml(title), author: owner, thumbUrl: thumbOf(snippet)),
      published == null ? null : DateTime.tryParse(published),
    ));
  }
  return out;
}

/// videos.list?part=contentDetails → المدة لكل معرّف.
Map<String, Duration> parseDurations(Json body) => {
      for (final item in itemsOf(body))
        ?_str(item, ['id']): ?parseIsoDuration(_str(item, ['contentDetails', 'duration'])),
    };

/// channels.list?part=contentDetails → قائمة الرفع لكل قناة.
Map<String, String> parseUploads(Json body) => {
      for (final item in itemsOf(body))
        ?_str(item, ['id']): ?_str(item, ['contentDetails', 'relatedPlaylists', 'uploads']),
    };

/// subscriptions.list → معرّفات القنوات بترتيب الرد.
List<String> parseSubscriptionChannelIds(Json body) => [
      for (final item in itemsOf(body)) ?_str(item, ['snippet', 'resourceId', 'channelId']),
    ];

/// channels.list?mine=true → اسم القناة.
String? parseMyChannelTitle(Json body) {
  final items = itemsOf(body);
  return items.isEmpty ? null : _str(items.first, ['snippet', 'title']);
}

/// أسباب الخطأ في ردّ الواجهة (`error.errors[].reason`).
Set<String> errorReasons(Object? body) {
  final errors = _at(body, ['error', 'errors']);
  return {
    if (errors is List)
      for (final e in errors)
        if (e is Map && e['reason'] is String) e['reason'] as String,
  };
}
