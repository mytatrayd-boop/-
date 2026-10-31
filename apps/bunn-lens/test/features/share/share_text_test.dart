import 'package:bunn_lens/domain/cafe.dart';
import 'package:bunn_lens/domain/scan.dart';
import 'package:bunn_lens/app/score_label.dart';
import 'package:bunn_lens/features/share/share_text.dart';
import 'package:bunn_lens/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Scan _scan({String? roaster, Cafe? cafe, int score = 82}) => Scan(
      id: 1,
      type: ScanType.bean,
      score: score,
      notes: const ['أ', 'ب', 'ج'],
      imagePath: '/x.jpg',
      createdAt: DateTime(2026, 1, 1),
      roasterName: roaster,
      cafe: cafe,
    );

Cafe _cafe({bool loc = true}) =>
    Cafe(id: 1, name: 'مقهى الورد', savedAt: DateTime(2026), lat: loc ? 24.7 : null, lng: loc ? 46.6 : null);

void main() {
  late AppLocalizations ar;
  late AppLocalizations en;
  setUp(() async {
    ar = await AppLocalizations.delegate.load(const Locale('ar'));
    en = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('محمصة + مقهى بموقع: التقييم واسم المقهى ورابط الخرائط', () {
    final t = buildShareText(ar, _scan(roaster: 'سبيشل', cafe: _cafe()));
    final lines = t.split('\n');
    expect(lines[0], 'قيّمت المحمصة سبيشل بعدسة البن: جيد (تقديري)');
    expect(lines[1], 'المقهى: مقهى الورد');
    expect(lines[2], 'https://www.google.com/maps/search/?api=1&query=24.7,46.6');
  });

  test('مقهى بلا محمصة: الاسم في الجملة الأولى بلا تكرار', () {
    final t = buildShareText(ar, _scan(cafe: _cafe()));
    expect(t.split('\n').first, 'قيّمت المقهى مقهى الورد بعدسة البن: جيد (تقديري)');
    expect(t.contains('المقهى: مقهى الورد'), isFalse);
    expect(t, contains('google.com/maps'));
  });

  test('مقهى بلا موقع: الاسم بلا رابط', () {
    final t = buildShareText(ar, _scan(roaster: 'س', cafe: _cafe(loc: false)));
    expect(t, contains('مقهى الورد'));
    expect(t, isNot(contains('http')));
  });

  test('بلا مقهى ولا محمصة: النوع فقط', () {
    final t = buildShareText(ar, _scan());
    expect(t, 'قيّمت بن بعدسة البن: جيد (تقديري)');
  });

  test('الإنجليزية', () {
    final t = buildShareText(en, _scan(roaster: 'Acme', cafe: _cafe()));
    expect(t.split('\n').first, 'I rated the roaster Acme with Bunn Lens: Good (estimate)');
    expect(t, contains('Cafe: مقهى الورد'));
  });

  test('تسميات الدرجة حسب DESIGN', () {
    expect(scoreLabelFor(ar, 100), 'ممتاز');
    expect(scoreLabelFor(ar, 85), 'ممتاز');
    expect(scoreLabelFor(ar, 84), 'جيد');
    expect(scoreLabelFor(ar, 70), 'جيد');
    expect(scoreLabelFor(ar, 69), 'متوسط');
    expect(scoreLabelFor(ar, 50), 'متوسط');
    expect(scoreLabelFor(ar, 49), 'ضعيف');
  });
}
