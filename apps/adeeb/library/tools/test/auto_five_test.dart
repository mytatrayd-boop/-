// الكتب الخمسة بالوضع الآلي (قبول 6.2): تجتاز البوابات وتطابق النسخ اليدوية في ≥ 98% من الفقرات.
// يحتاج المصادر المخزّنة `.cache/<id>/openiti.txt` (bin/fetch_openiti.dart)؛ يُتخطّى بدونها.
import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

void main() {
  final scope = Scope.load(File('scope.yaml'));
  for (final id in ['kalila', 'bayan', 'uyun', 'kamil', 'adab']) {
    final src = File('.cache/$id/openiti.txt');
    test('$id بالوضع الآلي', () {
      final recipe = OpenitiRecipe.load(File('recipes/$id.json'));
      final manual = jsonDecode(utf8.decode(gzip.decode(File('../books/$id/$id.v1.json.gz').readAsBytesSync())))
          as Map<String, Object?>;
      final out = autoConvert(
        meta: AutoMeta(
          bookUri: bookUriOf(recipe.versionUri),
          versionUri: recipe.versionUri,
          titleAr: recipe.titleAr,
          titleEn: recipe.titleEn,
          authorAr: recipe.authorAr,
          authorEn: recipe.authorEn,
          deathHijri: recipe.authorDeathHijri,
          localPath: recipe.path,
        ),
        sourceBytes: src.readAsBytesSync(),
        scope: scope,
        id: id,
        retrieved: '2026-10-16',
      );
      final auto = <String, int>{};
      for (final c in out.result!.chapters) {
        for (final p in (c['paragraphs']! as List).cast<Map<String, Object?>>()) {
          auto.update(p['text']! as String, (n) => n + 1, ifAbsent: () => 1);
        }
      }
      var total = 0, matched = 0;
      for (final c in (manual['chapters']! as List).cast<Map<String, Object?>>()) {
        for (final p in (c['paragraphs']! as List).cast<Map<String, Object?>>()) {
          total++;
          final t = p['text']! as String;
          if ((auto[t] ?? 0) > 0) {
            matched++;
            auto[t] = auto[t]! - 1;
          }
        }
      }
      final ratio = matched / total;
      print('$id: ${out.decision.name} ${out.reasons} ${out.metrics} match=${(ratio * 100).toStringAsFixed(2)}%');
      expect(out.decision, GateDecision.accept, reason: out.reasons.join('; '));
      expect(ratio, greaterThanOrEqualTo(0.98));
    }, skip: src.existsSync() ? false : 'المصدر غير مخزّن: ${src.path}');
  }
}
