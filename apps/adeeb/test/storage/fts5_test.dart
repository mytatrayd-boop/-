import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('SQLite المضمّن يدعم FTS5 (ARCHITECTURE §13 T1)', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final options = db
        .select('PRAGMA compile_options')
        .map((r) => r.values.first as String)
        .toList();
    expect(options, contains('ENABLE_FTS5'));
    db.execute("CREATE VIRTUAL TABLE t USING fts5(norm, content='', contentless_delete=1)");
  });
}
