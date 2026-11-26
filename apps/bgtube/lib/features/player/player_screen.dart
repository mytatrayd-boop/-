import 'dart:async';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/incoming_link.dart';
import '../../domain/models/now_playing.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/playback_queue_model.dart';
import '../../domain/playback_speed.dart';
import '../../domain/sleep_timer.dart';
import '../../domain/ports/playback_controller.dart';
import '../../domain/ports/playback_queue.dart';
import '../../domain/youtube_link_parser.dart';
import '../../l10n/gen/app_localizations.dart';
import '../local_playlists/local_playlists_screen.dart';
import '../queue/queue_sheet.dart';
import '../queue/queue_ui.dart';
import '../settings/settings_screen.dart';
import 'failure_message.dart';
import 'format_duration.dart';
import 'text_direction.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _text = TextEditingController();
  AppFailure? _linkFailure;

  StreamSubscription<String>? _incomingSub;
  StreamSubscription<VideoRef>? _skippedSub;

  @override
  void initState() {
    super.initState();
    // مقطع فشل وتُخطّي: رسالة قصيرة (DESIGN 4أ).
    _skippedSub = ref.read(playbackQueueProvider).skippedFailures.listen((r) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      showUndoSnack(ScaffoldMessenger.of(context), l, l.queueSkippedSnack(shortTitle(l, r)));
    });
    final source = ref.read(incomingLinkSourceProvider);
    // أثناء التشغيل.
    _incomingSub = source.texts.listen(_handleIncoming);
    // بدء بارد.
    source.initialText().then((t) {
      if (t != null && mounted) _handleIncoming(t);
    }).catchError((Object _) {
      // فشل قراءة نية البدء لا يجب أن يُسقط التطبيق؛ يبدأ فارغاً.
    });
  }

  Future<void> _handleIncoming(String shared) async {
    if (!mounted) return;
    _text.text = shared;
    await _submit(shared, shared: true);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _skippedSub?.cancel();
    _text.dispose();
    super.dispose();
  }

  /// لصق أو مشاركة: إن كان الطابور فارغاً يبدأ التشغيل مباشرة بلا ورقة، وإلا
  /// ورقة بثلاثة خيارات: «شغّل الآن» و«شغّل التالي» و«أضف للنهاية» (DESIGN ⋮).
  Future<void> _submit(String raw, {bool shared = false}) async {
    final queue = ref.read(playbackQueueProvider);
    try {
      final link = shared ? parseSharedText(raw) : parseYoutubeLink(raw);
      final id = link.videoId;
      if (id == null) throw const AppFailure(FailureKind.playlistNotSupported);
      setState(() => _linkFailure = null);
      FocusScope.of(context).unfocus();
      final refs = [VideoRef(videoId: id)];
      if (queue.queueState.value.isEmpty) {
        await queue.enqueue(refs, QueuePlacement.playNow);
        return;
      }
      final placement = await showPlacementSheet(context, includePlayNow: true);
      if (placement == null || !mounted) return;
      await enqueueWithFeedback(context, queue, refs, placement);
    } on AppFailure catch (f) {
      setState(() => _linkFailure = f);
    }
  }

  Future<void> _pasteAndPlay() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).clipboardEmpty)));
      return;
    }
    _text.text = text;
    await _submit(text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = ref.watch(playbackControllerProvider);
    final queue = ref.watch(playbackQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.appTitle),
        backgroundColor: AppColors.background,
        actions: [
          // بعد الإيقاف يختفي المشغّل ويبقى الطابور محفوظاً: مدخل إليه من هنا.
          ListenableBuilder(
            listenable: Listenable.merge([controller.nowPlaying, queue.queueState]),
            builder: (context, _) => controller.nowPlaying.value == null && !queue.queueState.value.isEmpty
                ? IconButton(
                    key: const Key('appBarQueue'),
                    tooltip: l.queueTitle,
                    icon: const Icon(Icons.queue_music),
                    onPressed: () => showQueueSheet(context),
                  )
                : const SizedBox.shrink(),
          ),
          // المكتبة لم تُبنَ بعد: «قوائمي المحلية» من هنا (D28).
          IconButton(
            key: const Key('openLocalPlaylists'),
            tooltip: l.localPlaylists,
            icon: const Icon(Icons.library_music_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const LocalPlaylistsScreen())),
          ),
          IconButton(
            tooltip: l.settings,
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            children: [
              Expanded(child: _NowPlayingArea(controller: controller, queue: queue, linkFailure: _linkFailure)),
              const SizedBox(height: 16),
              _InputRow(
                controller: _text,
                onSubmit: _submit,
                onPaste: _pasteAndPlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({required this.controller, required this.onSubmit, required this.onPaste});

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          textDirection: TextDirection.ltr, // الروابط لاتينية دائماً
          decoration: InputDecoration(hintText: l.linkHint),
          onSubmitted: onSubmit,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onPaste,
          icon: const Icon(Icons.content_paste),
          label: Text(l.pasteAndPlay),
        ),
      ],
    );
  }
}

