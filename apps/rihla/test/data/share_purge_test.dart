import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:rihla/data/share/share_service.dart';

void main() {
  test('purgeStaleShareFiles deletes only files older than a day', () async {
    final dir = await Directory.systemTemp.createTemp('rihla_purge');
    addTearDown(() => dir.delete(recursive: true));
    final old = File(p.join(dir.path, 'old.gpx'))..writeAsStringSync('a');
    final fresh = File(p.join(dir.path, 'fresh.gpx'))..writeAsStringSync('b');
    old.setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));

    final n = await purgeStaleShareFiles(dir);

    expect(n, 1);
    expect(old.existsSync(), isFalse);
    expect(fresh.existsSync(), isTrue);
  });

  test('purgeStaleShareFiles tolerates a missing directory', () async {
    final n = await purgeStaleShareFiles(Directory('/nonexistent_rihla_x'));
    expect(n, 0);
  });
}
