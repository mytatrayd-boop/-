/// مدقق مكتبة الكتب: الفهرس وكل ملف كتاب (ARCHITECTURE §4 «قواعد إلزامية»).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'arabic_nfc.dart';
import 'book_builder.dart';
import 'catalog.dart';
import 'presentation_forms.dart';
import 'tts.dart';

class Issue {
  Issue(this.where, this.code, this.detail, {this.warning = false, this.paragraphId});
  final String where;
  final String code;
  final String detail;

  /// تحذير لا يُفشل التحقق، ويظهر في عيّنة المراجعة ليحكم عليه إنسان.
  final bool warning;
  final String? paragraphId;
  @override
  String toString() => '$where: ${warning ? 'تحذير ' : ''}[$code] $detail';
}

/// رموز تُعدّ تحذيراً لا خطأً: «(١٥)» و«(2)» قد تكون من نص المؤلف (عدد أو ترقيم)،
/// و«[...]» قد تكون إضافة محقق أو من النص (تظهر في العيّنة ليحكم عليها إنسان).
/// وكذلك المعقوف غير المتوازن، والرقم بعد قوس أو فاصلة («) 1»، «: 31،»)، ونمط «قاله ش»/«ش:»
/// (تعليقات محقق محتملة).
const warningCodes = {
  'footnote_paren_number',
  'square_bracket',
  'unbalanced_bracket',
  'number_after_punct',
  'editor_sh',
};

/// استثناءات مراجَعة يدوياً: معرّف فقرة/باب ← رموز مسموح بها فيه.
typedef ValidationExceptions = Map<String, Set<String>>;

/// أنماط تدل على حاشية أو بقايا ترميز ويكي/HTML داخل نص فقرة.
final Map<String, RegExp> footnotePatterns = {
  'footnote_bracket_number': RegExp(r'\[\s*[0-9٠-٩۰-۹]+\s*\]'),
  'footnote_guillemet_number': RegExp(r'«\s*[0-9٠-٩۰-۹]+\s*»'),
  'footnote_paren_number': RegExp(r'\(\s*[0-9٠-٩۰-۹]+\s*\)'),
  'footnote_superscript': RegExp('[¹²³⁰-⁹]'),
  'footnote_attached_number': RegExp(r'[ء-ي\u064B-\u0652][0-9٠-٩۰-۹]+(?=[\s.,،؛:!؟]|$)'),
  'footnote_asterisk': RegExp(r'\*'),
  'wiki_template': RegExp(r'\{\{|\}\}'),
  'wiki_link': RegExp(r'\[\[|\]\]'),
  'wiki_bold_italic': RegExp(r"''"),
  'html_tag': RegExp(r'</?[a-zA-Z][^>]*>'),
  'html_entity': RegExp(r'&(#\d+|#x[0-9a-fA-F]+|[a-zA-Z]+);'),
  'url': RegExp(r'https?://'),
  // «[1]» يغطيه footnote_bracket_number (خطأ)؛ هذا لما سواه.
  'square_bracket': RegExp(r'\[(?!\s*[0-9٠-٩۰-۹]+\s*\])[^\[\]]*\]'),
  'number_after_punct': RegExp(r'[)"،,؛;:]\s*[0-9٠-٩۰-۹]+(?=\s*[،,؛;.)]|\s*$|\s+[ء-ي])'),
  'editor_sh': RegExp(r'قاله ش(?![ء-ي])|(?<![ء-ي])ش\s*:|(?<![ء-ي])ش\s*\]'),
};

/// رقم الصفحة في الطبعة الأصلية (اختياري، من علامات OpenITI): مجلد وصفحة.
final pagePattern = RegExp(r'^V\d{2,}P\d{3,}$');

final _bookId = RegExp(r'^[a-z]{2,12}$');

/// معرّف كتاب الخط الآلي (ARCHITECTURE §18.5): `o00412`، ويقبل معرّفات الكتب الخمسة أيضاً.
/// يُستعمل مع `autoIds` فقط؛ تدقيق المكتبة الحالية (schema 1) لا يتغير.
final autoBookIdPattern = RegExp(r'^[a-z][a-z0-9]{1,11}$');
final _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _control = RegExp('[\u0000-\u0008\u000B-\u001F\u007F-\u009F\u200B\u200D-\u200F\u202A-\u202E\u2066-\u2069\uFEFF\uE000-\uF8FF]');

bool _nonEmptyString(Object? v) => v is String && v.trim().isNotEmpty;

