import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/analysis.dart';
import '../../domain/scan.dart';

/// توكنات كل طلب: Firebase ID token وApp Check token. تُنفَّذ مع المصادقة (ترتيب البناء 9).
class AuthHeaders {
  const AuthHeaders({required this.idToken, required this.appCheck});
  final String idToken;
  final String appCheck;
}

abstract class AuthTokens {
  Future<AuthHeaders?> headers();
}

/// قبل ربط Firebase: لا توكنات، فيرفض الوسيط الطلب (unauthorized).
class NoAuthTokens implements AuthTokens {
  const NoAuthTokens();
  @override
  Future<AuthHeaders?> headers() async => null;
}

abstract class AnalysisService {
  Future<AnalysisResult> analyze(ScanType type, Uint8List jpeg);
}

class HttpAnalysisService implements AnalysisService {
  HttpAnalysisService({
    required this.baseUrl,
    required this.tokens,
    http.Client? client,
    this.timeout = const Duration(seconds: 25),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final AuthTokens tokens;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<AnalysisResult> analyze(ScanType type, Uint8List jpeg) async {
    if (baseUrl.isEmpty) throw const AnalysisException(AnalysisError.unknown);
    final auth = await tokens.headers();
    if (auth == null) throw const AnalysisException(AnalysisError.unauthorized);
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl/analyze?type=${type.name}'),
            headers: {
              'authorization': 'Bearer ${auth.idToken}',
              'x-firebase-appcheck': auth.appCheck,
              'content-type': 'image/jpeg',
            },
            body: jpeg,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const AnalysisException(AnalysisError.busy);
    } catch (_) {
      throw const AnalysisException(AnalysisError.offline);
    }
    // الوسيط لا يحدد charset، فنفك الجسم UTF-8 صراحة وإلا تتشوه الملاحظات العربية.
    return parseAnalysisResponse(res.statusCode, utf8.decode(res.bodyBytes, allowMalformed: true));
  }
}

/// يحوّل رد الوسيط إلى نتيجة أو [AnalysisException].
AnalysisResult parseAnalysisResponse(int status, String body) {
  Map<String, dynamic>? json;
  try {
    final d = jsonDecode(body);
    if (d is Map<String, dynamic>) json = d;
  } catch (_) {}
  if (status == 200 && json != null) {
    final s = switch (json['status']) {
      'ok' => AnalysisStatus.ok,
      'unclear' => AnalysisStatus.unclear,
      'not_coffee' => AnalysisStatus.notCoffee,
      _ => null,
    };
    final notes = json['notes'];
    final score = json['score'];
    if (s != null && score is int && notes is List && notes.length == 3 && notes.every((n) => n is String)) {
      return AnalysisResult(
        status: s,
        score: score,
        notes: notes.cast<String>(),
        promptVersion: json['promptVersion'] as String?,
        remaining: (json['quota'] as Map?)?['remaining'] as int?,
      );
    }
    throw const AnalysisException(AnalysisError.unknown);
  }
  throw AnalysisException(switch (status) {
    401 => AnalysisError.unauthorized,
    403 => AnalysisError.quotaExhausted,
    429 || 502 || 503 => AnalysisError.busy,
    _ => AnalysisError.unknown,
  });
}
