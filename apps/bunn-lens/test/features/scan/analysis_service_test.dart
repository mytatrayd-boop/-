import 'dart:convert';
import 'dart:typed_data';

import 'package:bunn_lens/data/services/analysis_service.dart';
import 'package:bunn_lens/domain/analysis.dart';
import 'package:bunn_lens/domain/scan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Tokens implements AuthTokens {
  const _Tokens(this.h);
  final AuthHeaders? h;
  @override
  Future<AuthHeaders?> headers() async => h;
}

const _ok = {
  'status': 'ok',
  'score': 80,
  'tier': 'good',
  'notes': ['أ', 'ب', 'ج'],
  'promptVersion': 'v2',
  'quota': {'remaining': 4},
};

AnalysisError _errorOf(int status, [String body = '{}']) {
  try {
    parseAnalysisResponse(status, body);
  } on AnalysisException catch (e) {
    return e.error;
  }
  throw StateError('no error');
}

void main() {
  test('رد ناجح', () {
    final r = parseAnalysisResponse(200, jsonEncode(_ok));
    expect(r.isOk, isTrue);
    expect(r.score, 80);
    expect(r.notes, ['أ', 'ب', 'ج']);
    expect(r.remaining, 4);
    expect(r.promptVersion, 'v2');
  });

  test('unclear وnot_coffee حالتان لا فشل', () {
    final u = parseAnalysisResponse(200, jsonEncode({..._ok, 'status': 'unclear', 'score': 0, 'notes': ['', '', '']}));
    expect(u.status, AnalysisStatus.unclear);
    final n = parseAnalysisResponse(200, jsonEncode({..._ok, 'status': 'not_coffee'}));
    expect(n.status, AnalysisStatus.notCoffee);
  });

  test('رد مشوّه أو ملاحظات ليست 3 = unknown', () {
    expect(_errorOf(200, 'not json'), AnalysisError.unknown);
    expect(_errorOf(200, jsonEncode({..._ok, 'notes': ['أ']})), AnalysisError.unknown);
    expect(_errorOf(200, jsonEncode({..._ok, 'status': 'x'})), AnalysisError.unknown);
  });

  test('رموز الأخطاء', () {
    expect(_errorOf(401), AnalysisError.unauthorized);
    expect(_errorOf(403), AnalysisError.quotaExhausted);
    expect(_errorOf(429), AnalysisError.busy);
    expect(_errorOf(503), AnalysisError.busy);
    expect(_errorOf(502), AnalysisError.busy);
    expect(_errorOf(500), AnalysisError.unknown);
  });

  group('HttpAnalysisService', () {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);
    const auth = AuthHeaders(idToken: 'T', appCheck: 'A');

    test('يرسل التوكنين والنوع والصورة', () async {
      late http.Request seen;
      final s = HttpAnalysisService(
        baseUrl: 'https://w.example',
        tokens: const _Tokens(auth),
        client: MockClient((req) async {
          seen = req;
          return http.Response.bytes(utf8.encode(jsonEncode(_ok)), 200);
        }),
      );
      final r = await s.analyze(ScanType.coffee, jpeg);
      expect(r.score, 80);
      expect(r.notes, ['أ', 'ب', 'ج']);
      expect(seen.url.toString(), 'https://w.example/analyze?type=coffee');
      expect(seen.headers['authorization'], 'Bearer T');
      expect(seen.headers['x-firebase-appcheck'], 'A');
      expect(seen.bodyBytes, jpeg);
    });

    test('بلا توكنات = unauthorized ولا طلب شبكة', () async {
      var called = false;
      final s = HttpAnalysisService(
        baseUrl: 'https://w.example',
        tokens: const _Tokens(null),
        client: MockClient((_) async {
          called = true;
          return http.Response('', 200);
        }),
      );
      await expectLater(s.analyze(ScanType.bean, jpeg),
          throwsA(isA<AnalysisException>().having((e) => e.error, 'error', AnalysisError.unauthorized)));
      expect(called, isFalse);
    });

    test('فشل الشبكة = offline، والمهلة = busy', () async {
      final off = HttpAnalysisService(
        baseUrl: 'https://w.example',
        tokens: const _Tokens(auth),
        client: MockClient((_) async => throw http.ClientException('x')),
      );
      await expectLater(off.analyze(ScanType.bean, jpeg),
          throwsA(isA<AnalysisException>().having((e) => e.error, 'error', AnalysisError.offline)));
      final slow = HttpAnalysisService(
        baseUrl: 'https://w.example',
        tokens: const _Tokens(auth),
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) => Future.delayed(const Duration(seconds: 1), () => http.Response('', 200))),
      );
      await expectLater(slow.analyze(ScanType.bean, jpeg),
          throwsA(isA<AnalysisException>().having((e) => e.error, 'error', AnalysisError.busy)));
    });

    test('عنوان الوسيط فارغ = unknown', () async {
      final s = HttpAnalysisService(baseUrl: '', tokens: const _Tokens(auth), client: MockClient((_) async => http.Response('', 200)));
      await expectLater(s.analyze(ScanType.bean, jpeg),
          throwsA(isA<AnalysisException>().having((e) => e.error, 'error', AnalysisError.unknown)));
    });
  });
}
