/// دفعة التحويل الآلي: قائمة الاختيار ← كتب في مجلد الإخراج + تقرير الدفعة (ARCHITECTURE §18.3).
/// لا ينشر شيئاً: يكتب في [outDir] فقط، والسجل يُلحق به ما قُبل أو أُحيل للمراجعة.
library;

import 'dart:convert';
import 'dart:io';

import 'auto_convert.dart';
import 'book_v2.dart';
import 'registry.dart';
import 'scope.dart';

class BookReport {
  BookReport(this.versionUri, this.title, this.decision, this.reasons, this.metrics,
      {this.id, this.version, this.file, this.generated = false, this.unknown = const {}});
  final String versionUri;
  final String title;
  final GateDecision decision;
  final List<String> reasons;
  final Map<String, num> metrics;
  final String? id;
  final int? version;
  final String? file;
  final bool generated;

  /// أنواع الوسم المجهول وأعدادها.
  final Map<String, int> unknown;

  Map<String, Object?> toJson() => {
        'version_uri': versionUri,
        'title': title,
        'decision': decision.name,
        if (id != null) 'id': id,
        if (version != null) 'version': version,
        if (file != null) 'file': file,
        'structure': generated ? 'generated' : 'source',
        'reasons': reasons,
        'metrics': metrics,
        if (unknown.isNotEmpty) 'unknown': {for (final k in unknown.keys.toList()..sort()) k: unknown[k]},
      };
}

class BatchReport {
  BatchReport(this.books);
  final List<BookReport> books;
  int count(GateDecision d) => books.where((b) => b.decision == d).length;

  /// الأسباب مجمّعة باسم البوابة (أول كلمة في السبب).
  Map<String, int> reasonCounts(GateDecision d) {
    final m = <String, int>{};
    for (final b in books.where((b) => b.decision == d)) {
      for (final r in b.reasons.map((r) => r.split(' ').first).toSet()) {
        m[r] = (m[r] ?? 0) + 1;
      }
    }
    return m;
  }

  /// مجموع أنواع الوسم المجهول في الدفعة: النوع ← (العدد، عدد الكتب)، الأكثر أولاً.
  List<(String, int, int)> unknownTally() {
    final n = <String, int>{}, books = <String, int>{};
    for (final x in this.books) {
      x.unknown.forEach((k, v) {
        n[k] = (n[k] ?? 0) + v;
        books[k] = (books[k] ?? 0) + 1;
      });
    }
    final keys = n.keys.toList()..sort((a, b) => n[b] != n[a] ? n[b]!.compareTo(n[a]!) : a.compareTo(b));
    return [for (final k in keys) (k, n[k]!, books[k]!)];
  }

  String toJson() => '${const JsonEncoder.withIndent('  ').convert({
        'accept': count(GateDecision.accept),
        'review': count(GateDecision.review),
        'reject': count(GateDecision.reject),
        'reasons': {for (final d in GateDecision.values) d.name: reasonCounts(d)},
        'unknown': [for (final (k, n, b) in unknownTally()) {'kind': k, 'count': n, 'books': b}],
        'books': [for (final b in books) b.toJson()],
      })}\n';

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# تقرير دفعة التحويل الآلي')
      ..writeln()
      ..writeln('| القرار | العدد |')
      ..writeln('|---|---|')
      ..writeln('| accept | ${count(GateDecision.accept)} |')
      ..writeln('| review | ${count(GateDecision.review)} |')
      ..writeln('| reject | ${count(GateDecision.reject)} |')
      ..writeln();
    for (final d in [GateDecision.reject, GateDecision.review]) {
      final rc = reasonCounts(d);
      if (rc.isEmpty) continue;
      b.writeln('## أسباب ${d.name}');
      for (final k in rc.keys.toList()..sort()) {
        b.writeln('- $k: ${rc[k]}');
      }
      b.writeln();
    }
    final tally = unknownTally();
    if (tally.isNotEmpty) {
      b
        ..writeln('## الوسم المجهول (النوع: العدد في عدد الكتب)')
        ..writeln();
      for (final (k, n, books) in tally) {
        b.writeln('- $k: $n في $books');
      }
      b.writeln();
    }
    b
      ..writeln('## الكتب')
      ..writeln()
      ..writeln('| القرار | المعرّف | النسخة | العنوان | الكلمات | الأبواب | الأسباب |')
      ..writeln('|---|---|---|---|---|---|---|');
    String cell(Object? s) => '$s'.replaceAll('|', '\\|').replaceAll('\n', ' ');
    for (final x in books) {
      b.writeln('| ${x.decision.name} | ${x.id ?? ''} | ${cell(x.versionUri)} | ${cell(x.title)} | '
          '${x.metrics['words'] ?? ''} | ${x.metrics['chapters'] ?? ''}${x.generated ? ' (مولّدة)' : ''} | '
          '${cell(x.reasons.join('؛ '))} |');
    }
    return b.toString();
  }
}

