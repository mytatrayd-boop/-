import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/incoming_link.dart';
import '../../domain/models/now_playing.dart';
import '../../domain/ports/playback_controller.dart';
import '../../domain/youtube_link_parser.dart';
import '../../l10n/gen/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
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
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw, {bool shared = false}) async {
    final controller = ref.read(playbackControllerProvider);
    try {
      final link = shared ? parseSharedText(raw) : parseYoutubeLink(raw);
      final id = link.videoId;
      if (id == null) throw const AppFailure(FailureKind.playlistNotSupported);
      setState(() => _linkFailure = null);
      FocusScope.of(context).unfocus();
      await controller.playVideo(id);
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

    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle), backgroundColor: AppColors.background),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            children: [
              Expanded(child: _NowPlayingArea(controller: controller, linkFailure: _linkFailure)),
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
  const _NowPlayingArea({required this.controller, required this.linkFailure});

  final PlaybackController controller;
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
        return _PlayerPanel(controller: controller, now: now);
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
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
  const _PlayerPanel({required this.controller, required this.now});

  final PlaybackController controller;
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
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: l.stop,
              iconSize: 32,
              constraints: const BoxConstraints.tightFor(width: 56, height: 56),
              onPressed: controller.stop,
              icon: const Icon(Icons.stop),
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
          ],
        ),
      ],
    );
  }
}
