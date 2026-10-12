/// مسار «اسأل الأديب» (ARCHITECTURE §7): استرجاع محلي ← الخادم ← تحقق محلي
/// من كل اقتباس ← عرض أو رجوع إلى النصوص المطابقة. Dart صافٍ.
library;

import 'dart:async';

import 'ask_api.dart';
import 'ask_passages.dart';
import 'ask_query.dart';
import 'quote_verifier.dart';

/// مراحل الانتظار الظاهرة (DESIGN §12.3).
enum AskStage { searching, answering, verifying }

/// مصدر الفقرات المحلية: أفضل الفقرات لاستعلام بترتيب bm25.
abstract interface class PassageRetriever {
  /// [bookId] null = كل الكتب المحمّلة.
  Future<List<LocalParagraph>> retrieve(
    AskQuery query, {
    String? bookId,
    int limit,
  });
}

/// لماذا تُعرض النصوص المطابقة بدل إجابة.
enum FallbackReason {
  /// لا نصوص مطابقة محلياً: «لم أجد» بلا طلب ولا استهلاك حصة.
  noLocalMatches,

  /// الخادم: `found=false` و`NOT_FOUND`.
  notFound,

  /// الخادم `UNVERIFIED`، أو لم يصح أي اقتباس في التطبيق.
  unverified,
  offline,
  dailyLimit,
  rateLimit,

  /// تعطّل الخادم أو مهلته أو رد لا يطابق العقد أو إعداد ناقص.
  unavailable,
  upgradeRequired,
}

sealed class AskOutcome {
  const AskOutcome({required this.question, required this.remaining});

  final String question;

  /// الرصيد بعد السؤال إن عُرف من الخادم.
  final int? remaining;
}

/// إجابة باقتباس واحد على الأقل متحقَّق منه محلياً.
class AskAnswer extends AskOutcome {
  const AskAnswer({
    required super.question,
    required super.remaining,
    required this.answer,
    required this.citations,
    this.others = const [],
  });

  final String answer;
  final List<VerifiedCitation> citations;

  /// الفقرات المسترجعة غير المقتبسة («نصوص مطابقة أخرى»).
  final List<LocalParagraph> others;
}

/// لا إجابة: السبب مع النصوص المطابقة من البحث المحلي (قد تكون فارغة).
class AskFallback extends AskOutcome {
  const AskFallback({
    required super.question,
    required super.remaining,
    required this.reason,
    required this.passages,
  });

  final FallbackReason reason;
  final List<LocalParagraph> passages;
}

class AskService {
  AskService({required this.retriever, required this.api});

  final PassageRetriever retriever;
  final AskApi api;

  /// يسأل الأديب. [localOnly] (بعد انتهاء الحصة) يكتفي بالنصوص المطابقة.
  /// يرمي [AskApiException] بـ [AskFailure.cancelled] عند الإلغاء فقط.
  Future<AskOutcome> ask(
    String rawQuestion, {
    required String lang,
    String? bookId,
    bool localOnly = false,
    void Function(AskStage stage)? onStage,
    Future<void>? cancel,
  }) async {
    final question = cleanQuestion(rawQuestion);
    onStage?.call(AskStage.searching);
    final query = AskQuery.fromQuestion(question);
    final ranked = query.isEmpty
        ? const <LocalParagraph>[]
        : await retriever.retrieve(query, bookId: bookId, limit: retrieveLimit);
    final passages = selectPassages(ranked, query);
    final local = [for (final p in passages) p.paragraph];

    AskFallback fallback(FallbackReason reason, {int? remaining}) =>
        AskFallback(
          question: question,
          remaining: remaining,
          reason: reason,
          passages: local,
        );

    if (localOnly) return fallback(FallbackReason.dailyLimit, remaining: 0);
    // لا نصوص مطابقة: «لم أجد» محلياً بلا طلب ولا استهلاك حصة (§7).
    if (passages.isEmpty) return fallback(FallbackReason.noLocalMatches);

    onStage?.call(AskStage.answering);
    final AskReply reply;
    try {
      reply = await api.ask(
        question: question,
        lang: lang,
        passages: passages,
        cancel: cancel,
      );
    } on AskApiException catch (e) {
      if (e.failure == AskFailure.cancelled) rethrow;
      final reason = switch (e.failure) {
        AskFailure.offline => FallbackReason.offline,
        AskFailure.dailyLimit => FallbackReason.dailyLimit,
        AskFailure.rateLimit => FallbackReason.rateLimit,
        AskFailure.upgradeRequired => FallbackReason.upgradeRequired,
        AskFailure.cancelled ||
        AskFailure.timeout ||
        AskFailure.unavailable ||
        AskFailure.badRequest ||
        AskFailure.notConfigured => FallbackReason.unavailable,
      };
      return fallback(reason, remaining: e.remaining);
    } on Object {
      return fallback(FallbackReason.unavailable);
    }

    if (!reply.found) {
      return fallback(
        reply.reason == NotFoundReason.unverified
            ? FallbackReason.unverified
            : FallbackReason.notFound,
        remaining: reply.remaining,
      );
    }
    onStage?.call(AskStage.verifying);
    final verified = verifyCitations(reply.citations, passages);
    if (verified.isEmpty) {
      return fallback(FallbackReason.unverified, remaining: reply.remaining);
    }
    final cited = {for (final c in verified) c.paragraphId};
    return AskAnswer(
      question: question,
      remaining: reply.remaining,
      answer: reply.answer,
      citations: verified,
      others: [
        for (final p in local)
          if (!cited.contains(p.id)) p,
      ],
    );
  }
}
