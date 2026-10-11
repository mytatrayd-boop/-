import 'dart:async';

import 'package:adeeb/library/book_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/library_fixtures.dart';

void main() {
  late FakeLibraryServer server;
  late Map<String, Object?> entry;
  late BookDownloader downloader;
  final url = Uri.parse('${testBaseUrl}books/mini/mini.v1.json.gz');

  setUp(() {
    server = FakeLibraryServer();
    entry = server.addBook(miniBook());
    downloader = BookDownloader(server.client(), timeout: const Duration(seconds: 2));
  });

  Future<List<int>> run({String? sha, int? size, ProgressCallback? onProgress, CancelToken? cancel}) =>
      downloader.download(
        url,
        expectedSha256: sha ?? entry['sha256']! as String,
        expectedSize: size ?? entry['size_bytes']! as int,
        onProgress: onProgress,
        cancel: cancel,
      );

  Matcher failsWith(DownloadFailure f) =>
      throwsA(isA<BookDownloadException>().having((e) => e.failure, 'failure', f));

  test('ينزّل ويتحقق من sha256 مع تقدّم متزايد ينتهي بالحجم الكامل', () async {
    final progress = <int>[];
    final bytes = await run(onProgress: (r, t) => progress.add(r));
    expect(bytes, server.files['books/mini/mini.v1.json.gz']);
    expect(progress.length, greaterThan(1));
    expect(progress, orderedEquals([...progress]..sort()));
    expect(progress.last, entry['size_bytes']);
  });

  test('sha256 لا يطابق ← integrity', () async {
    await expectLater(run(sha: 'a' * 64), failsWith(DownloadFailure.integrity));
  });

  test('ملف أكبر من المعلن يُرفض أثناء التنزيل', () async {
    await expectLater(run(size: 10), failsWith(DownloadFailure.integrity));
  });

  test('ملف أصغر من المعلن ← integrity', () async {
    await expectLater(run(size: (entry['size_bytes']! as int) + 1), failsWith(DownloadFailure.integrity));
  });

  test('انقطاع الاتصال ← network', () async {
    server.offline = true;
    await expectLater(run(), failsWith(DownloadFailure.network));
  });

  test('انقطاع أثناء التدفق ← network', () async {
    final controller = StreamController<List<int>>();
    server.bookStream = controller;
    final future = run();
    controller.add([1, 2, 3]);
    controller.addError(http.ClientException('Connection reset'));
    await expectLater(future, failsWith(DownloadFailure.network));
    await controller.close();
  });

  test('توقف البيانات أطول من المهلة ← network', () async {
    final controller = StreamController<List<int>>();
    server.bookStream = controller;
    downloader = BookDownloader(server.client(), timeout: const Duration(milliseconds: 50));
    final future = run();
    controller.add([1, 2, 3]);
    await expectLater(future, failsWith(DownloadFailure.network));
    await controller.close();
  });

  test('404 ← server', () async {
    server.files.clear();
    await expectLater(run(), failsWith(DownloadFailure.server));
  });

  test('الإلغاء أثناء التدفق يرمي DownloadCancelledException', () async {
    final controller = StreamController<List<int>>();
    server.bookStream = controller;
    final token = CancelToken();
    final future = run(cancel: token, onProgress: (_, _) => token.cancel());
    controller.add([1, 2, 3]);
    await expectLater(future, throwsA(isA<DownloadCancelledException>()));
    await controller.close();
  });

  test('رابط غير https يُرفض دون طلب', () async {
    await expectLater(
      downloader.download(Uri.parse('http://example.test/x'), expectedSha256: 'a' * 64, expectedSize: 1),
      failsWith(DownloadFailure.integrity),
    );
    expect(server.requests, isEmpty);
  });
}
