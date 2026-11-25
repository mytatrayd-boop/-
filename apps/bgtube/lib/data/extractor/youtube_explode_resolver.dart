import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/app_failure.dart';
import '../../domain/models/resolved_audio.dart';
import '../../domain/ports/audio_source_resolver.dart';

/// التنفيذ الوحيد الذي يعرف youtube_explode_dart (D4).
/// لا يستقبل ولا يستخدم أي رمز دخول أو كوكي.
class YoutubeExplodeResolver implements AudioSourceResolver {
  YoutubeExplodeResolver({YoutubeExplode? client, this.timeout = const Duration(seconds: 25)})
      : _yt = client ?? YoutubeExplode();

  final YoutubeExplode _yt;
  final Duration timeout;

  @override
  Future<ResolvedAudio> resolve(String videoId) async {
    try {
      return await _resolve(videoId).timeout(timeout);
    } on AppFailure {
      rethrow;
    } on RequestLimitExceededException {
      throw const AppFailure(FailureKind.rateLimited, 'request limit');
    } on TimeoutException {
      throw const AppFailure(FailureKind.network, 'timeout');
    } on SocketException {
      throw const AppFailure(FailureKind.network, 'socket');
    } on ClientException {
      throw const AppFailure(FailureKind.network, 'http');
    } catch (e) {
      throw AppFailure(FailureKind.extractionFailed, e.runtimeType.toString());
    }
  }

  Future<ResolvedAudio> _resolve(String videoId) async {
    final video = await _yt.videos.get(videoId);
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    if (manifest.audioOnly.isEmpty) {
      throw const AppFailure(FailureKind.extractionFailed, 'no audio streams');
    }
    final stream = manifest.audioOnly.withHighestBitrate();
    return ResolvedAudio(
      url: stream.url,
      title: video.title,
      author: video.author,
      duration: video.duration,
      thumbnailUrl: video.thumbnails.highResUrl,
      expiresAt: expiryFromUrl(stream.url),
    );
  }

  void dispose() => _yt.close();
}

/// يقرأ `expire` (ثوانٍ يونكس) من رابط googlevideo إن وُجد.
DateTime? expiryFromUrl(Uri url) {
  final raw = url.queryParameters['expire'];
  final secs = raw == null ? null : int.tryParse(raw);
  if (secs == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
}
