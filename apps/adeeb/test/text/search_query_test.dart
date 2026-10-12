import 'package:adeeb/text/light_stemmer.dart';
import 'package:adeeb/text/search_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// أمثلة اصطناعية قصيرة، ليست نصوصاً تراثية.
void main() {
  group('الجذع الخفيف', () {
    final cases = {
      'الاسد': 'اسد',
      'والاسد': 'اسد',
      'فالحكمه': 'حكمه',
      'بالقلم': 'قلم',
      'كالبحر': 'بحر',
      'للكتاب': 'كتاب',
      'وكتاب': 'كتاب',
      'فسلام': 'سلام',
      'كتبها': 'كتب',
      'كتبهم': 'كتب',
      'كتبهما': 'كتب',
      'كتابكم': 'كتاب',
      'معلمين': 'معلم',
      'معلمون': 'معلم',
      'كلمات': 'كلم',
      'والكلمات': 'كلم',
    };
    cases.forEach((input, expected) {
      test('«$input» ← «$expected»', () {
        expect(lightStem(input), expected);
      });
    });

    test('لا يُحذف ما يُبقي أقل من 3 أحرف', () {
      expect(lightStem('وجد'), 'وجد');
      expect(lightStem('فرس'), 'فرس');
      expect(lightStem('الم'), 'الم');
      expect(lightStem('بين'), 'بين');
      expect(lightStem('اسد'), 'اسد');
      expect(lightStem('ها'), 'ها');
      expect(lightStem(''), '');
    });

    test('«و/ف» المفردتان لا تُحذفان إلا إن بقي 4 أحرف', () {
      expect(lightStem('فكره'), 'فكره');
      expect(lightStem('فساد'), 'فساد');
      expect(lightStem('وجود'), 'وجود');
      expect(lightStem('وكتب'), 'وكتب');
      expect(lightStem('فقال'), 'فقال');
      expect(lightStem('والكتب'), 'كتب');
      expect(lightStem('وكلمات'), 'كلم');
    });

    test('stemNormalized يجذع كل كلمة', () {
      expect(stemNormalized('والاسد في الغابه'), 'اسد في غابه');
      expect(stemNormalized(''), '');
    });
  });

  group('تحليل الاستعلام', () {
    test('كلمات مطبَّعة مربوطة بـ AND، والكلمة على norm أو stem', () {
      final q = SearchQuery.parse('الحِكمةُ  أسد');
      expect(q.terms.map((t) => t.words), [
        ['الحكمه'],
        ['اسد'],
      ]);
      expect(
        q.toFtsMatch(),
        '(norm:"الحكمه" OR stem:"حكمه") AND (norm:"اسد" OR stem:"اسد")',
      );
    });

    test('ما بين علامتي تنصيص عبارة على norm فقط', () {
      for (final raw in ['"الحكمة ضالة"', '«الحكمة ضالة»', '“الحكمة ضالة”']) {
        final q = SearchQuery.parse(raw);
        expect(q.terms.single.words, ['الحكمه', 'ضاله'], reason: raw);
        expect(q.terms.single.quoted, isTrue);
        expect(q.toFtsMatch(), 'norm:"الحكمه ضاله"');
      }
    });

    test('displayText يزيل زوج التنصيص الخارجي فقط', () {
      expect(SearchQuery.parse('  اسد ').displayText, 'اسد');
      expect(SearchQuery.parse('"باب الاسد"').displayText, 'باب الاسد');
      expect(SearchQuery.parse('«باب الاسد»').displayText, 'باب الاسد');
      expect(SearchQuery.parse('“باب”').displayText, 'باب');
      expect(SearchQuery.parse('قال «باب»').displayText, 'قال «باب»');
      expect(SearchQuery.parse('"أ" و"ب"').displayText, '"أ" و"ب"');
      expect(SearchQuery.parse('"').displayText, '"');
    });

    test('عبارة وكلمات معاً، وعلامة بلا إغلاق تُهمل', () {
      final q = SearchQuery.parse('قال «باب الأسد» "ثم');
      expect(q.terms.map((t) => (t.words.join(' '), t.quoted)), [
        ('قال', false),
        ('باب الاسد', true),
        ('ثم', false),
      ]);
    });

    test('الترقيم وعلامات FTS5 لا تصل إلى التعبير', () {
      final q = SearchQuery.parse('NEAR(a* OR b) - ^c:');
      expect(q.toFtsMatch(), isNot(contains('*')));
      expect(q.toFtsMatch(), isNot(contains('^')));
      expect(q.terms.map((t) => t.words.single), ['near', 'a', 'or', 'b', 'c']);
    });

    test('الحد الأدنى حرفان، والفارغ والترقيم غير قابلين للبحث', () {
      expect(SearchQuery.parse('').isEmpty, isTrue);
      expect(SearchQuery.parse('  ،،  ').isEmpty, isTrue);
      expect(SearchQuery.parse('ب').isSearchable, isFalse);
      expect(SearchQuery.parse('بِّ').isSearchable, isFalse);
      expect(SearchQuery.parse('في').isSearchable, isTrue);
    });

    test('عدد الكلمات محدود', () {
      final q = SearchQuery.parse(List.filled(40, 'كلمة').join(' '));
      expect(q.terms.length, SearchQuery.maxTerms);
    });
  });

  group('مواضع التطابق في النص الأصلي', () {
    String marked(String text, List<MatchSpan> spans) {
      final b = StringBuffer();
      var at = 0;
      for (final s in spans) {
        b
          ..write(text.substring(at, s.start))
          ..write('[')
          ..write(text.substring(s.start, s.end))
          ..write(']');
        at = s.end;
      }
      b.write(text.substring(at));
      return b.toString();
    }

    String mark(String text, String query) =>
        marked(text, findMatches(text, SearchQuery.parse(query)));

    test('أمثلة القبول: التظليل على الكلمة بتشكيلها', () {
      const text = 'فقرة اختبار: الحِكْمَةُ والأَسَدُ، وأَسَدٌ على التل.';
      expect(mark(text, 'الحكمه'), contains('[الحِكْمَةُ]'));
      expect(
        mark(text, 'اسد'),
        'فقرة اختبار: الحِكْمَةُ [والأَسَدُ]، [وأَسَدٌ] على التل.',
      );
      expect(mark(text, 'علي'), contains('[على]'));
    });

    test('الكلمة لا تطابق جزءاً من كلمة أخرى', () {
      expect(mark('أسدية وأسود', 'اسد'), 'أسدية وأسود');
    });

    test('التطويل داخل الكلمة يبقى ضمن التظليل', () {
      expect(mark('قال الحـــكمة هنا', 'حكمه'), 'قال [الحـــكمة] هنا');
    });

    test('العبارة كلمات متتالية فقط', () {
      const text = 'باب الأسد ثم باب ثم الأسد';
      expect(mark(text, '"باب الاسد"'), '[باب الأسد] ثم باب ثم الأسد');
    });

    test('كلمتان تُظلَّلان معاً ولا تداخل', () {
      expect(mark('الحكمة والأسد', 'حكمه اسد'), '[الحكمة] [والأسد]');
    });

    test('شعر: فواصل الشطور والأبيات لا تمنع التطابق', () {
      expect(mark('شطر أول\tالحكمة\nبيت', 'الحكمة'), 'شطر أول\t[الحكمة]\nبيت');
    });

    test('لا تطابق ← قائمة فارغة', () {
      expect(findMatches('نص بلا تطابق', SearchQuery.parse('غائب')), isEmpty);
      expect(findMatches('', SearchQuery.parse('غائب')), isEmpty);
    });
  });

  group('المقتطف', () {
    test('فقرة قصيرة كاملة مع مواضع التظليل نفسها', () {
      const text = 'قال الحكمة هنا';
      final spans = findMatches(text, SearchQuery.parse('الحكمه'));
      final s = buildSnippet(text, spans);
      expect(s.text, text);
      expect(
        s.text.substring(s.spans.single.start, s.spans.single.end),
        'الحكمة',
      );
    });

    test('فقرة طويلة: يبدأ قبل التطابق بـ «…» على حد كلمة ويُقطع في آخره', () {
      final text =
          '${List.filled(60, 'كلمة').join(' ')} الحِكْمَةُ ${List.filled(80, 'أخرى').join(' ')}';
      final spans = findMatches(text, SearchQuery.parse('الحكمه'));
      final s = buildSnippet(text, spans, before: 30, maxLength: 120);
      expect(s.text.startsWith(ellipsis), isTrue);
      expect(s.text.endsWith(ellipsis), isTrue);
      expect(s.text.substring(1, 6), 'كلمة ');
      expect(s.text.length, lessThanOrEqualTo(122));
      expect(
        s.text.substring(s.spans.single.start, s.spans.single.end),
        'الحِكْمَةُ',
      );
    });

    test('بلا تطابق: أول النص', () {
      final text = List.filled(100, 'كلمة').join(' ');
      final s = buildSnippet(text, const [], maxLength: 50);
      expect(s.text.startsWith('كلمة'), isTrue);
      expect(s.text.endsWith(ellipsis), isTrue);
      expect(s.spans, isEmpty);
    });

    test('فواصل الشعر تصير مسافات بالطول نفسه', () {
      const text = 'شطر\tالحكمة\nبيت';
      final s = buildSnippet(
        text,
        findMatches(text, SearchQuery.parse('الحكمة')),
      );
      expect(s.text, 'شطر الحكمة بيت');
      expect(
        s.text.substring(s.spans.single.start, s.spans.single.end),
        'الحكمة',
      );
    });
  });
}
