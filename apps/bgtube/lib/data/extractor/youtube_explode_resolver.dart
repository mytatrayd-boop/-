import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/app_failure.dart';
import '../../domain/models/resolved_audio.dart';
import '../../domain/ports/audio_source_resolver.dart';

/// مجموعات العملاء بالترتيب (D22). `null` = إدارة المكتبة الافتراضية
/// (androidSdkless ثم tv). تُجرَّب المجموعة التالية عند طلب حلّ الفيديو نفسه
/// مجدداً خلال [YoutubeExplodeResolver.retryWindow] (أي بعد فشل تشغيل).
final List<List<YoutubeApiClient>?> defaultClientStrategies = [
  null,
  [YoutubeApiClient.androidVr],
  [YoutubeApiClient.ios],
];

/// التنفيذ الوحيد الذي يعرف youtube_explode_dart (D4).
/// لا يستقبل ولا يستخدم أي رمز دخول أو كوكي.
class YoutubeExplodeResolver implements AudioSourceResolver {
  YoutubeExplodeResolver({
    YoutubeExplode? client,
    this.timeout = const Duration(seconds: 25),
    List<List<YoutubeApiClient>?>? strategies,
    this.retryWindow = const Duration(minutes: 2),
    DateTime Function()? now,
  })  : _yt = client ?? YoutubeExplode(),
        _strategies = strategies ?? defaultClientStrategies,
        _now = now ?? DateTime.now;

  final YoutubeExplode _yt;
  final Duration timeout;
  final Duration retryWindow;
  final List<List<YoutubeApiClient>?> _strategies;
  final DateTime Function() _now;

  String? _lastId;
  DateTime? _lastAt;
  int _attempt = 0;

  @override
  Future<ResolvedAudio> resolve(String videoId) async {
    final now = _now();
    final repeat = videoId == _lastId && _lastAt != null && now.difference(_lastAt!) < retryWindow;
    _attempt = repeat ? _attempt + 1 : 0;
    _lastId = videoId;
    _lastAt = now;
    final strategy = _strategies[_attempt % _strategies.length];
    try {
      return await _resolve(videoId, strategy).timeout(timeout);
    } on AppFailure {
      rethrow;
    } on RequestLimitExceededException {
      throw const AppFailure(FailureKind.rateLimited, 'RequestLimitExceeded');
    } on TimeoutException {
      throw const AppFailure(FailureKind.network, 'Timeout');
    } on SocketException catch (e) {
      throw AppFailure(FailureKind.network, 'SocketException${_osCode(e)}');
    } on ClientException {
      throw const AppFailure(FailureKind.network, 'ClientException');
    } catch (e) {
      throw AppFailure(FailureKind.extractionFailed, extractionDetail(e));
    }
  }

  Future<ResolvedAudio> _resolve(String videoId, List<YoutubeApiClient>? clients) async {
    final video = await _yt.videos.get(videoId);
    StreamManifest manifest;
    try {
      manifest = await _yt.videos.streamsClient.getManifest(videoId, ytClients: clients);
    } on RequestLimitExceededException {
      rethrow;
    } catch (_) {
      if (clients == null) rethrow;
      // العميل البديل فشل: نعود لإدارة المكتبة الافتراضية مرة واحدة.
      manifest = await _yt.videos.streamsClient.getManifest(videoId);
    }
    final stream = pickAudioStream(manifest.audioOnly);
    if (stream == null) {
      throw const AppFailure(FailureKind.extractionFailed, 'no audio streams');
    }
    return ResolvedAudio(
      url: stream.url,
      title: video.title,
      author: video.author,
      duration: video.duration,
      thumbnailUrl: video.thumbnails.highResUrl,
      expiresAt: expiryFromUrl(stream.url),
      httpHeaders: headersForStreamUrl(stream.url),
      sourceInfo: sourceInfoFor(stream),
    );
  }

  void dispose() => _yt.close();
}

String _osCode(SocketException e) {
  final code = e.osError?.errorCode;
  return code == null ? '' : ' os$code';
}

/// يختار مسار الصوت: صوت فقط، تقدّمي (بلا أجزاء DASH)، المسار الأصلي إن تعدّدت
/// اللغات، ويفضّل mp4/AAC (m4a) على webm/opus لتوافق ExoPlayer، ثم أعلى معدّل.
AudioOnlyStreamInfo? pickAudioStream(Iterable<AudioOnlyStreamInfo> streams) {
  final progressive = streams.where((s) => s.fragments.isEmpty).toList();
  if (progressive.isEmpty) return null;
  final original = progressive.where((s) => s.audioTrack == null || s.audioTrack!.audioIsDefault).toList();
  final pool = original.isEmpty ? progressive : original;
  final m4a = pool.where((s) => s.container == StreamContainer.mp4 && s.audioCodec.startsWith('mp4a')).toList();
  final candidates = m4a.isEmpty ? pool : m4a;
  candidates.sort((a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond));
  return candidates.first;
}

/// User-Agent العميل الذي أصدر الرابط (معامل `c`)، مأخوذاً من تعريفات المكتبة
/// نفسها. هذا ما يفعله NewPipe (YoutubeHttpDataSource) وyt-dlp (http_headers لكل
/// صيغة). لا كوكي ولا رموز.
Map<String, String> headersForStreamUrl(Uri url) {
  final ua = _clientUserAgents[url.queryParameters['c']];
  return ua == null ? const {} : {'User-Agent': ua};
}

final Map<String, String> _clientUserAgents = {
  for (final c in [YoutubeApiClient.androidSdkless, YoutubeApiClient.ios, YoutubeApiClient.safari, YoutubeApiClient.tv])
    if (_client(c)['userAgent'] is String) _client(c)['clientName'] as String: _client(c)['userAgent'] as String,
};

Map<String, dynamic> _client(YoutubeApiClient c) => (c.payload['context'] as Map)['client'] as Map<String, dynamic>;

/// مثال: `ANDROID itag140 mp4a.40.2 ip6`. لا رابط ولا قيم موقّعة.
String sourceInfoFor(AudioOnlyStreamInfo s) {
  final q = s.url.queryParameters;
  final ip = q['ip'];
  final family = ip == null ? '' : (ip.contains(':') ? ' ip6' : ' ip4');
  return '${q['c'] ?? '?'} itag${s.tag} ${s.audioCodec}$family';
}

/// تشخيص فشل الاستخراج: نوع الاستثناء ورمز HTTP إن وُجد، بلا الرسالة الكاملة
/// (قد تحوي روابط).
String extractionDetail(Object e) {
  final type = e.runtimeType.toString();
  int? status;
  if (e is FatalFailureException) {
    status = e.statusCode;
  } else {
    final m = RegExp(r'(?:returned|code:?|\()\s*([1-5]\d\d)\b', caseSensitive: false).firstMatch(e.toString());
    status = m == null ? null : int.parse(m.group(1)!);
  }
  return status == null ? type : '$type HTTP $status';
}

/// يقرأ `expire` (ثوانٍ يونكس) من رابط googlevideo إن وُجد.
DateTime? expiryFromUrl(Uri url) {
  final raw = url.queryParameters['expire'];
  final secs = raw == null ? null : int.tryParse(raw);
  if (secs == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
}
