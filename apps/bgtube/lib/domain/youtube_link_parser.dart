import '../core/app_failure.dart';

/// نتيجة تحليل رابط يوتيوب.
class ParsedLink {
  const ParsedLink({this.videoId, this.playlistId});

  final String? videoId;
  final String? playlistId;
}

final _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

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
    return ParsedLink(playlistId: playlistId);
  }
  throw const AppFailure(FailureKind.invalidLink);
}
