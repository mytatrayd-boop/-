/// منطق الاستماع (ARCHITECTURE §10، DESIGN §10): تسلسل الفقرات والمقاطع،
/// التشغيل والإيقاف والتالي والسابق، أوامر الإشعار والسماعة والمقاطعات، وحفظ
/// الموضع. يعتمد على [TtsEngine] و[MediaSession] فقط، فيُختبر بمحاكاتهما.
/// Dart صافٍ بلا Flutter.
library;

import 'dart:async';

import '../reader/reader_book.dart';
import 'speech_text.dart';
import 'tts_engine.dart';

enum ListeningStatus {
  /// لا جلسة استماع.
  idle,

  /// تجهيز الصوت (قائمة الأصوات، بدء الخدمة).
  preparing,
  playing,
  paused,

  /// توقف بسبب خطأ في المحرك؛ «إعادة المحاولة» = [ListeningPlayer.play].
  error,
}

/// السرعات المتاحة (DESIGN §10.2).
const listeningSpeeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 2];
const defaultListeningSpeed = 1.0;

class ListeningState {
  const ListeningState({
    this.status = ListeningStatus.idle,
    this.book,
    this.paragraph = 0,
    this.speed = defaultListeningSpeed,
    this.voice,
  });

  final ListeningStatus status;

  /// الكتاب المسموع (null عند [ListeningStatus.idle]).
  final ReaderBook? book;

  /// فهرس الفقرة الجارية في [ReaderBook.paragraphs].
  final int paragraph;
  final double speed;
  final TtsVoice? voice;

  /// توجد جلسة (تشغيل أو إيقاف مؤقت أو تجهيز أو خطأ): يظهر المشغّل المصغّر.
  bool get active => status != ListeningStatus.idle && book != null;

  bool get playing => status == ListeningStatus.playing;

  String? get bookId => active ? book!.id : null;

  ReaderParagraph? get current => active && book!.paragraphs.isNotEmpty
      ? book!.paragraphs[paragraph]
      : null;

  String? get paragraphId => current?.id;

  ReaderChapter? get chapter {
    final p = current;
    return p == null ? null : book!.chapters[p.chapterIndex];
  }

  /// التقدّم داخل الباب الحالي (0–1) للخط الرفيع فوق المشغّل المصغّر.
  double get chapterProgress {
    final p = current;
    final c = chapter;
    if (p == null || c == null || c.firstParagraph < 0) return 0;
    var count = 0;
    for (
      var i = c.firstParagraph;
      i < book!.paragraphs.length &&
          book!.paragraphs[i].chapterIndex == p.chapterIndex;
      i++
    ) {
      count++;
    }
    return count == 0 ? 0 : (paragraph - c.firstParagraph + 1) / count;
  }

  ListeningState copyWith({
    ListeningStatus? status,
    ReaderBook? book,
    int? paragraph,
    double? speed,
    TtsVoice? voice,
  }) => ListeningState(
    status: status ?? this.status,
    book: book ?? this.book,
    paragraph: paragraph ?? this.paragraph,
    speed: speed ?? this.speed,
    voice: voice ?? this.voice,
  );
}

enum StartResult {
  started,

  /// لا صوت عربي على الجهاز: تُعرض إرشادات التثبيت.
  noArabicVoice,

  /// تعذّر بدء المحرك أو الخدمة.
  failed,
}

/// أحداث لمرة واحدة للواجهة.
enum ListeningEvent { bookFinished, engineError, openPlayer }

typedef PositionSaver = Future<void> Function(
  String bookId,
  String paragraphId,
);

class ListeningPlayer {
  ListeningPlayer({
    required this._engine,
    required MediaSession session,
    required this._savePosition,
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
    this.maxInterruptionToResume = const Duration(minutes: 5),
  }) : _session = session,
       _clock = clock ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed {
    _commands = session.commands.listen(_onCommand);
  }

  final TtsEngine _engine;
  final MediaSession _session;
  final PositionSaver _savePosition;
  final DateTime Function() _clock;

  /// الوقفات بين شطري البيت وبعده (قابلة للحقن في الاختبار).
  final Future<void> Function(Duration) _delay;

  /// مكالمة أطول من هذا لا يُستأنف بعدها تلقائياً (DESIGN §10.3).
  final Duration maxInterruptionToResume;

  late final StreamSubscription<MediaCommand> _commands;
  final _states = StreamController<ListeningState>.broadcast();
  final _events = StreamController<ListeningEvent>.broadcast();

  var _state = const ListeningState();

  /// يزيد مع كل تغيير يُبطل حلقة النطق الجارية.
  int _token = 0;
  List<SpeechChunk>? _chunks;
  int _chunk = 0;
  bool _sessionActive = false;
  DateTime? _interruptedAt;
  String? _lastSaved;
  MediaSessionState? _lastSession;
  bool _disposed = false;

