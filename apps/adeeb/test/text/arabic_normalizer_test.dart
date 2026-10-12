import 'package:adeeb/text/arabic_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// أمثلة اصطناعية قصيرة (كلمات مفردة)، ليست نصوصاً تراثية.
void main() {
  group('حذف التشكيل', () {
    final cases = {
      'الحِكْمَةُ': 'الحكمه',
      'أَسَدٌ': 'اسد',
      'كِتَابًا': 'كتابا',
      'بِكَلِمَةٍ': 'بكلمه',
      'مُحَمَّدٌ': 'محمد', // شدة
      'قُلْ': 'قل', // سكون
      'هٰذَا': 'هذا', // ألف خنجرية U+0670
      'رَحْمٰنِ': 'رحمن',
      'ٱلْكِتَٰبُ': 'الكتب', // ألف وصل + خنجرية
    };
    cases.forEach((input, expected) {
      test('«$input» ← «$expected»', () {
        expect(normalizeArabic(input), expected);
      });
    });

    test('كل علامات التشكيل U+064B–U+0652 تُحذف', () {
      for (var c = 0x064B; c <= 0x0652; c++) {
        expect(
          normalizeArabic('ب${String.fromCharCode(c)}ت'),
          'بت',
          reason: c.toRadixString(16),
        );
      }
    });

    test('علامات القرآن الصغيرة (U+0610–U+061A وU+06D6–U+06ED) تُحذف', () {
      for (final c in [
        0x0610,
        0x0615,
        0x061A,
        0x06D6,
        0x06DA,
        0x06E5,
        0x06ED,
      ]) {
        expect(
          normalizeArabic('ب${String.fromCharCode(c)}ت'),
          'بت',
          reason: c.toRadixString(16),
        );
      }
    });
  });

  group('التطويل', () {
    test('ـ يُحذف ولا يقطع الكلمة', () {
      expect(normalizeArabic('الحـــكمة'), 'الحكمه');
      expect(normalizeArabic('كـتـاب'), 'كتاب');
    });
  });

  group('الهمزات والألف', () {
    final cases = {
      'أسد': 'اسد',
      'إنسان': 'انسان',
      'آخر': 'اخر',
      'ٱسم': 'اسم',
      'مؤمن': 'مومن',
      'سئل': 'سيل',
      'بئر': 'بير',
      'سماء': 'سماء', // الهمزة المفردة تبقى
      'شيء': 'شيء',
      'ءامن': 'ءامن',
    };
    cases.forEach((input, expected) {
      test('«$input» ← «$expected»', () {
        expect(normalizeArabic(input), expected);
      });
    });

    test('الأشكال المفكوكة (حرف + همزة/مدة مركّبة) تساوي المركّبة', () {
      expect(normalizeArabic('أسد'), normalizeArabic('أسد'));
      expect(normalizeArabic('إنسان'), normalizeArabic('إنسان'));
      expect(normalizeArabic('آخر'), normalizeArabic('آخر'));
      expect(normalizeArabic('مؤمن'), normalizeArabic('مؤمن'));
      expect(normalizeArabic('سئل'), normalizeArabic('سئل'));
    });
  });

  group('التاء المربوطة والألف المقصورة', () {
    test('ة ← ه', () {
      expect(normalizeArabic('مدرسة'), 'مدرسه');
      expect(normalizeArabic('الحكمة'), normalizeArabic('الحكمه'));
    });
    test('ى ← ي', () {
      expect(normalizeArabic('على'), 'علي');
      expect(normalizeArabic('على'), normalizeArabic('علي'));
      expect(normalizeArabic('مستشفى'), 'مستشفي');
    });
    test('الياء الفارسية ی والكاف ک تُوحَّدان', () {
      expect(normalizeArabic('علی'), 'علي');
      expect(normalizeArabic('کتاب'), 'كتاب');
    });
  });

  group('الترقيم والمسافات والأرقام', () {
    test('علامات الترقيم العربية واللاتينية ← مسافة واحدة', () {
      expect(normalizeArabic('قال: «نعم»، ثم؟ ذهب!'), 'قال نعم ثم ذهب');
      expect(normalizeArabic('أ.ب,ج;د(هـ)'), 'ا ب ج د ه');
      expect(normalizeArabic('كلمة؛ كلمة'), 'كلمه كلمه');
    });
    test('المسافات المتعددة والأسطر والجدولة تُضغط والأطراف تُحذف', () {
      expect(normalizeArabic('  شطر\tشطر\nبيت   ثان  '), 'شطر شطر بيت ثان');
    });
    test('الأرقام الهندية والفارسية ← لاتينية', () {
      expect(normalizeArabic('سنة ٢٥٥هـ'), 'سنه 255ه');
      expect(normalizeArabic('۱۲۳'), '123');
    });
    test('اللاتينية بحروف صغيرة', () {
      expect(normalizeArabic('Gemini GitHub'), 'gemini github');
    });
    test('محارف الاتجاه والوصل غير المرئية لا تقطع الكلمة', () {
      expect(normalizeArabic('كت‌اب'), 'كتاب');
      expect(normalizeArabic('‏كتاب‎'), 'كتاب');
    });
    test('نص فارغ أو ترقيم فقط ← فارغ', () {
      expect(normalizeArabic(''), '');
      expect(normalizeArabic(' ،. ! '), '');
      expect(normalizeArabic('ًٌٍ'), '');
    });
  });

  test('ثابت: تطبيع المطبَّع لا يغيّره', () {
    const samples = ['الحِكْمَةُ والأَسَدُ', 'إلى آخره؛ مؤتمر', 'شيءٌ ـ ٣'];
    for (final s in samples) {
      final once = normalizeArabic(s);
      expect(normalizeArabic(once), once);
    }
  });

  group('خريطة المواضع', () {
    test('الطول يطابق النص المطبَّع', () {
      const s = 'فقرة اختبار: الحِكْمَةُ والأَسَدُ.';
      final n = normalizeArabicWithMap(s);
      expect(n.text, normalizeArabic(s));
      expect(n.starts.length, n.text.length);
      expect(n.ends.length, n.text.length);
    });

    test('نهاية الحرف تشمل تشكيله وتطويله التابعين', () {
      const s = 'الحِكْمَةُ';
      final n = normalizeArabicWithMap(s);
      expect(n.text, 'الحكمه');
      // أول حرف وآخره: المدى الأصلي للكلمة كلها بتشكيلها.
      expect(s.substring(n.starts.first, n.ends.last), s);
      // «ح» وكسرتها.
      expect(s.substring(n.starts[2], n.ends[2]), 'حِ');
    });

    test('مدى كلمة داخل جملة مع ترقيم وتطويل', () {
      const s = '«قال الأَسَـدُ»: نعم';
      final n = normalizeArabicWithMap(s);
      expect(n.text, 'قال الاسد نعم');
      final i = n.text.indexOf('الاسد');
      final j = i + 'الاسد'.length - 1;
      expect(s.substring(n.starts[i], n.ends[j]), 'الأَسَـدُ');
    });
  });
}
