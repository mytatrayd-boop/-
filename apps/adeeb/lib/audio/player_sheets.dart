import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/generated_cover.dart';
import '../library/library_text.dart';
import '../reader/reader_book.dart';
import 'listen_actions.dart';
import 'listening_player.dart';
import 'listening_providers.dart';
import 'tts_engine.dart';

/// «لا يوجد صوت عربي على جهازك» (DESIGN §10.4).
Future<void> showNoArabicVoiceSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const NoArabicVoiceSheet(),
    );

class NoArabicVoiceSheet extends ConsumerStatefulWidget {
  const NoArabicVoiceSheet({super.key});

  @override
  ConsumerState<NoArabicVoiceSheet> createState() => _NoArabicVoiceSheetState();
}

class _NoArabicVoiceSheetState extends ConsumerState<NoArabicVoiceSheet> {
  bool _showAlternative = false;

  Future<void> _openSettings() async {
    final opened = await ref.read(ttsEngineProvider).openInstallSettings();
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      setState(() => _showAlternative = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.audioNoVoiceTitle, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 12),
          Text(l10n.audioNoVoiceBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _showAlternative = true),
              child: Text(l10n.audioNoVoiceHelp),
            ),
          ),
          if (_showAlternative)
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.audioNoVoiceAlternative,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _openSettings,
            child: Text(l10n.audioOpenVoiceSettings),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.later),
          ),
        ],
      ),
    );
  }
}

/// قائمة الأصوات العربية مع «جرّب» (DESIGN §10.2).
Future<void> showVoicePicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const VoicePickerSheet(),
    );

class VoicePickerSheet extends ConsumerWidget {
  const VoicePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final voicesAsync = ref.watch(arabicVoicesProvider);
    final selected =
        ref.watch(listeningStateProvider).voice?.name ??
        ref.watch(audioSettingsProvider).value?.voiceName;
    final voices = voicesAsync.value;
    if (voices == null) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Center(
          child: voicesAsync.hasError
              ? Text(l10n.audioEngineError)
              : Semantics(
                  label: l10n.loading,
                  child: const CircularProgressIndicator(),
                ),
        ),
      );
    }
    if (voices.isEmpty) return const NoArabicVoiceSheet();
    final current = voices
        .where((v) => v.name == selected)
        .firstOrNull ?? voices.first;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsetsDirectional.only(bottom: 16),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
          child: Semantics(
            header: true,
            child: Text(l10n.audioVoice, style: theme.textTheme.titleLarge),
          ),
        ),
        for (final v in voices)
          _VoiceTile(
            label: voiceLabel(l10n, voices, v, lang),
            selected: v == current,
            onSelect: () =>
                ref.read(audioSettingsProvider.notifier).setVoice(v),
            onTry: () => ref
                .read(listeningPlayerProvider)
                .preview(v, l10n.audioSample),
          ),
      ],
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.label,
    required this.selected,
    required this.onSelect,
    required this.onTry,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      minTileHeight: 56,
      selected: selected,
      // الاختيار بعلامة ✓ لا باللون وحده (DESIGN §16.5).
      leading: Icon(selected ? Icons.check_circle : Icons.circle_outlined),
      title: Text(label),
      onTap: onSelect,
      trailing: Semantics(
        label: l10n.audioTryVoiceSemantics(label),
        excludeSemantics: true,
        button: true,
        child: TextButton(onPressed: onTry, child: Text(l10n.audioTryVoice)),
      ),
    );
  }
}

