import 'package:adeeb/audio/listening_player.dart';
import 'package:adeeb/audio/speech_text.dart';
import 'package:adeeb/audio/tts_engine.dart';
import 'package:adeeb/library/catalog.dart';
import 'package:adeeb/reader/reader_book.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_audio.dart';

/// كتاب اصطناعي صغير (ليس نصاً تراثياً): بابان، والثاني فيه بيت شعر.
ReaderBook testBook() => ReaderBook.fromRows(
  id: 'bk',
  title: const LocalizedName(ar: 'كتاب الاختبار'),
  author: const LocalizedName(ar: 'مؤلف الاختبار'),
  authorDeathHijri: 100,
  rawChapters: const [
    (id: 'bk-b001', title: 'الباب الأول', level: 1),
    (id: 'bk-b002', title: 'الباب الثاني', level: 1),
  ],
  rawParagraphs: const [
    (
      id: 'bk-b001-p00001',
      chapterId: 'bk-b001',
      kind: 'prose',
      text: 'فقرة أولى.',
    ),
    (
      id: 'bk-b001-p00002',
      chapterId: 'bk-b001',
      kind: 'prose',
      text: 'فقرة ثانية.',
    ),
    (
      id: 'bk-b002-p00001',
      chapterId: 'bk-b002',
      kind: 'verse',
      text: 'شطر أ\tشطر ب',
    ),
    (
      id: 'bk-b002-p00002',
      chapterId: 'bk-b002',
      kind: 'prose',
      text: 'فقرة أخيرة.',
    ),
  ],
);

Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeTtsEngine tts;
  late FakeMediaSession media;
  late List<(String, String)> saved;
  late List<Duration> pauses;
  late DateTime now;
  late ListeningPlayer player;
  late List<ListeningEvent> events;
  late ReaderBook book;

  setUp(() {
    tts = FakeTtsEngine();
    media = FakeMediaSession();
    saved = [];
    pauses = [];
    now = DateTime(2026, 10, 12, 10);
    events = [];
    book = testBook();
    player = ListeningPlayer(
      engine: tts,
      session: media,
      savePosition: (b, p) async => saved.add((b, p)),
      clock: () => now,
      delay: (d) async => pauses.add(d),
    );
    player.events.listen(events.add);
  });

  tearDown(() => player.dispose());

  Future<void> finish([SpeakResult r = SpeakResult.done]) async {
    tts.finish(r);
    await settle();
  }

  test(
    'يبدأ من الفقرة المطلوبة ويتابع الفقرات والأبواب ثم «انتهى الكتاب»',
    () async {
      expect(await player.start(book, 1), StartResult.started);
      await settle();
      expect(player.state.status, ListeningStatus.playing);
      expect(player.state.paragraphId, 'bk-b001-p00002');
      expect(tts.currentText, 'فقرة ثانية.');
      expect(media.activations, 1);
      expect(media.last!.playing, isTrue);
      expect(media.last!.nowPlaying.chapterTitle, 'الباب الأول');
      expect(media.last!.nowPlaying.bookTitle, 'كتاب الاختبار');
      expect(media.last!.nowPlaying.author, 'مؤلف الاختبار');

      await finish();
      // الباب التالي دون توقف، والشعر بالشطرين مع وقفة.
      expect(player.state.paragraphId, 'bk-b002-p00001');
      expect(media.last!.nowPlaying.chapterTitle, 'الباب الثاني');
      expect(tts.currentText, 'شطر أ');
      await finish();
      expect(tts.currentText, 'شطر ب');
      await finish();
      expect(pauses, [hemistichPause, versePause]);
      expect(tts.currentText, 'فقرة أخيرة.');
      await finish();

      expect(player.state.status, ListeningStatus.idle);
      expect(player.state.active, isFalse);
      expect(events, [ListeningEvent.bookFinished]);
      expect(media.deactivations, 1);
      expect(saved.map((s) => s.$2), [
        'bk-b001-p00002',
        'bk-b002-p00001',
        'bk-b002-p00002',
      ]);
      expect(saved.every((s) => s.$1 == 'bk'), isTrue);
    },
  );

  test('الصوت المحفوظ والسرعة تُطبّق، وصوت غير موجود ← أول صوت', () async {
    await player.start(book, 0, voiceName: 'ar-sa-1', speed: 1.5);
    expect(tts.configured.last, (voice: voiceSa, speed: 1.5));
    expect(player.state.voice, voiceSa);
    await player.stop();
    await player.start(book, 0, voiceName: 'غائب');
    expect(tts.configured.last.voice, voiceEg1);
    expect(tts.configured.last.speed, 1.5, reason: 'السرعة الحالية تبقى');
  });

  test('لا صوت عربي ← noArabicVoice بلا جلسة ولا نطق', () async {
    tts.voices = [];
    expect(await player.start(book, 0), StartResult.noArabicVoice);
    expect(player.state.active, isFalse);
    expect(media.activations, 0);
    expect(tts.spoken, isEmpty);
  });

  test('إيقاف مؤقت ثم استئناف من بداية المقطع، والموضع يُحفظ', () async {
    await player.start(book, 0);
    await settle();
    await player.pause();
    expect(player.state.status, ListeningStatus.paused);
    expect(tts.speaking, isFalse);
    expect(media.last!.playing, isFalse);
    await player.play();
    await settle();
    expect(player.state.playing, isTrue);
    expect(tts.spoken, ['فقرة أولى.', 'فقرة أولى.']);
    expect(saved.map((s) => s.$2), ['bk-b001-p00001']);
  });

  test('التالي والسابق أثناء التشغيل وأثناء الإيقاف، وحدود الكتاب', () async {
    await player.start(book, 0);
    await settle();
    await player.previous();
    expect(player.state.paragraph, 0, reason: 'لا سابق للأولى');
    await player.next();
    await settle();
    expect(player.state.paragraphId, 'bk-b001-p00002');
    expect(tts.currentText, 'فقرة ثانية.');
    await player.pause();
    await player.next();
    await settle();
    expect(player.state.paragraphId, 'bk-b002-p00001');
    expect(player.state.status, ListeningStatus.paused);
    expect(tts.speaking, isFalse, reason: 'التنقل أثناء الإيقاف لا يشغّل');
    expect(media.last!.nowPlaying.id, 'bk-b002-p00001');
    await player.next();
    await player.next();
    expect(
      player.state.paragraphId,
      'bk-b002-p00002',
      reason: 'لا تالي للأخيرة',
    );
  });

  test('إيقاف الاستماع ينهي الجلسة ويحفظ الموضع', () async {
    await player.start(book, 2);
    await settle();
    await player.stop();
    expect(player.state.active, isFalse);
    expect(media.deactivations, 1);
    expect(tts.speaking, isFalse);
    expect(saved.last, ('bk', 'bk-b002-p00001'));
  });

  test('أوامر الإشعار وشاشة القفل وأزرار السماعة', () async {
    await player.start(book, 0);
    await settle();
    media.send(MediaCommand.pause);
    await settle();
    expect(player.state.status, ListeningStatus.paused);
    media.send(MediaCommand.play);
    await settle();
    expect(player.state.playing, isTrue);
    media.send(MediaCommand.next);
    await settle();
    expect(player.state.paragraph, 1);
    media.send(MediaCommand.previous);
    await settle();
    expect(player.state.paragraph, 0);
    media.send(MediaCommand.openPlayer);
    await settle();
    expect(events, [ListeningEvent.openPlayer]);
    media.send(MediaCommand.stop);
    await settle();
    expect(player.state.active, isFalse);
  });

  test('فصل السماعة يوقف مؤقتاً', () async {
    await player.start(book, 0);
    await settle();
    media.send(MediaCommand.becomingNoisy);
    await settle();
    expect(player.state.status, ListeningStatus.paused);
  });

  test('مكالمة: إيقاف مؤقت ثم استئناف إن لم تتجاوز 5 دقائق', () async {
    await player.start(book, 0);
    await settle();
    media.send(MediaCommand.interruptionBegan);
    await settle();
    expect(player.state.status, ListeningStatus.paused);
    now = now.add(const Duration(minutes: 4));
    media.send(MediaCommand.interruptionEnded);
    await settle();
    expect(player.state.playing, isTrue);
  });

  test('مكالمة أطول من 5 دقائق أو فقد التركيز نهائياً: لا استئناف', () async {
    await player.start(book, 0);
    await settle();
    media.send(MediaCommand.interruptionBegan);
    await settle();
    now = now.add(const Duration(minutes: 6));
    media.send(MediaCommand.interruptionEnded);
    await settle();
    expect(player.state.status, ListeningStatus.paused);

    await player.play();
    await settle();
    media.send(MediaCommand.interruptionBegan);
    await settle();
    media.send(MediaCommand.interruptionEndedNoResume);
    media.send(MediaCommand.interruptionEnded);
    await settle();
    expect(player.state.status, ListeningStatus.paused);
  });

  test('إيقاف المستخدم أثناء المكالمة يمنع الاستئناف التلقائي', () async {
    await player.start(book, 0);
    await settle();
    media.send(MediaCommand.interruptionBegan);
    await settle();
    await player.pause();
    media.send(MediaCommand.interruptionEnded);
    await settle();
    expect(player.state.status, ListeningStatus.paused);
  });

  test('خطأ المحرك ← حالة خطأ، و«إعادة المحاولة» تستأنف', () async {
    await player.start(book, 0);
    await settle();
    await finish(SpeakResult.error);
    expect(player.state.status, ListeningStatus.error);
    expect(player.state.active, isTrue, reason: 'المشغّل يبقى ظاهراً');
    expect(events, [ListeningEvent.engineError]);
    expect(media.last!.playing, isFalse);
    await player.play();
    await settle();
    expect(player.state.playing, isTrue);
    expect(tts.currentText, 'فقرة أولى.');
  });

  test('فشل بدء الخدمة أو المحرك ← failed وحالة خطأ', () async {
    media.failActivate = true;
    expect(await player.start(book, 0), StartResult.failed);
    expect(player.state.status, ListeningStatus.error);
  });

  test(
    'تغيير السرعة أثناء التشغيل يعيد المقطع الحالي بالسرعة الجديدة',
    () async {
      await player.start(book, 0);
      await settle();
      await player.setSpeed(2);
      await settle();
      expect(tts.configured.last.speed, 2);
      expect(player.state.speed, 2);
      expect(tts.spoken, ['فقرة أولى.', 'فقرة أولى.']);
      expect(player.state.playing, isTrue);
    },
  );

  test('«جرّب» يوقف التشغيل ويقرأ الجملة ثم يعيد الصوت المختار', () async {
    await player.start(book, 0, voiceName: 'ar-eg-1');
    await settle();
    final trying = player.preview(voiceSa, 'جملة تجربة');
    await settle();
    expect(player.state.status, ListeningStatus.paused);
    expect(tts.currentText, 'جملة تجربة');
    expect(tts.configured.last.voice, voiceSa);
    tts.finish();
    await trying;
    expect(tts.configured.last.voice, voiceEg1);
  });

  test('بدء كتاب آخر يحل محل الجلسة دون إنهاء الخدمة', () async {
    await player.start(book, 0);
    await settle();
    await player.start(book, 3);
    await settle();
    expect(player.state.paragraphId, 'bk-b002-p00002');
    expect(media.activations, 1);
    expect(tts.currentText, 'فقرة أخيرة.');
  });

  test('التقدّم داخل الباب', () async {
    await player.start(book, 1);
    expect(player.state.chapterProgress, 1.0);
    await player.previous();
    expect(player.state.chapterProgress, 0.5);
  });
}
