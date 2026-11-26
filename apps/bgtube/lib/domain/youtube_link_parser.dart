import '../core/app_failure.dart';

/// نتيجة تحليل رابط يوتيوب.
class ParsedLink {
  const ParsedLink({this.videoId, this.playlistId});

  final String? videoId;
  final String? playlistId;
}

final _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// معرّف قائمة يوتيوب: حروف وأرقام و`_-` (PL…، UU…، OLAK…، LL، WL، RD…).
final _playlistIdPattern = RegExp(r'^[A-Za-z0-9_-]{2,64}$');

/// نوع قائمة من رابط `list=` (D30): ما لا تتيحه الواجهة الرسمية يُعرف مسبقاً
/// برسالة واضحة بدل خطأ عام من الخادم.
enum PlaylistLinkKind {
  /// قائمة عادية (PL/UU/OLAK/FL…): عبر playlistItems.
  regular,

  /// إعجابات المستخدم نفسه (LL): عبر الإعجابات.
  likes,

  /// «المشاهدة لاحقاً» أو السجل (WL/HL): غير متاحين في الواجهة الرسمية.
  watchLater,

  /// قوائم المزيج المولّدة (RD…): غير متاحة في الواجهة الرسمية.
  mix,
}

PlaylistLinkKind classifyPlaylistId(String id) {
  if (id == 'LL') return PlaylistLinkKind.likes;
  if (id == 'WL' || id == 'HL') return PlaylistLinkKind.watchLater;
  if (id.startsWith('RD')) return PlaylistLinkKind.mix;
  return PlaylistLinkKind.regular;
}

/// يحلّل رابط يوتيوب (watch / youtu.be / shorts / embed / live / playlist).
/// يرمي [AppFailure] من نوع invalidLink إن لم يكن الرابط صالحاً.
ParsedLink parseYoutubeLink(String input) {
  var text = input.trim();
  if (text.isEmpty) throw const AppFailure(FailureKind.invalidLink);
  if (!text.contains('://')) text = 'https://$text';

  final Uri uri;
  try {
    uri = Uri.parse(text);
  } on FormatException {
    throw const AppFailure(FailureKind.invalidLink);
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    throw const AppFailure(FailureKind.invalidLink);
  }

  final host = uri.host.toLowerCase();
  final isShort = host == 'youtu.be' || host == 'www.youtu.be';
  final isYoutube = host == 'youtube.com' || host.endsWith('.youtube.com');
  if (!isShort && !isYoutube) throw const AppFailure(FailureKind.invalidLink);

  String? valid(String? id) => id != null && _idPattern.hasMatch(id) ? id : null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  final list = uri.queryParameters['list'];
  final playlistId = (list != null && list.isNotEmpty) ? list : null;

  String? videoId;
  if (isShort) {
    videoId = valid(segments.isEmpty ? null : segments.first);
  } else if (segments.isNotEmpty && segments.first == 'watch') {
    videoId = valid(uri.queryParameters['v']);
  } else if (segments.length >= 2 &&
      const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
    videoId = valid(segments[1]);
  }

  if (videoId != null) return ParsedLink(videoId: videoId, playlistId: playlistId);
  if (segments.isNotEmpty && segments.first == 'playlist' && playlistId != null) {
    if (!_playlistIdPattern.hasMatch(playlistId)) throw const AppFailure(FailureKind.invalidLink);
    return ParsedLink(playlistId: playlistId);
  }
  throw const AppFailure(FailureKind.invalidLink);
}
