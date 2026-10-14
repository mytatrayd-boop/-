import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

void main() {
  test('يدمج الألف والهمزة المنفصلة إلى أ وإ وآ', () {
    expect(arabicNfc('أ'), 'أ');
    expect(arabicNfc('إ'), 'إ');
    expect(arabicNfc('آ'), 'آ');
    expect(arabicNfc('ؤ'), 'ؤ');
    expect(arabicNfc('ئ'), 'ئ');
  });

  test('يعيد ترتيب الشدة والفتحة ترتيباً قانونياً (فتحة ثم شدة)', () {
    expect(arabicNfc('بَّ'), 'بَّ');
    expect(isArabicNfc('بَّ'), isFalse);
    expect(isArabicNfc('بَّ'), isTrue);
  });

  test('الدمج بعد إعادة الترتيب: ا + فتحة + همزة فوق', () {
    // الهمزة (230) غير محجوبة بالفتحة (30) فتُدمج.
    expect(arabicNfc('أَ'), 'أَ');
  });

  test('لا يغيّر نصاً مشكولاً سليماً', () {
    const s = 'نَصٌّ مَشْكُولٌ لِلِاخْتِبَارِ';
    expect(arabicNfc(s), s);
  });

  test('يكشف علامات الدمج غير العربية', () {
    expect(unsupportedMarks('é'), {0x0301});
    expect(unsupportedMarks('نص'), isEmpty);
  });
}
