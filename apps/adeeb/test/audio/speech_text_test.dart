import 'package:adeeb/audio/speech_text.dart';
import 'package:adeeb/audio/tts_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// نصوص اصطناعية قصيرة، ليست نصوصاً تراثية.
void main() {
  group('النثر', () {
    test('فقرة قصيرة مقطع واحد بتشكيلها، والمسافات تُطوى', () {
      expect(speechChunks('  فقرةُ   اختبارٍ\nقصيرة. ', 'prose'), [
        const SpeechChunk('فقرةُ اختبارٍ قصيرة.'),
      ]);
    });

    test('فقرة فارغة بلا مقاطع', () {
      expect(speechChunks('   ', 'prose'), isEmpty);
      expect(speechChunks('', 'verse'), isEmpty);
    });

    test('الطويلة تُقسم على حدود الجمل ولا يتجاوز مقطع الحد', () {
      final sentence = 'جملة اختبار رقم واحد تنتهي هنا. ';
      final text = List.filled(300, sentence).join();
      final chunks = speechChunks(text, 'prose');
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c.text.length, lessThanOrEqualTo(maxSpeechChunk));
        expect(c.text.endsWith('.'), isTrue, reason: 'يُقطع بعد نهاية جملة');
      }
      expect(
        chunks.map((c) => c.text).join(' '),
        text.trim().replaceAll(RegExp(r'\s+'), ' '),
      );
    });

    test('بلا نهاية جملة: الفواصل ثم المسافات ثم قطع صلب', () {
      expect(splitLongText('أ، ب، ج', 4), ['أ،', 'ب، ج']);
      expect(splitLongText('كلمة كلمة كلمة', 10), ['كلمة كلمة', 'كلمة']);
      expect(splitLongText('ابتثجحخدذر', 4), ['ابتث', 'جحخد', 'ذر']);
    });

    test('علامة الاستفهام العربية حد جملة', () {
      expect(splitLongText('هل هذا سؤال؟ نعم هو كذلك', 14), [
        'هل هذا سؤال؟',
        'نعم هو كذلك',
      ]);
    });
  });

  group('الشعر', () {
    test('كل شطر مقطع، بوقفة قصيرة بين الشطرين وأطول بعد البيت', () {
      expect(speechChunks('شطر أول\tشطر ثانٍ\nشطر ثالث\tشطر رابع', 'verse'), [
        const SpeechChunk('شطر أول', pauseAfter: hemistichPause),
        const SpeechChunk('شطر ثانٍ', pauseAfter: versePause),
        const SpeechChunk('شطر ثالث', pauseAfter: hemistichPause),
        const SpeechChunk('شطر رابع', pauseAfter: versePause),
      ]);
    });

    test('بيت بشطر واحد وأسطر فارغة', () {
      expect(speechChunks('شطر وحيد\n\n \t ', 'verse'), [
        const SpeechChunk('شطر وحيد', pauseAfter: versePause),
      ]);
    });

    test('شطر أطول من الحد يُقسم والوقفة بعد آخر أجزائه', () {
      final chunks = speechChunks(
        'كلمة كلمة كلمة\tقصير',
        'verse',
        maxLength: 10,
      );
      expect(chunks, [
        const SpeechChunk('كلمة كلمة'),
        const SpeechChunk('كلمة', pauseAfter: hemistichPause),
        const SpeechChunk('قصير', pauseAfter: versePause),
      ]);
    });
  });

  group('TtsVoice', () {
    test('البلد من وسم اللغة، والعربية فقط', () {
      expect(const TtsVoice(name: 'a', locale: 'ar-EG').region, 'EG');
      expect(const TtsVoice(name: 'a', locale: 'ar_sa').region, 'SA');
      expect(const TtsVoice(name: 'a', locale: 'ar').region, isNull);
      expect(const TtsVoice(name: 'a', locale: 'ar-Arab-EG').region, 'EG');
      expect(TtsVoice.isArabicLocale('ar'), isTrue);
      expect(TtsVoice.isArabicLocale('AR-eg'), isTrue);
      expect(TtsVoice.isArabicLocale('arn-CL'), isFalse);
      expect(TtsVoice.isArabicLocale('en-US'), isFalse);
    });
  });
}
