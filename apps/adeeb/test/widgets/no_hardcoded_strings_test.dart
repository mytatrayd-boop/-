import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// لا نصوص واجهة مكتوبة داخل الكود (CLAUDE.md): كل نص في ARB.
void main() {
  test('lib/ بلا نصوص واجهة ثابتة', () {
    final uiLiteral = RegExp(
      r'''(\b(Text|Tooltip|SnackBar)\(\s*['"])|((label|tooltip|semanticLabel|hintText|labelText|title):\s*['"])''',
    );
    final offenders = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('/l10n/')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (uiLiteral.hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
