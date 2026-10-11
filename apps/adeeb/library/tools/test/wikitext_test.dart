import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

List<Block> conv(String s, {TemplateRules? rules, RemovalStats? stats}) =>
    WikitextConverter(rules ?? TemplateRules()).convert(s, stats ?? RemovalStats());

String texts(List<Block> bs) => bs
    .map((b) => switch (b) {
          HeadingBlock(:final level, :final text) => 'H$level:$text',
          ProseBlock(:final text) => 'P:$text',
          VerseBlock() => 'V:${b.text}',
        })
    .join('|');

void main() {
  test('يحذف الحواشي ref وreferences وsup ويعدّها', () {
    final st = RemovalStats();
    final b = conv('نص أول<ref>حاشية</ref> ونص<ref name="x"/> ثانٍ<sup>١</sup>.\n<references/>', stats: st);
    expect(texts(b), 'P:نص أول ونص ثانٍ.');
    expect(st.counts['ref (حاشية)'], 2);
    expect(st.counts['sup (رقم حاشية مرفوع)'], 1);
  });

  test('يضم الأسطر المتتالية في فقرة ويفصل عند السطر الفارغ', () {
    expect(texts(conv('سطر أول\nسطر ثانٍ\n\nفقرة ثانية')), 'P:سطر أول سطر ثانٍ|P:فقرة ثانية');
  });

  test('العناوين والروابط والتنسيق والكيانات', () {
    final b = conv("== عنوان ==\n'''غامق''' و''مائل'' [[هدف|تسمية]] [[صفحة]] &laquo;x&raquo;\n[[تصنيف:س]] [[ملف:ص.png|تعليق]]");
    expect(texts(b), 'H2:عنوان|P:غامق ومائل تسمية صفحة «x»');
  });

  test('القوالب: drop وunwrap وverse، والقالب المجهول خطأ صريح', () {
    final rules = TemplateRules(drop: ['ترويسة'], unwrap: {'وسط': 1}, verse: ['بيت']);
    final b = conv('{{ترويسة|عنوان=س}}\n{{وسط|يبقى}}\n\n{{بيت|صدر|عجز}}\n{{بيت|صدر٢|عجز٢}}', rules: rules);
    expect(texts(b), 'P:يبقى|V:صدر\tعجز\nصدر٢\tعجز٢');
    expect(() => conv('{{مجهول|س}}', rules: rules), throwsA(isA<WikitextException>()));
  });

  test('poem: كل سطر بيت، والشطران بمسافات ثلاث أو أكثر', () {
    final b = conv('<poem>\nصدر أ     عجز أ\nصدر ب\tعجز ب\n</poem>');
    expect(texts(b), 'V:صدر أ\tعجز أ\nصدر ب\tعجز ب');
  });

  test('يرفض <pages> والجداول والوسوم المجهولة بدل حذفها بصمت', () {
    expect(() => conv('<pages index="x.pdf" from=1 to=2 />'), throwsA(isA<WikitextException>()));
    expect(() => conv('{|\n| خلية\n|}'), throwsA(isA<WikitextException>()));
    expect(() => conv('نص <math>x</math>'), throwsA(isA<WikitextException>()));
  });

  test('يحذف الفواصل التي لا حروف فيها', () {
    expect(texts(conv('نص\n\n* * *\n\n----\n\nنص آخر')), 'P:نص|P:نص آخر');
  });

  test('يحفظ التشكيل كما هو ويحذف محارف الاتجاه الخفية', () {
    expect(texts(conv('نَصٌّ‏ مَشْكُولٌ')), 'P:نَصٌّ مَشْكُولٌ');
  });

  group('قالب البيت (البند 1)', () {
    final rules = TemplateRules(verse: ['بيت']);
    test('1= و2= موضعيان', () {
      expect(texts(conv('{{بيت|2=عجز|1=صدر}}', rules: rules)), 'V:صدر\tعجز');
    });
    test('«=» داخل الشطر (بعد مسافات) لا يجعله مسمّى', () {
      expect(texts(conv('{{بيت|قال الفتى = نعم|عجز}}', rules: rules)), 'V:قال الفتى = نعم\tعجز');
    });
    test('وسيط مسمّى مجهول خطأ', () {
      expect(() => conv('{{بيت|صدر|عجز|نمط=س}}', rules: rules), throwsA(isA<WikitextException>()));
    });
    test('أكثر من شطرين خطأ', () {
      expect(() => conv('{{بيت|أ|ب|ج}}', rules: rules), throwsA(isA<WikitextException>()));
      expect(() => conv('{{بيت|أ|3=ج}}', rules: rules), throwsA(isA<WikitextException>()));
    });
    test('بيت فارغ خطأ', () {
      expect(() => conv('{{بيت| | }}', rules: rules), throwsA(isA<WikitextException>()));
      expect(() => conv('{{بيت}}', rules: rules), throwsA(isA<WikitextException>()));
    });
  });

  group('unwrap (البند 2)', () {
    test('يدعم N= المسمّى رقماً', () {
      final rules = TemplateRules(unwrap: {'وسط': 2});
      expect(texts(conv('{{وسط|حجم=كبير|أول|ثانٍ}}', rules: rules)), 'P:ثانٍ');
      expect(texts(conv('{{وسط|2=ثانٍ|أول}}', rules: rules)), 'P:ثانٍ');
    });
    test('غياب الوسيط المطلوب خطأ لا حذف صامت', () {
      final rules = TemplateRules(unwrap: {'وسط': 2});
      expect(() => conv('{{وسط|أول}}', rules: rules), throwsA(isA<WikitextException>()));
    });
  });

  test('<br> داخل poem فاصل سطر لا لاصق (البند 3)', () {
    expect(texts(conv('<poem>\nبيت أول<br/>بيت ثانٍ\nصدر<br>عجز\n</poem>')),
        'V:بيت أول\nبيت ثانٍ\nصدر\nعجز');
  });

  test('poem لا يشطر عند « ... »', () {
    expect(texts(conv('<poem>\nقال ... ثم مضى\n</poem>')), 'V:قال ... ثم مضى');
  });

  group('الروابط ذات البادئة (البند 4)', () {
    test('بادئة غير لغوية يبقى نصها الظاهر', () {
      expect(texts(conv('انظر [[w:مقالة|المقالة]] و[[wikt:كلمة]] هنا')), 'P:انظر المقالة وwikt:كلمة هنا');
    });
    test('بادئة من قائمة اللغات بنص ظاهر يبقى نصها', () {
      expect(texts(conv('قال [[en:Lion|الأسد]] كذا')), 'P:قال الأسد كذا');
    });
    test('رابط لغة بلا نص ظاهر يُحذف', () {
      expect(texts(conv('نص\n[[en:Kalila and Dimna]]')), 'P:نص');
    });
    test('بادئة لاتينية خارج القائمة لا تُحذف', () {
      expect(texts(conv('[[xyz:صفحة]]')), 'P:xyz:صفحة');
    });
    test('[[:تصنيف:س|نص]] رابط ظاهر', () {
      expect(texts(conv('[[:تصنيف:كتب|الكتب]]')), 'P:الكتب');
    });
  });

  group('المخفي والتعليق غير المغلق (البند 5)', () {
    test('span بـ display:none خطأ', () {
      expect(() => conv('نص <span style="display:none">مخفي</span>'), throwsA(isA<WikitextException>()));
      expect(() => conv("نص <div class='x' style='color:red; display: none'>مخفي</div>"),
          throwsA(isA<WikitextException>()));
    });
    test('تعليق بلا إغلاق خطأ', () {
      expect(() => conv('نص <!-- بلا إغلاق\nنص آخر'), throwsA(isA<WikitextException>()));
    });
    test('span عادي يُزال وسمه ويبقى نصه', () {
      expect(texts(conv('نص <span style="color:red">ظاهر</span>')), 'P:نص ظاهر');
    });
  });

  test('ZWNJ يبقى', () {
    expect(texts(conv('نص‌مع')), 'P:نص‌مع');
  });
}