/// المشغّل الكامل (DESIGN §10.2) في ورقة بملء الشاشة.
Future<void> showFullPlayer(
  BuildContext context, {
  required void Function(ListeningState state) onGoToText,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => FullPlayer(onGoToText: onGoToText),
);

class FullPlayer extends ConsumerWidget {
  const FullPlayer({super.key, required this.onGoToText});

  final void Function(ListeningState state) onGoToText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final s = ref.watch(listeningStateProvider);
    ref.listen(listeningStateProvider, (previous, next) {
      // انتهت الجلسة (إيقاف أو نهاية الكتاب): تُغلق الورقة.
      if (previous?.active == true && !next.active) {
        Navigator.of(context).maybePop();
      }
    });
    final book = s.book;
    final paragraph = s.current;
    final chapter = s.chapter;
    if (book == null || paragraph == null) return const SizedBox.shrink();
    final player = ref.read(listeningPlayerProvider);
    final settings = ref.watch(audioSettingsProvider).value;
    final speed = s.active ? s.speed : settings?.speed ?? s.speed;
    final voices = ref.watch(arabicVoicesProvider).value ?? const [];
    final voice = s.voice;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height,
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.audioPlayerTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.audioMinimize,
                icon: const Icon(Icons.keyboard_arrow_down),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: GeneratedCover(
              bookId: book.id,
              title: book.title.ar,
              width: 140,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            book.title.ar,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: bookFont, fontSize: 22),
          ),
          Text(
            l10n.authorLine(context, book.author.ar, book.authorDeathHijri),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          if (chapter != null)
            Text(
              chapter.title,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          const SizedBox(height: 16),
          _ParagraphText(paragraph: paragraph),
          const SizedBox(height: 16),
          if (s.status == ListeningStatus.error)
            _ErrorRow(onRetry: player.play)
          else
            _Controls(state: s, player: player),
          const SizedBox(height: 24),
          Semantics(
            header: true,
            child: Text(l10n.audioSpeed, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in listeningSpeeds)
                Semantics(
                  label: l10n.audioSpeedSemantics(formatSpeed(v, lang)),
                  excludeSemantics: true,
                  selected: v == speed,
                  button: true,
                  child: ChoiceChip(
                    label: Text(l10n.audioSpeedValue(formatSpeed(v, lang))),
                    selected: v == speed,
                    onSelected: (_) =>
                        ref.read(audioSettingsProvider.notifier).setSpeed(v),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsetsDirectional.zero,
            minTileHeight: 48,
            leading: const Icon(Icons.record_voice_over),
            title: Text(
              l10n.audioVoiceRow(
                voice == null || voices.isEmpty
                    ? l10n.audioVoice
                    : voiceLabel(l10n, voices, voice, lang),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showVoicePicker(context),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.menu_book),
              label: Text(l10n.audioGoToText),
              onPressed: () {
                Navigator.of(context).pop();
                onGoToText(s);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// نص الفقرة الحالية بخط أميري 20، بتمرير داخلي حتى 6 أسطر.
class _ParagraphText extends StatelessWidget {
  const _ParagraphText({required this.paragraph});
  final ReaderParagraph paragraph;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    const lineHeight = 2.0;
    final fontSize = scaler.scale(20).clamp(0, 64).toDouble();
    final text = paragraph.isVerse
        ? paragraph.text.replaceAll('\t', '    ')
        : paragraph.text;
    return Container(
      constraints: BoxConstraints(maxHeight: fontSize * lineHeight * 6),
      decoration: BoxDecoration(
        color: context.extraColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(12),
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          textAlign: paragraph.isVerse ? TextAlign.center : TextAlign.start,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: bookFont,
            fontSize: fontSize,
            height: lineHeight,
          ),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.player});
  final ListeningState state;
  final ListeningPlayer player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preparing = state.status == ListeningStatus.preparing;
    final book = state.book!;
    // أيقونات الوسائط لا تُعكس في RTL (DESIGN §6.3).
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: l10n.audioPrevious,
                iconSize: 32,
                icon: const Icon(Icons.skip_previous),
                onPressed: state.paragraph > 0 ? player.previous : null,
              ),
              const SizedBox(width: 24),
              SizedBox.square(
                dimension: 72,
                child: preparing
                    ? Semantics(
                        label: l10n.audioPreparing,
                        liveRegion: true,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : IconButton.filled(
                        tooltip: state.playing ? l10n.audioPause : l10n.audioPlay,
                        iconSize: 40,
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        icon: Icon(
                          state.playing ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: player.togglePlay,
                      ),
              ),
              const SizedBox(width: 24),
              IconButton(
                tooltip: l10n.audioNext,
                iconSize: 32,
                icon: const Icon(Icons.skip_next),
                onPressed: state.paragraph + 1 < book.paragraphs.length
                    ? player.next
                    : null,
              ),
            ],
          ),
          if (preparing)
            Directionality(
              textDirection: Directionality.of(context),
              child: ExcludeSemantics(child: Text(l10n.audioPreparing)),
            ),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.audioEngineError,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}
