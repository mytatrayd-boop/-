/// حفظ آخر إجابة فقط على الجهاز، بلا سجل أسئلة (DESIGN §12.4، §18.6):
/// ترميزها وفك ترميزها JSON. Dart صافٍ.
library;

import 'dart:convert';

import 'ask_service.dart';
import 'quote_verifier.dart';

const _version = 1;

String encodeLastAnswer(AskAnswer a) => jsonEncode({
  'v': _version,
  'question': a.question,
  'answer': a.answer,
  'citations': [for (final c in a.citations) c.toJson()],
});

/// null إن كان المحفوظ تالفاً أو بصيغة أخرى.
AskAnswer? decodeLastAnswer(String? raw) {
  if (raw == null) return null;
  try {
    final json = jsonDecode(raw);
    if (json is! Map || json['v'] != _version) return null;
    final question = json['question'];
    final answer = json['answer'];
    final list = json['citations'];
    if (question is! String || answer is! String || list is! List) {
      return null;
    }
    final citations = <VerifiedCitation>[];
    for (final c in list) {
      final parsed = VerifiedCitation.fromJson(c);
      if (parsed == null) return null;
      citations.add(parsed);
    }
    if (citations.isEmpty || answer.isEmpty) return null;
    return AskAnswer(
      question: question,
      remaining: null,
      answer: answer,
      citations: citations,
    );
  } on FormatException {
    return null;
  }
}
