/// بيانات اختبار اصطناعية للمكتبة: كتاب صغير (test/fixtures/mini_book.json)
/// وفهرس وخادم وهمي. ليست نصوصاً تراثية.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const testBaseUrl = 'https://example.test/library/';

Map<String, Object?> miniBook({String id = 'mini', int version = 1}) {
  final text = File('test/fixtures/mini_book.json')
      .readAsStringSync()
      .replaceAll('mini', id);
  final map = jsonDecode(text) as Map<String, Object?>;
  map['version'] = version;
  return map;
}

Uint8List gzJson(Map<String, Object?> map) =>
    Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(map))));

Map<String, Object?> catalogEntry(Map<String, Object?> book, List<int> gz) {
  final id = book['id']! as String;
  final version = book['version']! as int;
  return {
    'id': id,
    'title': book['title'],
    'author': book['author'],
    'author_death_hijri': book['author_death_hijri'],
    'version': version,
    'file': 'books/$id/$id.v$version.json.gz',
    'sha256': sha256.convert(gz).toString(),
    'size_bytes': gz.length,
    'uncompressed_bytes': gzip.decode(gz).length,
    'paragraph_count': 3,
    'diacritics': 'partial',
    'source': {
      'name': 'بيانات اختبار اصطناعية',
      'url': 'https://example.invalid/$id',
    },
    'license': 'public-domain',
  };
}

String catalogJson(
  List<Map<String, Object?>> entries, {
  int schema = 1,
  int catalogVersion = 1,
}) => jsonEncode({
  'schema': schema,
  'catalog_version': catalogVersion,
  'updated': '2026-10-11',
  'books': entries,
});

/// مكتبة وهمية: ملفات الكتب بمساراتها والفهرس، مع مفاتيح لمحاكاة الأعطال.
class FakeLibraryServer {
  FakeLibraryServer();

  String? catalog;
  final files = <String, List<int>>{};
  bool offline = false;
  int catalogStatus = 200;

  /// إن وُضع: يتحكم الاختبار في تدفق جسم الملف (للتقدّم والإلغاء والانقطاع).
  StreamController<List<int>>? bookStream;
  final requests = <Uri>[];

  /// يضيف كتاباً ويعيد مدخل الفهرس.
  Map<String, Object?> addBook(Map<String, Object?> book) {
    final gz = gzJson(book);
    final entry = catalogEntry(book, gz);
    files[entry['file']! as String] = gz;
    return entry;
  }

  http.Client client() => MockClient.streaming((request, _) async {
    requests.add(request.url);
    if (offline) throw http.ClientException('offline', request.url);
    final path = request.url.toString().replaceFirst(testBaseUrl, '');
    if (path == 'catalog.json') {
      final body = catalog;
      if (body == null || catalogStatus != 200) {
        return http.StreamedResponse(
          Stream.value(const <int>[]),
          catalogStatus == 200 ? 404 : catalogStatus,
        );
      }
      final bytes = utf8.encode(body);
      return http.StreamedResponse(
        Stream.value(bytes),
        200,
        contentLength: bytes.length,
      );
    }
    final stream = bookStream;
    if (stream != null) return http.StreamedResponse(stream.stream, 200);
    final bytes = files[path];
    if (bytes == null) {
      return http.StreamedResponse(Stream.value(const <int>[]), 404);
    }
    // دفعات صغيرة ليظهر التقدّم.
    final chunks = <List<int>>[
      for (var i = 0; i < bytes.length; i += 64)
        bytes.sublist(i, i + 64 > bytes.length ? bytes.length : i + 64),
    ];
    return http.StreamedResponse(
      Stream.fromIterable(chunks),
      200,
      contentLength: bytes.length,
    );
  });
}

/// كتاب اصطناعي أكبر للقارئ: [chapters] أبواب في كل منها [perChapter] فقرة
/// نصها «فقرة اختبار اصطناعية رقم N…» (ليست نصاً تراثياً).
Map<String, Object?> syntheticBook({
  String id = 'big',
  int version = 1,
  int chapters = 3,
  int perChapter = 20,
}) {
  String pad(int n, int w) => n.toString().padLeft(w, '0');
  return {
    'schema': 1,
    'id': id,
    'version': version,
    'title': {'ar': 'كتاب اصطناعي طويل', 'en': 'Long Synthetic Book'},
    'author': {'ar': 'مولّد الاختبار', 'en': 'Test Generator'},
    'author_death_hijri': 200,
    'source': {
      'name': 'بيانات اختبار اصطناعية',
      'url': 'https://example.invalid/$id',
      'retrieved': '2026-10-11',
      'edition': 'لا توجد',
    },
    'license': 'public-domain',
    'removed': 'لا شيء — بيانات اصطناعية للاختبار',
    'chapters': [
      for (var c = 1; c <= chapters; c++)
        {
          'id': '$id-b${pad(c, 3)}',
          'title': 'باب اختبار رقم $c',
          'level': 1,
          'paragraphs': [
            for (var p = 1; p <= perChapter; p++)
              {
                'id': '$id-b${pad(c, 3)}-p${pad(p, 5)}',
                'text':
                    'فقرة اختبار اصطناعية رقم $p من الباب $c، '
                    'وفيها كلام مكرر لملء السطر وإطالة الفقرة قليلاً حتى تلتف على أكثر من سطر.',
              },
          ],
        },
    ],
    'redirects': <String, String>{},
  };
}
