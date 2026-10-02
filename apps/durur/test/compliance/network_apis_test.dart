import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dart_source.dart';

/// الميزة 10 (SPEC معيار 1، 6؛ D21): فحص ثابت يكمّل اختبار المرور بلا شبكة.
/// ذلك الاختبار يحجب `HttpClient` و`Socket` فقط (عبر HttpOverrides
/// وIOOverrides)؛ أما RawSocket وSecureSocket وRawSecureSocket
/// وRawDatagramSocket وWebSocket وInternetAddress.lookup فلا تمر بهما، لذا
/// يُمنع استعمالها في lib/ هنا أصلاً. الاستثناء الوحيد: `HttpClient` في
/// `lib/src/updates/update_fetcher.dart` (تحديث البيانات الموقّع).
/// ويُمنع العزل (`Isolate`، `compute`) لأن ما يجري فيه لا تغطيه تجاوزات
/// المنطقة في الاختبار.
void main() {
  const allowedHttpClientFile = 'lib/src/updates/update_fetcher.dart';

  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.startsWith('lib/l10n/'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// واجهات الشبكة في الكود (بلا التعليقات والنصوص).
  final networkApi = RegExp(
    r'\b(?:HttpClient|HttpServer|Socket|ServerSocket|RawSocket|RawServerSocket|'
    r'SecureSocket|SecureServerSocket|RawSecureSocket|RawSecureServerSocket|'
    r'RawDatagramSocket|WebSocket|WebSocketChannel|InternetAddress|'
    r'NetworkInterface|NetworkImage|NetworkAssetBundle|HttpRequest)\b|'
    r'\bImage\.network\b|\bnetworkUrl\b',
  );

  /// العزل: `Isolate.spawn/run`، و`compute(` من flutter/foundation كدالة
  /// حرة (لا استدعاء طريقة بالاسم نفسه مثل `HeliacalCalculator.compute`، ولا
  /// تعريفها).
  final isolateApi = RegExp(
    r'\bIsolate\b|\bspawnUri\b|'
    r'(?:^|[=(,:;{}>?]|\bawait|\breturn|=>)\s*compute\s*(?:<[^>]*>)?\s*\(',
    multiLine: true,
  );

  /// استيرادات مكتبات شبكة أو عزل (تُقرأ من النصوص لأنها سلاسل).
  final bannedImport = RegExp(
    r'^(?:dart:isolate|dart:html|dart:js_interop|package:(?:http|dio|'
    r'web_socket_channel|web_socket|grpc|socket_io_client|graphql|chopper|'
    r'retrofit|cached_network_image|connectivity_plus|'
    r'flutter_cache_manager)/)',
  );

  List<String> violations(RegExp pattern, {bool allowHttpClient = false}) {
    final found = <String>[];
    for (final f in files) {
      final src = f.readAsStringSync();
      final code = codeOnly(src);
      for (final m in pattern.allMatches(code)) {
        final api = m[0]!.trim();
        if (allowHttpClient &&
            f.path == allowedHttpClientFile &&
            api == 'HttpClient') {
          continue;
        }
        final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
        found.add('${f.path}:$line: $api');
      }
    }
    return found;
  }

  test('لا واجهة شبكة في lib/ إلا HttpClient في update_fetcher.dart', () {
    expect(violations(networkApi, allowHttpClient: true), isEmpty);
  });

  test('HttpClient موجود فعلاً في update_fetcher.dart (الفحص يرى الملف)', () {
    final code = codeOnly(File(allowedHttpClientFile).readAsStringSync());
    expect(networkApi.allMatches(code).map((m) => m[0]).toSet(), {
      'HttpClient',
    });
  });

  test('لا عزل (Isolate، compute) في lib/', () {
    expect(violations(isolateApi), isEmpty);
  });

  test('لا استيراد مكتبة شبكة أو عزل (package:http وأمثالها)', () {
    final found = <String>[];
    for (final f in files) {
      for (final s in dartStrings(f.readAsStringSync())) {
        if (bannedImport.hasMatch(s.value)) {
          found.add('${f.path}:${s.line}: ${s.value}');
        }
      }
    }
    expect(found, isEmpty);
  });

  test('dart:io يُستورد فقط حيث الحاجة (ملفات وHttpClient)', () {
    final importers = [
      for (final f in files)
        if (dartStrings(f.readAsStringSync()).any((s) => s.value == 'dart:io'))
          f.path,
    ];
    expect(importers, [
      'lib/src/updates/update_fetcher.dart',
      'lib/src/updates/update_store.dart',
    ]);
  });

  test('الفحص نفسه يلتقط المخالفات (عينات)', () {
    const sample = '''
// HttpClient في تعليق لا يُحسب
final note = 'Socket في نص لا يُحسب';
Future<void> f() async {
  await RawSocket.connect('h', 1);
  await SecureSocket.connect('h', 443);
  await RawSecureSocket.connect('h', 443);
  await RawDatagramSocket.bind('0.0.0.0', 0);
  await WebSocket.connect('wss://x');
  await InternetAddress.lookup('x');
  Image.network('https://x');
  final r = await compute(g, 1);
  await Isolate.spawn(g, 1);
  calculator.compute(year: 1);
}
HeliacalDates compute({required int year}) => x;
''';
    final code = codeOnly(sample);
    expect(networkApi.allMatches(code).map((m) => m[0]).toList(), [
      'RawSocket',
      'SecureSocket',
      'RawSecureSocket',
      'RawDatagramSocket',
      'WebSocket',
      'InternetAddress',
      'Image.network',
    ]);
    expect(isolateApi.allMatches(code), hasLength(2));
    expect(bannedImport.hasMatch('package:http/http.dart'), isTrue);
    expect(bannedImport.hasMatch('dart:isolate'), isTrue);
    expect(bannedImport.hasMatch('package:hijri/hijri.dart'), isFalse);
  });
}
