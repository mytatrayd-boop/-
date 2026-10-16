/// سجل المعرّفات الثابتة `library/registry.tsv` (D31، ARCHITECTURE §18.3).
///
/// إلحاقي: `book_uri ← id ← أول إصدار ← URI النسخة`. لا يُحذف منه سطر ولا يُعاد معرّف؛
/// الكتب الجديدة `o` + 5 أرقام بالترتيب، والكتب الخمسة بمعرّفاتها (D33).
library;

import 'dart:io';

class RegistryEntry {
  RegistryEntry(this.bookUri, this.id, this.firstVersion, this.versionUri);
  final String bookUri;
  final String id;
  final int firstVersion;
  final String versionUri;

  String toLine() => '$bookUri\t$id\t$firstVersion\t$versionUri';
}

const registryHeader = 'book_uri\tid\tfirst_version\tversion_uri';
final _autoId = RegExp(r'^o(\d{5})$');

class Registry {
  Registry._(this.file, this.entries);

  /// الملف (null لسجل في الذاكرة في الاختبارات).
  final File? file;
  final List<RegistryEntry> entries;

  static Registry empty() => Registry._(null, []);

  static Registry load(File f) => parse(f.readAsStringSync(), file: f);

  static Registry parse(String text, {File? file}) {
    final lines = text.split('\n').where((l) => l.isNotEmpty && !l.startsWith('#')).toList();
    if (lines.isEmpty || lines.first != registryHeader) {
      throw const FormatException('registry.tsv: السطر الأول يجب أن يكون الترويسة: $registryHeader');
    }
    final r = Registry._(file, []);
    for (final (i, l) in lines.skip(1).indexed) {
      final c = l.split('\t');
      final v = c.length == 4 ? int.tryParse(c[2]) : null;
      if (v == null) throw FormatException('registry.tsv سطر ${i + 2}: أربعة أعمدة مطلوبة: «$l»');
      r._add(RegistryEntry(c[0], c[1], v, c[3]));
    }
    return r;
  }

  final Map<String, RegistryEntry> _byBook = {};
  final Set<String> _ids = {};

  void _add(RegistryEntry e) {
    if (_byBook.containsKey(e.bookUri)) throw FormatException('registry.tsv: كتاب مكرر ${e.bookUri}');
    if (!_ids.add(e.id)) throw FormatException('registry.tsv: معرّف مكرر ${e.id}');
    _byBook[e.bookUri] = e;
    entries.add(e);
  }

  String? idOf(String bookUri) => _byBook[bookUri]?.id;
  RegistryEntry? entryOf(String bookUri) => _byBook[bookUri];

  /// المعرّف التالي الذي سيُعطى لكتاب جديد (بلا تسجيل).
  String nextId() {
    var max = 0;
    for (final id in _ids) {
      final m = _autoId.firstMatch(id);
      if (m != null && int.parse(m[1]!) > max) max = int.parse(m[1]!);
    }
    return 'o${(max + 1).toString().padLeft(5, '0')}';
  }

  /// يعيد معرّف الكتاب، ويسجّله بمعرّف جديد إن لم يكن مسجلاً (إلحاقاً بآخر الملف).
  String assign(String bookUri, String versionUri, {int firstVersion = 1}) {
    final old = idOf(bookUri);
    if (old != null) return old;
    final e = RegistryEntry(bookUri, nextId(), firstVersion, versionUri);
    _add(e);
    file?.writeAsStringSync('${e.toLine()}\n', mode: FileMode.append, flush: true);
    return e.id;
  }
}