class _NowPlayingArea extends StatelessWidget {
  const _NowPlayingArea({required this.controller, required this.queue, required this.linkFailure});

  final PlaybackController controller;
  final PlaybackQueue queue;
  final AppFailure? linkFailure;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller.failure, controller.resolving, controller.nowPlaying]),
      builder: (context, _) {
        final failure = linkFailure ?? controller.failure.value;
        final now = controller.nowPlaying.value;
        final resolving = controller.resolving.value;

        if (failure != null) {
          return _ErrorView(
            message: failureMessage(l, failure),
            detail: failure.debugDetail,
            // إعادة المحاولة تخصّ فشل التشغيل لا الرابط غير الصالح.
            onRetry: linkFailure == null ? controller.retry : null,
          );
        }
        if (resolving) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l.resolving),
              ],
            ),
          );
        }
        if (now == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headphones, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(l.emptyTitle, textAlign: TextAlign.center),
              ],
            ),
          );
        }
        return _PlayerPanel(controller: controller, queue: queue, now: now);
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.detail, this.onRetry});

  final String message;

  /// تشخيص تقني قصير (نوع الاستثناء/رمز HTTP) بخط صغير، لتفيد لقطة الشاشة.
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
          if (detail case final d? when d.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
              child: SelectableText(
                d,
                key: const Key('failureDetail'),
                textAlign: TextAlign.center,
                // نص تقني لاتيني: اتجاه يسار-يمين حتى داخل واجهة عربية.
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l.retry)),
          ],
        ],
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({required this.controller, required this.queue, required this.now});

  final PlaybackController controller;
  final PlaybackQueue queue;
  final NowPlaying now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          now.title,
          textDirection: textDirectionFor(now.title),
          textAlign: TextAlign.start,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (now.author != null)
          Text(now.author!,
              textDirection: textDirectionFor(now.author!),
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        // شريط التقدم ثابت LTR (DESIGN.md).
        Directionality(
          textDirection: TextDirection.ltr,
          child: StreamBuilder<Duration>(
            stream: controller.positionStream,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final total = now.duration;
              final max = total?.inMilliseconds.toDouble() ?? 0;
              final value = pos.inMilliseconds.toDouble().clamp(0, max > 0 ? max : 1).toDouble();
              return Column(
                children: [
                  Slider(
                    value: max > 0 ? value : 0,
                    max: max > 0 ? max : 1,
                    onChanged: max > 0
                        ? (v) => controller.seek(Duration(milliseconds: v.round()))
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(pos, locale)),
                        Text(total == null ? '' : formatDuration(total, locale)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _NextUpLine(queue: queue),
        const SizedBox(height: 4),
        // ترتيب (السابق | تشغيل | التالي) ثابت LTR كعُرف المشغّلات (DESIGN).
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<QueueSnapshot>(
            valueListenable: queue.queueState,
            builder: (context, s, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const Key('previousButton'),
                  tooltip: l.previous,
                  iconSize: 32,
                  constraints: const BoxConstraints.tightFor(width: 56, height: 56),
                  // «السابق» بعد ٣ ث يعيد المقطع من بدايته، فيبقى مفعّلاً.
                  onPressed: queue.skipToPrevious,
                  icon: const Icon(Icons.skip_previous),
                ),
                const SizedBox(width: 16),
                ValueListenableBuilder<bool>(
                  valueListenable: controller.playing,
                  builder: (context, playing, _) => IconButton.filled(
                    tooltip: playing ? l.pause : l.play,
                    iconSize: 40,
                    constraints: const BoxConstraints.tightFor(width: 64, height: 64),
                    onPressed: playing ? controller.pause : controller.play,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  key: const Key('nextButton'),
                  tooltip: l.next,
                  iconSize: 32,
                  constraints: const BoxConstraints.tightFor(width: 56, height: 56),
                  onPressed: s.next == null ? null : queue.skipToNext, // معطّل في آخر الطابور
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: l.stop,
              iconSize: 28,
              constraints: const BoxConstraints.tightFor(width: 56, height: 56),
              onPressed: controller.stop,
              icon: const Icon(Icons.stop),
            ),
            _SpeedButton(controller: controller),
            _SleepButton(controller: controller),
            _QueueButton(queue: queue),
          ],
        ),
      ],
    );
  }
}

/// «التالي: {العنوان}» (سطر واحد) عند وجود طابور؛ يفتح شاشة الطابور.
class _NextUpLine extends StatelessWidget {
  const _NextUpLine({required this.queue});
  final PlaybackQueue queue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<QueueSnapshot>(
      valueListenable: queue.queueState,
      builder: (context, s, _) {
        final next = s.next;
        if (next == null) return const SizedBox(height: 0);
        final text = l.queueNextUp(videoTitle(l, next.ref));
        return InkWell(
          key: const Key('nextUpLine'),
          onTap: () => showQueueSheet(context),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        );
      },
    );
  }
}

/// زر الطابور مع شارة عدد المتبقي.
class _QueueButton extends StatelessWidget {
  const _QueueButton({required this.queue});
  final PlaybackQueue queue;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<QueueSnapshot>(
      valueListenable: queue.queueState,
      builder: (context, s, _) {
        final n = s.remainingCount;
        return IconButton(
          key: const Key('queueButton'),
          tooltip: n == 0 ? l.queueTitle : '${l.queueTitle} · ${l.queueRemaining(formatCount(context, n))}',
          constraints: const BoxConstraints.tightFor(width: 56, height: 56),
          onPressed: () => showQueueSheet(context),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(formatCount(context, n)),
            child: const Icon(Icons.queue_music),
          ),
        );
      },
    );
  }
}

