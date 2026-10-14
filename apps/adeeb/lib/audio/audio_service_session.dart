import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';

import 'tts_engine.dart';

/// جلسة الوسائط الفعلية (D7): `audio_service` للخدمة الأمامية والإشعار وشاشة
/// القفل وأزرار السماعة، و`audio_session` (إعداد «speech») للتركيز الصوتي
/// والمكالمات وفصل السماعة. لا تُختبر هنا (تحتاج جهازاً)؛ المنطق كله في
/// `ListeningPlayer` ويُختبر بمحاكاة [MediaSession].
class AudioServiceSession implements MediaSession {
  AudioServiceSession({
    required this.channelName,
    required this.subtitle,
    required this.controlLabels,
  });

  /// اسم قناة الإشعار («القراءة الصوتية»، DESIGN §10.3).
  final String channelName;

  /// السطر الثاني في الإشعار: «الكتاب — المؤلف».
  final String Function(String book, String author) subtitle;

  /// تسميات الأزرار لقارئ الشاشة: السابق، تشغيل، إيقاف مؤقت، التالي.
  final ({String previous, String play, String pause, String next})
  controlLabels;

  final _commands = StreamController<MediaCommand>.broadcast();
  Future<_Handler>? _handler;
  Future<AudioSession>? _audioSession;
  final _subscriptions = <StreamSubscription<Object?>>[];

  @override
  Stream<MediaCommand> get commands => _commands.stream;

  Future<_Handler> _initHandler() => _handler ??=
      AudioService.init(
        builder: () => _Handler(_commands.add),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.adeebai.adeeb.listening',
          androidNotificationChannelName: channelName,
          // يمكن إغلاق الإشعار بالسحب عند الإيقاف المؤقت فقط (DESIGN §10.3).
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: false,
        ),
      ).then((h) {
        _subscriptions.add(
          AudioService.notificationClicked.listen((clicked) {
            if (clicked) _commands.add(MediaCommand.openPlayer);
          }),
        );
        return h;
      });

  Future<AudioSession> _initAudioSession() => _audioSession ??= () async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _subscriptions
      ..add(
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            _commands.add(MediaCommand.interruptionBegan);
          } else {
            _commands.add(
              event.type == AudioInterruptionType.unknown
                  ? MediaCommand.interruptionEndedNoResume
                  : MediaCommand.interruptionEnded,
            );
          }
        }),
      )
      ..add(
        session.becomingNoisyEventStream.listen(
          (_) => _commands.add(MediaCommand.becomingNoisy),
        ),
      );
    return session;
  }();

  @override
  Future<bool> activate() async {
    await _initHandler();
    final session = await _initAudioSession();
    return session.setActive(true);
  }

  @override
  void update(MediaSessionState state) {
    unawaited(
      _initHandler().then((h) {
        final n = state.nowPlaying;
        h.mediaItem.add(
          MediaItem(
            id: n.id,
            title: n.chapterTitle,
            album: n.bookTitle,
            artist: n.author,
            displayTitle: n.chapterTitle,
            displaySubtitle: subtitle(n.bookTitle, n.author),
          ),
        );
        final labels = controlLabels;
        h.playbackState.add(
          PlaybackState(
            controls: [
              // أثناء التجهيز لا سابق ولا تالي (كأزرار التطبيق).
              if (!state.loading)
                _control(MediaControl.skipToPrevious, labels.previous),
              if (state.playing)
                _control(MediaControl.pause, labels.pause)
              else
                _control(MediaControl.play, labels.play),
              if (!state.loading)
                _control(MediaControl.skipToNext, labels.next),
            ],
            systemActions: const {
              MediaAction.play,
              MediaAction.pause,
              MediaAction.playPause,
              MediaAction.skipToNext,
              MediaAction.skipToPrevious,
              MediaAction.stop,
            },
            // العرض المضغوط: «تشغيل/إيقاف» فقط (DESIGN §10.3).
            androidCompactActionIndices: [state.loading ? 0 : 1],
            processingState: state.loading
                ? AudioProcessingState.loading
                : AudioProcessingState.ready,
            playing: state.playing,
          ),
        );
      }),
    );
  }

  /// الزر الافتراضي بأيقونته مع تسمية من ARB.
  static MediaControl _control(MediaControl base, String label) => MediaControl(
    androidIcon: base.androidIcon,
    label: label,
    action: base.action,
  );

  @override
  Future<void> deactivate() async {
    final h = await _initHandler();
    // الحالة idle توقف الخدمة الأمامية وتزيل الإشعار.
    h.playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle),
    );
    h.mediaItem.add(null);
    final session = await _audioSession;
    await session?.setActive(false);
  }
}

/// يحوّل أوامر النظام (الإشعار، شاشة القفل، السماعة، بلوتوث السيارة) إلى
/// [MediaCommand]. زر السماعة الواحد يمر بـ `click` الافتراضي إلى play/pause،
/// والضغط المزدوج إلى التالي.
class _Handler extends BaseAudioHandler {
  _Handler(this._send);

  final void Function(MediaCommand) _send;

  @override
  Future<void> play() async => _send(MediaCommand.play);

  @override
  Future<void> pause() async => _send(MediaCommand.pause);

  @override
  Future<void> skipToNext() async => _send(MediaCommand.next);

  @override
  Future<void> skipToPrevious() async => _send(MediaCommand.previous);

  @override
  Future<void> stop() async => _send(MediaCommand.stop);

  /// سحب الإشعار (ممكن عند الإيقاف المؤقت فقط) ينهي الجلسة.
  @override
  Future<void> onNotificationDeleted() async => _send(MediaCommand.stop);

  @override
  Future<void> onTaskRemoved() async => _send(MediaCommand.stop);
}