  ListeningState get state => _state;
  Stream<ListeningState> get states => _states.stream;
  Stream<ListeningEvent> get events => _events.stream;

  void _set(ListeningState next) {
    _state = next;
    if (!_disposed) _states.add(next);
    _pushSession();
  }

  void _pushSession() {
    if (!_sessionActive) return;
    final s = _state;
    final p = s.current;
    final c = s.chapter;
    if (p == null || c == null) return;
    final next = MediaSessionState(
      playing: s.status == ListeningStatus.playing,
      loading: s.status == ListeningStatus.preparing,
      nowPlaying: NowPlaying(
        id: p.id,
        chapterTitle: c.title,
        bookTitle: s.book!.title.ar,
        author: s.book!.author.ar,
      ),
    );
    if (next == _lastSession) return;
    _lastSession = next;
    _session.update(next);
  }

  void _savePositionNow() {
    final s = _state;
    final id = s.paragraphId;
    if (id == null || id == _lastSaved) return;
    _lastSaved = id;
    unawaited(
      _savePosition(s.book!.id, id).catchError((Object _) {
        if (_lastSaved == id) _lastSaved = null;
      }),
    );
  }

  /// يبدأ الاستماع من [paragraph] في [book] (يحل محل أي جلسة قائمة).
  /// [voiceName] الصوت المحفوظ إن وُجد، وإلا أول صوت عربي.
  Future<StartResult> start(
    ReaderBook book,
    int paragraph, {
    String? voiceName,
    double? speed,
  }) async {
    if (book.paragraphs.isEmpty) return StartResult.failed;
    final token = ++_token;
    final List<TtsVoice> voices;
    try {
      voices = await _engine.arabicVoices();
    } on Object {
      return StartResult.failed;
    }
    if (token != _token) return StartResult.failed;
    if (voices.isEmpty) return StartResult.noArabicVoice;
    final voice = voices.firstWhere(
      (v) => v.name == voiceName,
      orElse: () => voices.first,
    );
    final rate = speed ?? _state.speed;
    await _engine.stop();
    _interruptedAt = null;
    _chunks = null;
    _chunk = 0;
    _lastSaved = null;
    _set(
      ListeningState(
        status: ListeningStatus.preparing,
        book: book,
        paragraph: paragraph.clamp(0, book.paragraphs.length - 1),
        speed: rate,
        voice: voice,
      ),
    );
    try {
      await _engine.configure(voice: voice, speed: rate);
      if (!_sessionActive) {
        await _session.activate();
        _sessionActive = true;
        _lastSession = null;
      }
    } on Object {
      if (token == _token) _fail();
      return StartResult.failed;
    }
    if (token != _token) return StartResult.failed;
    _savePositionNow();
    _set(_state.copyWith(status: ListeningStatus.playing));
    unawaited(_loop(token));
    return StartResult.started;
  }

  Future<void> _loop(int token) async {
    while (token == _token && !_disposed) {
      final s = _state;
      final book = s.book!;
      final p = book.paragraphs[s.paragraph];
      final chunks = _chunks ??= speechChunks(p.text, p.kind);
      if (_chunk >= chunks.length) {
        if (s.paragraph + 1 >= book.paragraphs.length) {
          _finish();
          return;
        }
        _moveTo(s.paragraph + 1);
        continue;
      }
      final chunk = chunks[_chunk];
      SpeakResult result;
      try {
        result = await _engine.speak(chunk.text);
      } on Object {
        result = SpeakResult.error;
      }
      if (token != _token) return;
      switch (result) {
        case SpeakResult.error:
          _fail();
          return;
        case SpeakResult.cancelled:
          // أوقفه غيرنا (مثلاً النظام): إيقاف مؤقت لا خطأ.
          unawaited(_pauseInternal());
          return;
        case SpeakResult.done:
          break;
      }
      if (chunk.pauseAfter > Duration.zero) {
        await _delay(chunk.pauseAfter);
        if (token != _token) return;
      }
      _chunk++;
    }
  }

  void _moveTo(int paragraph) {
    _chunks = null;
    _chunk = 0;
    _set(_state.copyWith(paragraph: paragraph));
    _savePositionNow();
  }

  void _finish() {
    _token++;
    _savePositionNow();
    unawaited(_endSession());
    _set(ListeningState(speed: _state.speed, voice: _state.voice));
    if (!_disposed) _events.add(ListeningEvent.bookFinished);
  }

  void _fail() {
    _token++;
    _set(_state.copyWith(status: ListeningStatus.error));
    if (!_disposed) _events.add(ListeningEvent.engineError);
  }

  Future<void> _endSession() async {
    if (!_sessionActive) return;
    _sessionActive = false;
    _lastSession = null;
    try {
      await _session.deactivate();
    } on Object {
      // الإشعار يختفي مع إيقاف الخدمة على أي حال.
    }
  }

