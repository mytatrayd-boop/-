/// فهرس البحث FTS5 للفقرات (ARCHITECTURE §5–6): جدول بلا محتوى، عمودا
/// `norm` (النص المطبَّع) و`stem` (جذوعه)، و`rowid` = rowid الفقرة. الكتابة
/// فيه داخل معاملات الاستيراد والحذف والترحيل فقط. Dart صافٍ.
library;

import 'package:sqlite3/sqlite3.dart';

import '../text/arabic_normalizer.dart';
import '../text/light_stemmer.dart';

const createSearchIndexSql =
    'CREATE VIRTUAL TABLE paragraphs_fts USING fts5('
    "norm, stem, content='', contentless_delete=1, "
    "tokenize='unicode61 remove_diacritics 0')";

/// قيمتا العمودين لنص فقرة.
({String norm, String stem}) searchColumns(String text) {
  final norm = normalizeArabic(text);
  return (norm: norm, stem: stemNormalized(norm));
}

/// يُعدّ إدراج صف فهرس؛ على المستدعي إغلاقه.
PreparedStatement prepareIndexInsert(Database db) => db.prepare(
  'INSERT INTO paragraphs_fts (rowid, norm, stem) VALUES (?, ?, ?)',
);

void indexParagraph(PreparedStatement insert, int rowid, String text) {
  final c = searchColumns(text);
  insert.execute([rowid, c.norm, c.stem]);
}

/// يحذف صفوف فهرس فقرات [bookId]. يُستدعى قبل حذف الفقرات نفسها، لأن
/// الجدول بلا محتوى لا يتبع الحذف المتسلسل ورقم الصف قد يُعاد استخدامه.
void unindexBook(Database db, String bookId) => db.execute(
  'DELETE FROM paragraphs_fts WHERE rowid IN '
  '(SELECT rowid FROM paragraphs WHERE book_id = ?)',
  [bookId],
);

/// يفهرس كل الفقرات الموجودة (ترحيل الكتب المثبّتة قبل الميزة 4).
void indexAllParagraphs(Database db) {
  final insert = prepareIndexInsert(db);
  final select = db.prepare('SELECT rowid, text FROM paragraphs');
  try {
    final rows = select.selectCursor();
    while (rows.moveNext()) {
      final r = rows.current;
      indexParagraph(insert, r['rowid'] as int, r['text'] as String);
    }
  } finally {
    select.close();
    insert.close();
  }
}
