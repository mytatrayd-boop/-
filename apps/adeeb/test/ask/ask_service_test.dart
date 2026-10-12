import 'dart:convert';
import 'dart:io';

import 'package:adeeb/ask/ask_api.dart';
import 'package:adeeb/ask/ask_query.dart';
import 'package:adeeb/ask/ask_service.dart';
import 'package:adeeb/core/app_config.dart';
import 'package:adeeb/storage/book_repository.dart';
import 'package:adeeb/storage/passage_retriever.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_ask_server.dart';
import '../helpers/library_fixtures.dart';
import '../storage/search_repository_test.dart' show entryFor, textBook;

/// نصوص اختبار اصطناعية (ليست نصوصاً تراثية).
const _texts = [
  'قال المعلم إن الصَّدِيقَ الوفي يظهر عند الشدة وليس عند الرخاء أبداً.',
  'وفي الحِكْمَةِ أن يصبر المرء على ما يكره حتى ينال ما يحب.',
  'فقرة اختبار لا تذكر شيئاً من كلمات السؤال المطروح هنا.',
  'الصديق والحكمة يجتمعان في هذه الفقرة الاصطناعية الثالثة.',
];

void main() {
  late Directory dir;
  late SqlitePassageRetriever retriever;
  late FakeAskServer server;
  late AskService service;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('adeeb_ask_');
    final path = '${dir.path}/adeeb.db';
    final books = SqliteBookRepository(path, useIsolate: false);
    final aa = textBook('aa', _texts);
    await books.install(gzJson(aa), entryFor(aa));
    final bb = textBook('bb', ['كتاب آخر يذكر الصديق مرة واحدة فقط هنا.']);
    await books.install(gzJson(bb), entryFor(bb));
    retriever = SqlitePassageRetriever(path, useIsolate: false);
    server = FakeAskServer();
    service = AskService(
      retriever: retriever,
      api: HttpAskApi(
        client: server.client(),
        baseUri: Uri.parse(testAskBaseUrl),
        deviceId: () async => '3b241101-e2bb-4255-8caf-4136c566a962',
        clientHeader: 'adeeb-android/1',
      ),
    );
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('المسترجع (FTS5، OR، bm25)', () {
    test(
      'OR بين الكلمات: فقرة تطابق كلمة واحدة تكفي، والأكثر تطابقاً أولاً',
      () async {
        final got = await retriever.retrieve(
          AskQuery.fromQuestion('ما الصديق والحكمة؟'),
        );
        final ids = got.map((p) => p.id).toList();
        expect(ids.first, 'aa-b001-p00004');
        expect(
          ids,
          containsAll(['aa-b001-p00001', 'aa-b001-p00002', 'bb-b001-p00001']),
        );
        expect(ids, isNot(contains('aa-b001-p00003')));
        expect(got.first.text, _texts[3]);
        expect(got.first.bookTitle, 'كتاب aa الاصطناعي');
        expect(got.first.chapterTitle, 'باب اختبار 1');
      },
    );

    test('نطاق كتاب واحد', () async {
      final got = await retriever.retrieve(
        AskQuery.fromQuestion('الصديق'),
        bookId: 'bb',
      );
      expect(got.map((p) => p.id), ['bb-b001-p00001']);
    });
  });

  group('AskService', () {
    test('إجابة باقتباس متحقَّق منه من النص المحلي بتشكيله', () async {
      server.onAsk = (body) {
        final ps = (body['passages']! as List).cast<Map<String, Object?>>();
        final p = ps.firstWhere(
          (x) => (x['text']! as String).contains('الوفي'),
        );
        return (
          200,
          jsonEncode({
            'found': true,
            'answer': 'إجابة اختبار موجزة.',
            'citations': [
              {
                'paragraph_id': p['id'],
                'quote': 'ان الصديق الوفي يظهر عند الشده',
              },
            ],
            'remaining': 9,
          }),
        );
      };
      final stages = <AskStage>[];
      final out = await service.ask(
        'ما صفة الصديق الوفي؟',
        lang: 'ar',
        bookId: 'aa',
        onStage: stages.add,
      );
      expect(stages, AskStage.values);
      final answer = out as AskAnswer;
      expect(answer.answer, 'إجابة اختبار موجزة.');
      expect(
        answer.citations.single.quote,
        'إن الصَّدِيقَ الوفي يظهر عند الشدة',
      );
      expect(answer.remaining, 9);
      final sent = server.askBodies.single;
      expect(sent['question'], 'ما صفة الصديق الوفي؟');
      expect((sent['passages']! as List).length, lessThanOrEqualTo(6));
    });

    test('اقتباس مختلق ← unverified بلا إجابة مع النصوص المطابقة', () async {
      server.onAsk = (body) =>
          server.quoteFirst(body, quote: 'الصديق الوفي كنز لا يفنى أبداً');
      final out = await service.ask('الصديق الوفي', lang: 'ar') as AskFallback;
      expect(out.reason, FallbackReason.unverified);
      expect(out.passages, isNotEmpty);
      expect(out.remaining, 9);
    });

    test(
      'found=false: NOT_FOUND ← notFound، UNVERIFIED ← unverified',
      () async {
        for (final (reason, expected) in [
          ('NOT_FOUND', FallbackReason.notFound),
          ('UNVERIFIED', FallbackReason.unverified),
        ]) {
          server.onAsk = (_) => (
            200,
            jsonEncode({
              'found': false,
              'answer': '',
              'citations': [],
              'reason': reason,
              'remaining': 8,
            }),
          );
          final out = await service.ask('الصديق', lang: 'ar') as AskFallback;
          expect(out.reason, expected);
          expect(out.remaining, 8);
          expect(out.passages, isNotEmpty);
        }
      },
    );

    test('لا نصوص مطابقة ← «لم أجد» محلياً بلا أي طلب', () async {
      final out =
          await service.ask('ما عاصمة فرنسا؟', lang: 'ar') as AskFallback;
      expect(out.reason, FallbackReason.noLocalMatches);
      expect(server.requests, isEmpty);
    });

    test('الحصة منتهية (localOnly) ← النصوص المطابقة بلا طلب', () async {
      final out = await service.ask(
        'الصديق',
        lang: 'ar',
        localOnly: true,
      ) as AskFallback;
      expect(out.reason, FallbackReason.dailyLimit);
      expect(out.passages, isNotEmpty);
      expect(server.requests, isEmpty);
    });

    final failures = <(int, String, FallbackReason)>[
      (429, '{"code":"DAILY_LIMIT","remaining":0}', FallbackReason.dailyLimit),
      (429, '{"code":"RATE_LIMIT"}', FallbackReason.rateLimit),
      (503, '{"code":"UNAVAILABLE"}', FallbackReason.unavailable),
      (426, '{"code":"UPGRADE_REQUIRED"}', FallbackReason.upgradeRequired),
      (400, '{"code":"BAD_REQUEST"}', FallbackReason.unavailable),
      (502, '<html>bad gateway</html>', FallbackReason.unavailable),
    ];
    for (final (status, body, reason) in failures) {
      test('$status ← $reason مع النصوص المطابقة', () async {
        server.onAsk = (_) => (status, body);
        final out = await service.ask('الصديق', lang: 'ar') as AskFallback;
        expect(out.reason, reason);
        expect(out.passages, isNotEmpty);
      });
    }

    test('دون إنترنت ← offline مع النصوص المطابقة', () async {
      server.offline = true;
      final out = await service.ask('الحكمة', lang: 'en') as AskFallback;
      expect(out.reason, FallbackReason.offline);
      expect(out.passages.map((p) => p.id), contains('aa-b001-p00002'));
    });
  });

  test('AppConfig: رابط الخادم https فقط، والفارغ null', () {
    AppConfig c(String url) =>
        AppConfig(libraryBaseUrl: '', askApiBaseUrl: url);
    expect(c('').askApiBaseUri, isNull);
    expect(c('http://x.workers.dev').askApiBaseUri, isNull);
    expect(
      c('https://x.workers.dev').askApiBaseUri.toString(),
      'https://x.workers.dev/',
    );
  });
}
