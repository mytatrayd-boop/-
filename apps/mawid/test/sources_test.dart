import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/model/programs.dart';

void main() {
  test('every date has an official https source (Google Play misleading-claims policy)', () {
    for (final p in programs) {
      expect(p.source, isNotEmpty, reason: p.name);
      expect(Uri.parse(p.sourceUrl).scheme, 'https', reason: p.name);
    }
    expect(holidaySources, isNotEmpty);
  });
}
