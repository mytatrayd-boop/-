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
}
