import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../../core/app_failure.dart';
import '../../domain/models/resolved_audio.dart';
import '../../domain/ports/alternate_source_resolver.dart';
import '../../domain/ports/audio_source_resolver.dart';

/// مجموعات العملاء بالترتيب (D24). `null` = إدارة المكتبة الافتراضية
/// (androidSdkless ثم tv إن فشلت كلها). تُجرَّب المجموعة التالية عند طلب حلّ
/// الفيديو نفسه مجدداً خلال [YoutubeExplodeResolver.retryWindow] (بعد فشل تشغيل)،
/// وكذلك عند التبديل أثناء التشغيل ([YoutubeExplodeResolver.resolveAlternate]).
///
/// الترتيب حسب عدم حاجة روابط googlevideo إلى PO token (معرفتنا بـyt-dlp، لم
/// تُثبت على الجهاز): androidVr أولاً (لا يتطلب PO token لغير المقيّدين عمرياً)،
/// ثم الافتراضي (ANDROID بلا androidSdkVersion)، ثم ios، ثم tv (لا يتطلب لكنه
/// يحتاج فك توقيع من صفحة المشاهدة فهو أبطأ وأضعف). مستبعَدة عمداً: mweb وsafari
/// (WEB) وmediaConnect وandroidMusic لأنها تتطلب PO token أو لا تعطي صوتاً
/// موثوقاً، وwebCreator وtvSimplyEmbedded لأنها مُهمَلة في المكتبة (تطلب دخولاً).
///
/// لا يُصفَّر التدوير عند نجاح التشغيل: المنفذ `AudioSourceResolver` لا يعرف
/// نتيجة التشغيل. أثره المقبول: إعادة تشغيل الفيديو نفسه خلال دقيقتين بعد
/// نجاحه تستعمل العميل التالي؛ وبعد دقيقتين أو لفيديو آخر يبدأ من الأول.
final List<List<YoutubeApiClient>?> defaultClientStrategies = [
  [YoutubeApiClient.androidVr],
  null,
  [YoutubeApiClient.ios],
  [YoutubeApiClient.tv],
];

/// اسم العميل (معامل `c` في الرابط) لمجموعة عملاء؛ `null` = ANDROID.
String clientLabel(List<YoutubeApiClient>? clients) =>
    clients == null ? 'ANDROID' : _client(clients.first)['clientName'] as String;

/// التنفيذ الوحيد الذي يعرف youtube_explode_dart (D4).
/// لا يستقبل ولا يستخدم أي رمز دخول أو كوكي.
class YoutubeExplodeResolver implements AudioSourceResolver, AlternateSourceResolver {
  YoutubeExplodeResolver({
    YoutubeExplode? client,
    this.timeout = const Duration(seconds: 25),
    List<List<YoutubeApiClient>?>? strategies,
    this.retryWindow = const Duration(minutes: 2),
    this.metadataGrace = const Duration(seconds: 3),
    this.alternateTimeout = const Duration(seconds: 18),
    this.alternateClientTimeout = const Duration(seconds: 8),
    DateTime Function()? now,
  })  : _yt = client ?? YoutubeExplode(),
        _strategies = strategies ?? defaultClientStrategies,
        _now = now ?? DateTime.now;

  final YoutubeExplode _yt;
  final Duration timeout;
  final Duration retryWindow;

  /// أقصى انتظار للبيانات الوصفية بعد جاهزية الصوت؛ بعده يبدأ التشغيل بالمعرّف
  /// عنواناً (صفحة المشاهدة قد تتعثر بإعادة المحاولات عند تقييد المعدّل).
  final Duration metadataGrace;

  /// سقف إجمالي لـ[resolveAlternate] (وإلا جمّد المسح تشغيلاً فاشلاً) وسقف لكل عميل.
  final Duration alternateTimeout;
  final Duration alternateClientTimeout;
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