  /// يستأنف (أو يعيد المحاولة بعد خطأ) من بداية المقطع الحالي.
  Future<void> play() async {
    if (!_state.active || _state.playing) return;
    if (_state.status == ListeningStatus.preparing) return;
    _interruptedAt = null;
    final token = ++_token;
    try {
      if (!_sessionActive) {
        await _session.activate();
        _sessionActive = true;
        _lastSession = null;
      }
      if (_state.status == ListeningStatus.error) {
        await _engine.configure(voice: _state.voice, speed: _state.speed);
      }
    } on Object {
      if (token == _token) _fail();
      return;
    }
    if (token != _token) return;
    _set(_state.copyWith(status: ListeningStatus.playing));
    unawaited(_loop(token));
  }

  /// إيقاف مؤقت بأمر المستخدم.
  Future<void> pause() async {
    _interruptedAt = null;
    await _pauseInternal();
  }

  Future<void> _pauseInternal() async {
    final s = _state.status;
    if (s != ListeningStatus.playing && s != ListeningStatus.preparing) return;
    _token++;
    _set(_state.copyWith(status: ListeningStatus.paused));
    _savePositionNow();
    await _engine.stop();
  }

  Future<void> togglePlay() => _state.playing ? pause() : play();

  Future<void> next() => _skip(1);

  Future<void> previous() => _skip(-1);

  Future<void> _skip(int delta) async {
    if (!_state.active) return;
    final target = _state.paragraph + delta;
    if (target < 0 || target >= _state.book!.paragraphs.length) return;
    final wasPlaying = _state.playing;
    final token = ++_token;
    await _engine.stop();
    if (token != _token) return;
    _moveTo(target);
    if (wasPlaying) unawaited(_loop(token));
  }

  /// ينهي الجلسة ويحفظ الموضع ويخفي المشغّل.
  Future<void> stop() async {
    if (_state.book == null) return;
    _token++;
    _interruptedAt = null;
    _savePositionNow();
    _set(ListeningState(speed: _state.speed, voice: _state.voice));
    await _engine.stop();
    await _endSession();
  }

  /// يغيّر السرعة؛ أثناء التشغيل يُعاد المقطع الحالي بالسرعة الجديدة.
  Future<void> setSpeed(double speed) =>
      _reconfigure(speed: speed, voice: _state.voice);

  Future<void> setVoice(TtsVoice voice) =>
      _reconfigure(speed: _state.speed, voice: voice);

  Future<void> _reconfigure({
    required double speed,
    required TtsVoice? voice,
  }) async {
    _state = _state.copyWith(speed: speed, voice: voice);
    _set(_state);
    final wasPlaying = _state.playing;
    final token = wasPlaying ? ++_token : _token;
    if (wasPlaying) await _engine.stop();
    try {
      await _engine.configure(voice: voice, speed: speed);
    } on Object {
      if (token == _token && wasPlaying) _fail();
      return;
    }
    if (wasPlaying && token == _token) unawaited(_loop(token));
  }

  /// «جرّب» (DESIGN §10.2): يقرأ [text] بالصوت [voice] ثم يعيد الصوت المختار.
  /// يوقف التشغيل الجاري مؤقتاً.
  Future<void> preview(TtsVoice voice, String text) async {
    await pause();
    try {
      await _engine.configure(voice: voice, speed: _state.speed);
      await _engine.speak(text);
    } on Object {
      return;
    } finally {
      try {
        await _engine.configure(voice: _state.voice, speed: _state.speed);
      } on Object {
        // يُعاد ضبطه عند التشغيل التالي.
      }
    }
  }

  void _onCommand(MediaCommand command) {
    switch (command) {
      case MediaCommand.play:
        unawaited(play());
      case MediaCommand.pause:
        unawaited(pause());
      case MediaCommand.next:
        unawaited(next());
      case MediaCommand.previous:
        unawaited(previous());
      case MediaCommand.stop:
        unawaited(stop());
      case MediaCommand.becomingNoisy:
        unawaited(pause());
      case MediaCommand.interruptionBegan:
        if (_state.playing || _state.status == ListeningStatus.preparing) {
          unawaited(_pauseInternal());
          _interruptedAt = _clock();
        }
      case MediaCommand.interruptionEnded:
        final at = _interruptedAt;
        _interruptedAt = null;
        if (at != null &&
            _state.status == ListeningStatus.paused &&
            _clock().difference(at) <= maxInterruptionToResume) {
          unawaited(play());
        }
      case MediaCommand.interruptionEndedNoResume:
        _interruptedAt = null;
      case MediaCommand.openPlayer:
        if (!_disposed) _events.add(ListeningEvent.openPlayer);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _token++;
    await _commands.cancel();
    await _states.close();
    await _events.close();
    try {
      await _engine.stop();
    } on Object {
      // لا شيء.
    }
    await _endSession();
  }
}