/// يتحقق من بايتات JSON (غير مضغوطة) لكتاب.
List<Issue> validateBookBytes(
  List<int> bytes,
  String where, {
  String? expectedId,
  int? expectedVersion,
  ValidationExceptions exceptions = const {},
  bool autoIds = false,
}) {
  final issues = <Issue>[];
  if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
    issues.add(Issue(where, 'bom', 'الملف يبدأ بـ BOM'));
  }
  String text;
  try {
    text = const Utf8Decoder(allowMalformed: false).convert(bytes);
  } on FormatException catch (e) {
    return [...issues, Issue(where, 'utf8', 'ترميز UTF-8 غير صالح: ${e.message}')];
  }
  Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException catch (e) {
    return [...issues, Issue(where, 'json', 'JSON غير صالح: ${e.message}')];
  }
  if (json is! Map<String, Object?>) {
    return [...issues, Issue(where, 'json', 'الجذر ليس كائناً')];
  }
  issues.addAll(validateBook(json, where,
      expectedId: expectedId, expectedVersion: expectedVersion, exceptions: exceptions, autoIds: autoIds));
  return issues;
}

List<Issue> validateBook(
  Map<String, Object?> b,
  String where, {
  String? expectedId,
  int? expectedVersion,
  ValidationExceptions exceptions = const {},
  bool autoIds = false,
}) {
  final issues = <Issue>[];
  void text(String t, String id, {bool verse = false}) {
    final allowed = exceptions[id] ?? const <String>{};
    issues.addAll(checkParagraphText(t, verse: verse, where: '$where $id', id: id)
        .where((i) => !allowed.contains(i.code)));
  }

  void err(String code, String detail) => issues.add(Issue(where, code, detail));

  if (b['schema'] != 1) err('schema', 'schema يجب أن يكون 1');
  final id = b['id'];
  if (id is! String || !(autoIds ? autoBookIdPattern : _bookId).hasMatch(id)) {
    err('book_id', 'معرّف الكتاب غير صالح: $id');
    return issues;
  }
  if (expectedId != null && id != expectedId) err('book_id', 'المعرّف $id لا يطابق المسار $expectedId');
  final version = b['version'];
  if (version is! int || version < 1) err('version', 'version عدد صحيح ≥ 1 مطلوب');
  if (expectedVersion != null && version != expectedVersion) {
    err('version', 'الإصدار $version لا يطابق اسم الملف v$expectedVersion');
  }
  for (final k in ['title', 'author']) {
    final v = b[k];
    if (v is! Map || !_nonEmptyString(v['ar'])) {
      err('missing_field', '$k.ar مطلوب');
    } else {
      text(v['ar'] as String, '$k.ar');
    }
  }
  if (b['author_death_hijri'] is! int) err('missing_field', 'author_death_hijri عدد صحيح مطلوب');
  final src = b['source'];
  if (src is! Map) {
    err('missing_field', 'source مطلوب');
  } else {
    if (!_nonEmptyString(src['name'])) err('missing_field', 'source.name مطلوب');
    final url = src['url'];
    if (url is! String || !url.startsWith('https://')) err('missing_field', 'source.url (https) مطلوب');
    final r = src['retrieved'];
    if (r is! String || !_date.hasMatch(r)) err('missing_field', 'source.retrieved بصيغة YYYY-MM-DD مطلوب');
  }
  if (!_nonEmptyString(b['license'])) err('missing_field', 'license مطلوب');
  if (!_nonEmptyString(b['removed'])) err('missing_field', 'removed مطلوب');

  final chapters = b['chapters'];
  if (chapters is! List || chapters.isEmpty) {
    err('missing_field', 'chapters قائمة غير فارغة مطلوبة');
    return issues;
  }

  final seen = <String>{};
  final allParagraphIds = <String>{};
  // عرض الأرقام ثابت لكل الكتب: 3 للباب و5 للفقرة (D17).
  final chapterRe = RegExp('^${RegExp.escape(id)}-b(\\d{${autoIds ? '3,4' : '3'}})\$');
  int? prevLevel;
  for (var ci = 0; ci < chapters.length; ci++) {
    final c = chapters[ci];
    if (c is! Map) {
      err('chapter', 'الباب $ci ليس كائناً');
      continue;
    }
    final cid = c['id'];
    final cm = cid is String ? chapterRe.firstMatch(cid) : null;
    if (cm == null) {
      err('chapter_id', 'معرّف باب غير صالح: $cid');
      continue;
    }
    cid as String;
    if (!seen.add(cid)) err('duplicate_id', 'معرّف مكرر: $cid');
    if (!_nonEmptyString(c['title'])) {
      err('chapter_title', 'عنوان فارغ: $cid');
    } else {
      text(c['title'] as String, cid);
    }
    final level = c['level'];
    if (level is! int || level < 1 || level > 3) {
      err('level', 'level بين 1 و3: $cid');
    } else {
      if (prevLevel == null && level != 1) err('level', 'أول باب يجب أن يكون level 1: $cid');
      if (prevLevel != null && level > prevLevel + 1) err('level', 'قفزة في المستوى: $cid');
      prevLevel = level;
    }
    final paras = c['paragraphs'];
    if (paras is! List) {
      err('missing_field', 'paragraphs مطلوبة: $cid');
      continue;
    }
    if (paras.isEmpty) {
      final next = ci + 1 < chapters.length ? chapters[ci + 1] : null;
      final nextLevel = next is Map ? next['level'] : null;
      if (nextLevel is! int || level is! int || nextLevel <= level) {
        err('empty_chapter', 'باب بلا فقرات ولا أبواب فرعية: $cid');
      }
    }
    final pRe = RegExp('^${RegExp.escape(cid)}-p(\\d{5})\$');
    for (final p in paras) {
      if (p is! Map) {
        err('paragraph', 'فقرة ليست كائناً في $cid');
        continue;
      }
      final pid = p['id'];
      final pm = pid is String ? pRe.firstMatch(pid) : null;
      if (pm == null) {
        err('paragraph_id', 'معرّف فقرة غير صالح: $pid');
        continue;
      }
      pid as String;
      if (!seen.add(pid)) err('duplicate_id', 'معرّف مكرر: $pid');
      allParagraphIds.add(pid);
      final kind = p['kind'];
      if (kind != null && kind != 'verse') err('kind', 'kind غير معروف ($kind): $pid');
      final t = p['text'];
      if (t is! String || t.trim().isEmpty) {
        err('empty_text', 'فقرة فارغة: $pid');
        continue;
      }
      text(t, pid, verse: kind == 'verse');
      // نص النطق (اختياري): حروفه حروف الأصل نفسها، لا يزيد إلا التشكيل.
      final tts = p['tts'];
      if (tts != null) {
        if (tts is! String || tts.trim().isEmpty) {
          err('tts', 'tts نص غير فارغ إن وُجد: $pid');
        } else if (!ttsMatchesText(tts, t)) {
          err('tts', 'tts بعد حذف التشكيل لا يطابق النص: $pid');
        } else if (!isArabicNfc(tts)) {
          err('tts', 'tts ليس NFC: $pid');
        }
      }
      final page = p['page'];
      if (page != null && (page is! String || !pagePattern.hasMatch(page))) {
        err('page', 'page بصيغة V01P009 إن وُجد: $pid');
      }
    }
  }

  final redirects = b['redirects'];
  if (redirects != null) {
    if (redirects is! Map) {
      err('redirects', 'redirects يجب أن يكون كائناً');
    } else {
      redirects.forEach((k, v) {
        if (allParagraphIds.contains(k)) err('redirects', 'المعرّف المحوَّل ما زال موجوداً: $k');
        if (!allParagraphIds.contains(v)) err('redirects', 'وجهة تحويل غير موجودة: $k → $v');
      });
    }
  }
  return issues;
}

