import 'dart:convert';
import 'dart:io';

import 'package:durur/l10n/app_localizations.dart';
import 'package:durur/src/app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart_source.dart';

/// الميزة 10 (SPEC معيار 3–4): فحص آلي للكود نفسه.
/// - كل نص يراه المستخدم في `lib/l10n/app_ar.arb`: لا سلسلة عربية في طبقة
///   الواجهة، ولا سلسلة فيها حروف (عربية أو لاتينية) في موضع ظاهر
///   (Text، Semantics، tooltip، hint…) في أي مكان من lib/.
/// - كل مفاتيح ARB مستخدمة.
/// - العربية وحدها لغة التطبيق، ولا اتجاه يسار-يمين ثابت في الواجهة.
/// (النص الظاهر فعلياً في كل شاشة يُفحص في test/offline/.)
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.startsWith('lib/l10n/'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  /// طبقة الواجهة: لا يُكتب فيها أي نص عربي (كله من ARB).
  bool isUiLayer(String path) =>
      path == 'lib/main.dart' ||
      path == 'lib/src/app.dart' ||
      path.startsWith('lib/src/features/') ||
      path.startsWith('lib/src/routing/') ||
      path.startsWith('lib/src/theme/') ||
      path.startsWith('lib/src/formatting/') ||
      path == 'lib/src/notifications/notification_content.dart' ||
      path == 'lib/src/notifications/local_notification_scheduler.dart';

  final arabic = RegExp('[ء-ي]');
  final letters = RegExp('[A-Za-zء-ي]');

  test('المُحلّل اللفظي يجد السلاسل ويتجاهل التعليقات', () {
    const sample = '''
// تعليق 'ليس سلسلة'
/* 'ولا هذا' */
final a = 'نص';
final b = "x \${'داخلي'} y";
final c = r'\\d+';
final d = \'\'\'متعدد
الأسطر\'\'\';
''';
    final found = dartStrings(sample).map((s) => s.value).toList();
    expect(found, ['نص', "x \${'داخلي'} y", r'\d+', 'متعدد\nالأسطر']);
  });

  test('طبقة الواجهة بلا أي سلسلة عربية مكتوبة في الكود', () {
    final violations = <String>[];
    for (final f in dartFiles.where((f) => isUiLayer(f.path))) {
      final src = f.readAsStringSync();
      for (final s in dartStrings(src)) {
        // أرقام الإدخال الهندية في RegExp ليست نصاً ظاهراً (digits.dart).
        if (s.value == '[٠-٩]') continue;
        if (arabic.hasMatch(s.value)) {
          violations.add('${f.path}:${s.line}: ${s.value}');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('لا سلسلة فيها حروف في موضع ظاهر للمستخدم في أي مكان من lib/', () {
    // ما قبل السلسلة مباشرة: وسيط موضعي لـ Text أو وسيط مسمّى ظاهر.
    final visible = RegExp(
      r'(?:\b(?:Text|SelectableText|Tooltip|TextSpan|SnackBar|Semantics)'
      r'(?:\.rich)?\s*\(\s*|'
      r'\b(?:label|tooltip|message|semanticLabel|semanticsLabel|hintText|'
      r'labelText|helperText|errorText|counterText|prefixText|suffixText|'
      r'hint|value|increasedValue|decreasedValue|onTapHint|onLongPressHint|'
      r'text|title|subtitle|content|applicationName|applicationLegalese|'
      r'restorationScopeId)\s*:\s*)$',
    );
    final violations = <String>[];
    for (final f in dartFiles) {
      final src = f.readAsStringSync();
      for (final s in dartStrings(src)) {
        final before = src.substring(0, s.offset);
        final tail = before.substring(
          before.length > 80 ? before.length - 80 : 0,
        );
        if (!visible.hasMatch(tail)) continue;
        final withoutInterpolation = s.value.replaceAll(
          RegExp(r'\$\{[^}]*\}|\$[A-Za-z_]\w*'),
          '',
        );
        if (letters.hasMatch(withoutInterpolation)) {
          violations.add('${f.path}:${s.line}: ${s.value}');
        }
      }
    }
    expect(violations, isEmpty);
  });

  group('ARB', () {
    final arb =
        jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
            as Map<String, dynamic>;
    final keys = arb.keys.where((k) => !k.startsWith('@')).toList();
    final source = dartFiles.map((f) => f.readAsStringSync()).join('\n');

    /// مفاتيح موجودة عمداً بلا استعمال حالي، مع السبب.
    const reserved = {
      // DESIGN §7.7: «wheel.a11y.date يبقى للجملة الكاملة حيث لا يوجد فصل
      // label/value». الدائرة تستخدم label/value منفصلين؛ القالب محفوظ بقرار
      // التصميم (مُبلَّغ للمصمم في STATUS.md).
      'wheelA11yDate',
    };

    test('كل مفاتيح ARB مستخدمة في lib/', () {
      final unused = [
        for (final k in keys)
          if (!reserved.contains(k) &&
              !RegExp('\\b${RegExp.escape(k)}\\b').hasMatch(source))
            k,
      ];
      expect(unused, isEmpty);
      // ولا مفتاح محجوز صار مستخدماً أو حُذف دون تحديث القائمة.
      for (final k in reserved) {
        expect(keys, contains(k));
      }
    });

    test('كل مفتاح له وصف، وقيمته غير فارغة', () {
      for (final k in keys) {
        expect((arb[k] as String).trim(), isNotEmpty, reason: k);
        expect(
          (arb['@$k'] as Map?)?['description'],
          isA<String>(),
          reason: k,
        );
      }
    });

    test('لا نص لاتيني ظاهر في ARB إلا إسناد GeoNames والرخصة وvan Gent', () {
      // يُحذف ما ليس نصاً ظاهراً: أسماء المتغيرات وصيغ ICU (select/plural
      // وحالاتها).
      String visibleText(String v) => v
          .replaceAll(RegExp(r'\{\s*\w+\s*,\s*(?:select|plural)\s*,'), '{')
          .replaceAll(RegExp(r'\b(?:other|few|many|zero|one|two)\{'), '{')
          .replaceAll(RegExp(r'\b[a-z_0-9]+\{'), '{')
          .replaceAll(RegExp(r'=\d+\{'), '{')
          .replaceAll(RegExp(r'\{\s*\w+\s*\}'), '')
          .replaceAll(RegExp(r'\b(?:SA|KW|AE|OM|QA|BH)\{'), '{');
      const attribution = [
        'GeoNames',
        'geonames.org',
        'CC BY 4.0',
        'R. H. van Gent',
      ];
      final latin = <String>[];
      for (final k in keys) {
        var text = visibleText(arb[k] as String);
        for (final a in attribution) {
          text = text.replaceAll(a, '');
        }
        if (RegExp('[A-Za-z]').hasMatch(text)) latin.add('$k: ${arb[k]}');
      }
      expect(latin, isEmpty);
    });
  });

  group('العربية وحدها، ومن اليمين لليسار', () {
    test('اللغة الوحيدة المدعومة العربية (التطبيق والملفات المولّدة)', () {
      expect(AppLocalizations.supportedLocales, [const Locale('ar')]);
      expect(DururApp.arabic, const Locale('ar'));
      final arbs = Directory('lib/l10n')
          .listSync()
          .map((e) => e.path)
          .where((p) => p.endsWith('.arb'))
          .toList();
      expect(arbs, ['lib/l10n/app_ar.arb']);
    });

    test('لا اتجاه يسار-يمين ثابت في الواجهة (start/end فقط)', () {
      final banned = RegExp(
        r'TextDirection\.ltr|EdgeInsets\.only\([^)]*\b(?:left|right)\s*:|'
        r'EdgeInsets\.fromLTRB|BorderRadius\.only\([^)]*(?:Left|Right)\s*:|'
        r'Alignment\.(?:centerLeft|centerRight|topLeft|topRight|bottomLeft|'
        r'bottomRight)|Positioned\([^)]*\b(?:left|right)\s*:|'
        r'TextAlign\.(?:left|right)\b',
      );
      final violations = <String>[];
      for (final f in dartFiles) {
        final src = stripComments(f.readAsStringSync());
        for (final m in banned.allMatches(src)) {
          violations.add('${f.path}: ${m[0]}');
        }
      }
      expect(violations, isEmpty);
    });
  });
}