  /// تبديل العميل أثناء التشغيل (D24): يجرّب العملاء بالترتيب متجاوزاً
  /// [excludedClients]، بلا بيانات وصفية وبلا رجوع للافتراضي، ولا يمسّ تدوير
  /// [resolve]. يقبل فقط صيغة [itag] نفسها (بايتات متطابقة)؛ عميل يفشل أو لا
  /// يملكها يُتخطّى إلى التالي. null إن لم يبقَ عميل.
  @override
  Future<AlternateSource?> resolveAlternate(
    String videoId, {
    required Set<String> excludedClients,
    String? itag,
  }) async {
    final skip = {...excludedClients};
    final clock = Stopwatch()..start();
    for (final strategy in _strategies) {
      final remaining = alternateTimeout - clock.elapsed;
      if (remaining <= Duration.zero) return null;
      final label = clientLabel(strategy);
      if (skip.contains(label)) continue;
      skip.add(label);
      try {
        final audio = await _resolve(videoId, strategy, metadata: false, fallback: false, itag: itag)
            .timeout(remaining < alternateClientTimeout ? remaining : alternateClientTimeout);
        final actual = audio.url.queryParameters['c'] ?? label;
        // المكتبة قد ترجع لعميل آخر (tv عند فراغ الافتراضي): لا نكرر مستبعَداً.
        if (excludedClients.contains(actual)) continue;
        return AlternateSource(audio: audio, client: actual);
      } on RequestLimitExceededException {
        return null; // تقييد المعدّل: لا فائدة من تجربة عميل آخر الآن
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// السرعة (D26): البيانات الوصفية والـmanifest بالتوازي لا بالتسلسل، والـmanifest
  /// بلا صفحة المشاهدة (`requireWatchPage: false`): العملاء المستعملون لا يحتاجون
  /// فك توقيع، والمكتبة تجلب الصفحة تلقائياً إن احتاجها عميل (tv). فشل البيانات
  /// الوصفية وحده لا يمنع التشغيل (العنوان يصير المعرّف)، وتأخرها أكثر من
  /// [metadataGrace] لا يؤخره: تصل لاحقاً عبر `lateMetadata`.
  Future<ResolvedAudio> _resolve(
    String videoId,
    List<YoutubeApiClient>? clients, {
    bool metadata = true,
    bool fallback = true,
    String? itag,
  }) async {
    final videoFuture = metadata ? _yt.videos.get(videoId).then<Video?>((v) => v) : Future<Video?>.value(null);
    final manifestFuture = _manifest(videoId, clients, fallback: fallback);
    // نمنع خطأً غير ملتقَط إن فشل أحدهما قبل انتظار الآخر.
    videoFuture.ignore();
    manifestFuture.ignore();
    final manifest = await manifestFuture;
    final stream = pickAudioStream(itag == null ? manifest.audioOnly : manifest.audioOnly.where((s) => '${s.tag}' == itag));
    if (stream == null) {
      throw const AppFailure(FailureKind.extractionFailed, 'no audio streams');
    }
    Video? video;
    var late = false;
    try {
      video = await videoFuture.timeout(metadataGrace);
    } on TimeoutException {
      late = true; // تكتمل لاحقاً عبر lateMetadata
    } catch (e) {
      video = null;
    }
    return ResolvedAudio(
      url: stream.url,
      title: video?.title ?? videoId,
      author: video?.author,
      duration: video?.duration,
      thumbnailUrl: video?.thumbnails.highResUrl,
      expiresAt: expiryFromUrl(stream.url),
      httpHeaders: headersForStreamUrl(stream.url),
      sourceInfo: sourceInfoFor(stream),
      lateMetadata: late
          ? videoFuture.then<AudioMetadata?>(
              (v) => v == null
                  ? null
                  : AudioMetadata(
                      title: v.title,
                      author: v.author,
                      duration: v.duration,
                      thumbnailUrl: v.thumbnails.highResUrl,
                    ),
              onError: (Object _) => null,
            )
          : null,
    );
  }

  Future<StreamManifest> _manifest(String videoId, List<YoutubeApiClient>? clients, {bool fallback = true}) async {
    final streams = _yt.videos.streamsClient;
    try {
      return await streams.getManifest(videoId, ytClients: clients, requireWatchPage: false);
    } on RequestLimitExceededException {
      rethrow;
    } catch (_) {
      if (clients == null || !fallback) rethrow;
      // العميل البديل فشل: نعود لإدارة المكتبة الافتراضية مرة واحدة.
      return streams.getManifest(videoId, requireWatchPage: false);
    }
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
  // تعريف المكتبة لـANDROID_VR بلا userAgent؛ نبنيه بصيغة yt-dlp وبإصدار
  // العميل نفسه في المكتبة كي يطابق الرابط المُصدَر.
  'ANDROID_VR': androidVrUserAgent(_client(YoutubeApiClient.androidVr)['clientVersion'] as String),
};

/// User-Agent تطبيق YouTube VR (Quest) بصيغة yt-dlp.
String androidVrUserAgent(String clientVersion) =>
    'com.google.android.apps.youtube.vr.oculus/$clientVersion '
    '(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip';

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