/// فحوص نص فقرة واحدة.
List<Issue> checkParagraphText(String t, {required bool verse, required String where, String? id}) {
  final issues = <Issue>[];
  void err(String code, String detail) =>
      issues.add(Issue(where, code, detail, warning: warningCodes.contains(code), paragraphId: id));
  if (t != t.trim()) err('whitespace', 'مسافات في الطرفين');
  if (_control.hasMatch(t)) err('control_char', 'محرف تحكم أو تنسيق غير مرئي');
  if (!verse && (t.contains('\n') || t.contains('\t'))) err('control_char', '\\n أو \\t في نثر');
  if (verse && t.contains('\r')) err('control_char', '\\r في شعر');
  if (unsupportedMarks(t).isNotEmpty) err('nfc', 'علامات دمج غير عربية');
  final pf = forbiddenArabicChars.firstMatch(t);
  if (pf != null) {
    err('presentation_form',
        'شكل عرض عربي أو حرف غير قياسي U+${pf[0]!.codeUnitAt(0).toRadixString(16).toUpperCase()}');
  }
  if (!isArabicNfc(t)) err('nfc', 'النص ليس NFC');
  if ('['.allMatches(t).length != ']'.allMatches(t).length) {
    err('unbalanced_bracket', 'معقوف غير متوازن داخل الفقرة');
  }
  for (final e in footnotePatterns.entries) {
    final m = e.value.firstMatch(t);
    if (m != null) err(e.key, 'علامة حاشية/ترميز: «${m[0]}»');
  }
  return issues;
}