/// يحوّل دفعة [pickBatch] من [selection]. المصدر لكل نسخة
/// `<sourcesDir>/<version_uri>`؛ غيابه رفضٌ بسبب `fetch`. الكتاب المقبول أو المحال للمراجعة يأخذ
/// معرّفه من [registry] (ويُسجَّل إن كان جديداً) ويُكتب في [outDir] بالمسار المقسّم؛ إصدار سابق
/// في [outDir] بمحتوى مختلف يعطي إصداراً جديداً بـ `redirects` آلية.
BatchReport runAutoBatch({
  required List<SelectedBook> selection,
  required Directory sourcesDir,
  required Directory outDir,
  required Scope scope,
  required Registry registry,
  required String date,
  int? limit,
  bool spread = false,
}) {
  final todo = pickBatch(selection, limit, spread: spread);
  final reports = <BookReport>[];
  for (final s in todo) {
    final src = File('${sourcesDir.path}/${s.versionUri}');
    if (!src.existsSync()) {
      reports.add(BookReport(s.versionUri, s.titleAr, GateDecision.reject, ['fetch: المصدر غير موجود'], const {}));
      continue;
    }
    final id = registry.idOf(s.bookUri) ?? registry.nextId();
    final prev = _latest(outDir, id);
    final version = prev == null ? 1 : prev.$1 + 1;
    final out = autoConvert(
      meta: AutoMeta.fromSelected(s),
      sourceBytes: src.readAsBytesSync(),
      scope: scope,
      id: id,
      retrieved: date,
      version: version,
      previous: prev?.$2,
    );
    if (out.decision == GateDecision.reject) {
      reports.add(BookReport(s.versionUri, s.titleAr, out.decision, out.reasons, out.metrics,
          generated: out.generated, unknown: out.unknown));
      continue;
    }
    registry.assign(s.bookUri, s.versionUri);
    var v = version;
    if (prev != null && _sameContent(prev.$2, out.json!)) {
      v = prev.$1; // المحتوى نفسه: لا إصدار جديد.
    } else {
      // الصيغة 2: عضو gzip لكل باب وفهرس جانبي بالإزاحات (§18.4، §19).
      writeBookV2(outDir, autoBookRelativePath(id, v), jsonDecode(utf8.decode(out.json!)) as Map<String, Object?>);
    }
    reports.add(BookReport(s.versionUri, s.titleAr, out.decision, out.reasons, out.metrics,
        id: id, version: v, file: autoBookRelativePath(id, v), generated: out.generated, unknown: out.unknown));
  }
  return BatchReport(reports);
}

/// آخر إصدار للكتاب في مجلد الإخراج: (رقمه، JSON).
(int, Map<String, Object?>)? _latest(Directory outDir, String id) {
  final dir = Directory('${outDir.path}/${autoBookRelativePath(id, 1)}').parent;
  if (!dir.existsSync()) return null;
  final re = RegExp('^${RegExp.escape(id)}\\.v(\\d+)\\.json\\.gz\$');
  var best = 0;
  for (final f in dir.listSync().whereType<File>()) {
    final m = re.firstMatch(f.uri.pathSegments.last);
    if (m != null && int.parse(m[1]!) > best) best = int.parse(m[1]!);
  }
  if (best == 0) return null;
  final raw = gzip.decode(File('${dir.path}/$id.v$best.json.gz').readAsBytesSync());
  return (best, jsonDecode(utf8.decode(raw)) as Map<String, Object?>);
}

/// الكتاب الجديد يطابق السابق إن تطابقت الفصول (بلا النظر إلى version وredirects وremoved).
bool _sameContent(Map<String, Object?> prev, List<int> json) {
  final neu = jsonDecode(utf8.decode(json)) as Map<String, Object?>;
  return jsonEncode(prev['chapters']) == jsonEncode(neu['chapters']);
}
