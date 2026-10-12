import 'package:adeeb/ask/ask_passages.dart';
import 'package:adeeb/ask/ask_query.dart';
import 'package:adeeb/ask/last_answer.dart';
import 'package:adeeb/ask/ask_service.dart';
import 'package:adeeb/ask/quote_verifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// نصوص اختبار اصطناعية (ليست نصوصاً تراثية).
LocalParagraph para(String id, String text, {String book = 'aa'}) =>
    LocalParagraph(
      id: id,
      bookId: book,
      bookTitle: 'كتاب $book',
      chapterTitle: 'باب اختبار',
      text: text,
    );

void main() {
  group('AskQuery', () {
    test('يحذف الكلمات الشائعة ويطبّع ويربط بـ OR', () {
      final q = AskQuery.fromQuestion('ما تعريفُ البيانِ عند الجاحظ؟');
      expect(q.words, ['تعريف', 'البيان', 'الجاحظ']);
      expect(
        q.toFtsMatch(),
        '(norm:"تعريف" OR stem:"تعريف") OR (norm:"البيان" OR stem:"بيان") '
        'OR (norm:"الجاحظ" OR stem:"جاحظ")',
      );
    });

    test('سؤال من كلمات شائعة فقط فارغ، والمكرر يُحذف', () {
      expect(AskQuery.fromQuestion('ما هو؟ وما هي؟').isEmpty, isTrue);
      expect(AskQuery.fromQuestion('الصديق الصديق').words, ['الصديق']);
    });

    test('cleanQuestion يزيل محارف التحكم التي يرفضها الخادم', () {
      expect(cleanQuestion(' سؤال\r\u0000طويل\n '), 'سؤال  طويل');
    });
  });

  group('selectPassages', () {
    test('ست فقرات على الأكثر، بلا تكرار، والمجموع ≤ 8000', () {
      final long = List.filled(400, 'كلمة').join(' '); // 1999 حرفاً
      final ranked = [
        for (var i = 1; i <= 8; i++) para('aa-b001-p0000$i', long),
        para('aa-b001-p00001', 'مكرر'),
      ];
      final out = selectPassages(ranked, AskQuery.fromQuestion('كلمة'));
      expect(out.length, maxPassages);
      expect(out.map((p) => p.id).toSet().length, out.length);
      final total = out.fold(0, (n, p) => n + p.sentText.length);
      expect(total, lessThanOrEqualTo(maxPassagesTotalChars));
      for (final p in out) {
        expect(p.sentText.length, lessThanOrEqualTo(maxPassageChars));
        expect(p.paragraph.text.contains(p.sentText), isTrue);
      }
    });

    test('الفقرة الطويلة تُقص على حدود الكلمات حول التطابق', () {
      final before = List.filled(500, 'تمهيد').join(' ');
      final after = List.filled(500, 'خاتمة').join(' ');
      final text = '$before الحِكْمَةُ ضالة المؤمن $after';
      final out = selectPassages([
        para('aa-b001-p00001', text),
      ], AskQuery.fromQuestion('الحكمة'));
      final sent = out.single.sentText;
      expect(sent.length, lessThanOrEqualTo(maxPassageChars));
      expect(sent, contains('الحِكْمَةُ ضالة المؤمن'));
      expect(text.contains(sent), isTrue);
      // لا نصف كلمة في الطرفين.
      expect(sent.split(' ').first, anyOf('تمهيد', 'الحِكْمَةُ'));
      expect(sent.split(' ').last, anyOf('خاتمة', 'المؤمن'));
    });

    test('العنوان يُقص إلى 200 والفارغ يصير «-»', () {
      expect(clipTitle('ب' * 300).length, maxTitleChars);
      expect(clipTitle('  '), '-');
    });
  });

  group('quote_verifier', () {
    const text = 'قال الحكيمُ: إنّ الصَّدِيقَ وقتَ الضيقِ كنزٌ لا يفنى.';

    test('يقبل الاقتباس بلا تشكيل ويعيده من النص المحلي بتشكيله', () {
      final span = locateQuote('ان الصديق وقت الضيق', text)!;
      expect(
        text.substring(span.start, span.end),
        'إنّ الصَّدِيقَ وقتَ الضيقِ',
      );
    });

    test('يرفض نصف كلمة في الطرفين والقصير والمختلق', () {
      expect(locateQuote('ن الصديق وقت الضيق', text), isNull);
      expect(locateQuote('الصديق وقت الضي', text), isNull);
      expect(locateQuote('الصديق وقت', text), isNull); // < 12 حرفاً
      expect(locateQuote('الصديق وقت الفرج كنز', text), isNull);
    });

    test('verifyCitations: المعرّف من المرسل فقط، بلا تكرار، حتى 3', () {
      final sent = [
        AskPassage(paragraph: para('aa-b001-p00001', text), sentText: text),
      ];
      final out = verifyCitations([
        const RawCitation(
          paragraphId: 'aa-b001-p00009',
          quote: 'ان الصديق وقت الضيق',
        ),
        const RawCitation(
          paragraphId: 'aa-b001-p00001',
          quote: 'ان الصديق وقت الضيق',
        ),
        const RawCitation(
          paragraphId: 'aa-b001-p00001',
          quote: 'إن الصديق وقت الضيق',
        ),
        const RawCitation(
          paragraphId: 'aa-b001-p00001',
          quote: 'كنز لا يفنى أبداً',
        ),
      ], sent);
      expect(out.map((c) => c.quote), ['إنّ الصَّدِيقَ وقتَ الضيقِ']);
      expect(out.single.bookTitle, 'كتاب aa');
    });
  });

  test('آخر إجابة: ترميز وفك، والتالف null', () {
    const answer = AskAnswer(
      question: 'سؤال',
      remaining: 4,
      answer: 'إجابة',
      citations: [
        VerifiedCitation(
          paragraphId: 'aa-b001-p00001',
          bookId: 'aa',
          bookTitle: 'كتاب',
          chapterTitle: 'باب',
          quote: 'اقتباس',
        ),
      ],
    );
    final back = decodeLastAnswer(encodeLastAnswer(answer))!;
    expect(back.question, 'سؤال');
    expect(back.answer, 'إجابة');
    expect(back.citations.single.quote, 'اقتباس');
    expect(decodeLastAnswer('{'), isNull);
    expect(decodeLastAnswer('{"v":2}'), isNull);
    expect(decodeLastAnswer(null), isNull);
  });
}