class LibraryReport {
  LibraryReport(this.issues, this.books, this.paragraphs);
  final List<Issue> issues;
  final int books;
  final int paragraphs;
  List<Issue> get errors => issues.where((i) => !i.warning).toList();
  List<Issue> get warnings => issues.where((i) => i.warning).toList();
  bool get ok => errors.isEmpty;
}

/// يتحقق من `catalog.json` وكل ملفات `books/` ومطابقة sha256 والأحجام.
/// [exceptions] لكل كتاب؛ إن غابت تُقرأ من `tools/recipes/*.json` (validation_exceptions).
LibraryReport validateLibrary(Directory root, {Map<String, ValidationExceptions>? exceptions}) {
  exceptions ??= loadRecipeExceptions(Directory('${root.path}/tools/recipes'));
  final issues = <Issue>[];
  // معرّفات الفقرات وredirects لكل كتاب وإصدار، لفحص الاستمرارية بين الإصدارات.
  final idsByVersion = <String, Map<int, ({Set<String> ids, Set<String> redirected})>>{};
  var books = 0, paragraphs = 0;
  final catFile = File('${root.path}/catalog.json');
  final listed = <String>{};
  if (!catFile.existsSync()) {
    issues.add(Issue('catalog.json', 'missing', 'catalog.json غير موجود'));
  } else {
    final bytes = catFile.readAsBytesSync();
    Map<String, Object?>? cat;
    try {
      cat = jsonDecode(const Utf8Decoder(allowMalformed: false).convert(bytes)) as Map<String, Object?>;
    } on Object catch (e) {
      issues.add(Issue('catalog.json', 'json', 'غير صالح: $e'));
    }
    if (cat != null) {
      void err(String code, String d) => issues.add(Issue('catalog.json', code, d));
      if (cat['schema'] != 1) err('schema', 'schema يجب أن يكون 1');
      if (cat['catalog_version'] is! int) err('missing_field', 'catalog_version مطلوب');
      final u = cat['updated'];
      if (u is! String || !_date.hasMatch(u)) err('missing_field', 'updated بصيغة YYYY-MM-DD مطلوب');
      final list = cat['books'];
      if (list is! List) {
        err('missing_field', 'books قائمة مطلوبة');
      } else {
        for (final e in list) {
          if (e is! Map<String, Object?>) {
            err('entry', 'عنصر ليس كائناً');
            continue;
          }
          final id = e['id'];
          if (id is! String || !_bookId.hasMatch(id)) {
            err('book_id', 'معرّف غير صالح: $id');
            continue;
          }
          if (!listed.add(id)) err('duplicate_id', 'كتاب مكرر: $id');
          final w = 'catalog.json[$id]';
          for (final k in ['title', 'author']) {
            final v = e[k];
            if (v is! Map || !_nonEmptyString(v['ar']) || !_nonEmptyString(v['en'])) {
              issues.add(Issue(w, 'missing_field', '$k.ar و$k.en مطلوبان'));
            }
          }
          for (final k in ['author_death_hijri', 'version', 'size_bytes', 'uncompressed_bytes', 'paragraph_count']) {
            if (e[k] is! int) issues.add(Issue(w, 'missing_field', '$k عدد صحيح مطلوب'));
          }
          if (!const ['full', 'partial', 'none'].contains(e['diacritics'])) {
            issues.add(Issue(w, 'missing_field', 'diacritics: full|partial|none'));
          }
          final s = e['source'];
          if (s is! Map || !_nonEmptyString(s['name']) || s['url'] is! String || !(s['url'] as String).startsWith('https://')) {
            issues.add(Issue(w, 'missing_field', 'source.name وsource.url (https) مطلوبان'));
          }
          if (!_nonEmptyString(e['license'])) issues.add(Issue(w, 'missing_field', 'license مطلوب'));
          final version = e['version'];
          final rel = e['file'];
          if (version is! int || rel != bookRelativePath(id, version)) {
            issues.add(Issue(w, 'file', 'file يجب أن يكون ${version is int ? bookRelativePath(id, version) : '?'}'));
            continue;
          }
          final f = File('${root.path}/$rel');
          if (!f.existsSync()) {
            issues.add(Issue(w, 'file', 'الملف غير موجود: $rel'));
            continue;
          }
          final gz = f.readAsBytesSync();
          if (sha256.convert(gz).toString() != e['sha256']) issues.add(Issue(w, 'sha256', 'sha256 لا يطابق الملف'));
          if (gz.length != e['size_bytes']) issues.add(Issue(w, 'size', 'size_bytes لا يطابق'));
          try {
            final raw = gzip.decode(gz);
            if (raw.length != e['uncompressed_bytes']) issues.add(Issue(w, 'size', 'uncompressed_bytes لا يطابق'));
            final book = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
            final expected = catalogEntry(book, gz, raw.length);
            if (expected['paragraph_count'] != e['paragraph_count']) {
              issues.add(Issue(w, 'paragraph_count', 'paragraph_count لا يطابق (${expected['paragraph_count']})'));
            }
          } on Object catch (ex) {
            issues.add(Issue(w, 'gzip', 'تعذّر فك الملف: $ex'));
          }
        }
      }
    }
  }

  // كل ملفات الكتب (كل الإصدارات) تُفحص، والأحدث يجب أن يكون في الفهرس.
  final booksDir = Directory('${root.path}/books');
  if (booksDir.existsSync()) {
    final files = booksDir.listSync(recursive: true).whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final rel = f.path.substring(root.path.length).replaceFirst(RegExp(r'^/+'), '');
      final m = RegExp(r'^books/([a-z]{2,12})/\1\.v(\d+)\.json\.gz$').firstMatch(rel);
      if (m == null) {
        issues.add(Issue(rel, 'file_name', 'اسم/مسار غير متوقع (books/<id>/<id>.v<N>.json.gz)'));
        continue;
      }
      List<int> raw;
      try {
        raw = gzip.decode(f.readAsBytesSync());
      } on Object catch (e) {
        issues.add(Issue(rel, 'gzip', 'تعذّر فك الضغط: $e'));
        continue;
      }
      final bi = validateBookBytes(raw, rel,
          expectedId: m[1], expectedVersion: int.parse(m[2]!), exceptions: exceptions[m[1]] ?? const {});
      issues.addAll(bi);
      books++;
      try {
        final book = jsonDecode(utf8.decode(raw)) as Map<String, Object?>;
        final ids = paragraphsOf(book).map((p) => p['id']! as String).toSet();
        paragraphs += ids.length;
        final red = ((book['redirects'] as Map?) ?? const {}).keys.cast<String>().toSet();
        (idsByVersion[m[1]!] ??= {})[int.parse(m[2]!)] = (ids: ids, redirected: red);
      } on Object {
        // سُجّل الخطأ أعلاه.
      }
    }
    // ثبات المعرّفات عبر كل الإصدارات السابقة لا السابق مباشرة فقط:
    // - lost_id: معرّف ظهر في أي إصدار سابق (فقرة أو مفتاح تحويل) وليس في N ولا في redirects الخاصة بـ N.
    // - reused_id: معرّف صار فقرة في N بعد أن كان مفتاح تحويل في إصدار سابق (لا يُعاد استخدام معرّف).
    idsByVersion.forEach((id, versions) {
      final ordered = versions.keys.toList()..sort();
      final everIds = <String>{};
      final everRedirected = <String>{};
      for (final v in ordered) {
        final cur = versions[v]!;
        final where = 'books/$id/$id.v$v.json.gz';
        final lost = everIds.union(everRedirected).difference(cur.ids).difference(cur.redirected).toList()
          ..sort();
        if (lost.isNotEmpty) {
          issues.add(Issue(where, 'lost_id',
              '${lost.length} معرّف من إصدار سابق غير موجود ولا في redirects: ${lost.take(10).join('، ')}'));
        }
        final reused = cur.ids.intersection(everRedirected).toList()..sort();
        if (reused.isNotEmpty) {
          issues.add(Issue(where, 'reused_id',
              '${reused.length} معرّف محوَّل سابقاً أُعيد استخدامه فقرة: ${reused.take(10).join('، ')}'));
        }
        everIds.addAll(cur.ids);
        everRedirected.addAll(cur.redirected);
      }
    });
    for (final f in latestBookFiles(root)) {
      final id = f.uri.pathSegments.last.split('.').first;
      if (!listed.contains(id) && catFile.existsSync()) {
        issues.add(Issue('catalog.json', 'not_listed', 'الكتاب $id غير مدرج في الفهرس'));
      }
    }
  }
  return LibraryReport(issues, books, paragraphs);
}

/// يقرأ validation_exceptions من وصفات الكتب: {كتاب: {معرّف: رموز}}.
Map<String, ValidationExceptions> loadRecipeExceptions(Directory recipesDir) {
  final out = <String, ValidationExceptions>{};
  if (!recipesDir.existsSync()) return out;
  final files = recipesDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    final ex = j['validation_exceptions'] as Map?;
    if (j['id'] is String && ex != null) {
      out[j['id']! as String] = {
        for (final e in ex.entries) e.key as String: {...(e.value as List).cast<String>()},
      };
    }
  }
  return out;
}