String speedText(AppLocalizations l, String locale, double s) =>
    l.speedValue(NumberFormat('0.##', locale).format(s));

class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return ValueListenableBuilder<double>(
      valueListenable: controller.speed,
      builder: (context, speed, _) => TextButton(
        key: const Key('speedButton'),
        style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
        onPressed: () => _showSheet(context, l, locale),
        child: Text(speedText(l, locale, speed)),
      ),
    );
  }

  void _showSheet(BuildContext context, AppLocalizations l, String locale) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Text(l.speed, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            for (final s in playbackSpeeds)
              ListTile(
                key: Key('speed_$s'),
                minTileHeight: 56,
                title: Text(speedText(l, locale, s)),
                trailing: controller.speed.value == s ? const Icon(Icons.check) : null,
                onTap: () {
                  controller.setSpeed(s);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SleepButton extends StatelessWidget {
  const _SleepButton({required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    return ValueListenableBuilder<Duration?>(
      valueListenable: controller.sleepRemaining,
      builder: (context, remaining, _) => TextButton(
        key: const Key('sleepButton'),
        style: TextButton.styleFrom(minimumSize: const Size(56, 56)),
        onPressed: () => _showSheet(context, l, locale),
        child: remaining == null
            ? const Icon(Icons.bedtime_outlined)
            : Text(formatDuration(remaining, locale)),
      ),
    );
  }

  void _showSheet(BuildContext context, AppLocalizations l, String locale) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Text(l.sleepTimer, style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            for (final d in sleepTimerOptions)
              ListTile(
                key: Key('sleep_${d.inMinutes}'),
                minTileHeight: 56,
                title: Text(l.sleepMinutes(NumberFormat.decimalPattern(locale).format(d.inMinutes))),
                onTap: () {
                  controller.startSleepTimer(d);
                  Navigator.of(sheetContext).pop();
                },
              ),
            if (controller.sleepRemaining.value != null)
              ListTile(
                key: const Key('sleepCancel'),
                minTileHeight: 56,
                leading: const Icon(Icons.close),
                title: Text(l.sleepCancel),
                onTap: () {
                  controller.cancelSleepTimer();
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
