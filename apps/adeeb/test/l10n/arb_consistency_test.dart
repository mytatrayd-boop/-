import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// الترجمة الإنجليزية مكتملة: نفس المفاتيح ونفس المتغيرات في الملفين، ولا
/// قيمة فارغة، ولا نص عربي في الإنجليزية إلا أمثلة نص الكتب وأسماء اللغات.
void main() {
  Map<String, Object?> load(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
          as Map<String, Object?>;

  final ar = load('ar');
  final en = load('en');
  Set<String> keys(Map<String, Object?> m) =>
      m.keys.where((k) => !k.startsWith('@')).toSet();
  // المتغيرات المعلنة في القالب العربي (@key.placeholders).
  Set<String> declared(String key) {
    final meta = ar['@$key'];
    if (meta is! Map || meta['placeholders'] is! Map) return const {};
    return (meta['placeholders'] as Map).keys.cast<String>().toSet();
  }

  test('المفاتيح متطابقة في app_ar.arb وapp_en.arb', () {
    expect(keys(en).difference(keys(ar)), isEmpty, reason: 'زائد في en');
    expect(keys(ar).difference(keys(en)), isEmpty, reason: 'ناقص في en');
  });

  test('المتغيرات نفسها في كل نص، ولا قيم فارغة', () {
    for (final k in keys(ar)) {
      for (final p in declared(k)) {
        expect(ar[k], contains('{$p'), reason: '$k: $p في ar');
        expect(en[k], contains('{$p'), reason: '$k: $p في en');
      }
      expect((ar[k]! as String).trim(), isNotEmpty, reason: k);
      expect((en[k]! as String).trim(), isNotEmpty, reason: k);
    }
  });

  test('لا نص عربي في الإنجليزية إلا المسموح', () {
    // أمثلة من نص الكتب (تبقى عربية دائماً)، واسم العربية بلغتها.
    const allowed = {
      'textPreview',
      'searchSuggestionWords',
      'audioSample',
      'askHint',
      'askExamples',
      'languageArabic',
    };
    final arabic = RegExp('[؀-ۿ]');
    final offenders = [
      for (final k in keys(en))
        if (!allowed.contains(k) && arabic.hasMatch(en[k]! as String)) k,
    ];
    expect(offenders, isEmpty);
  });
}
