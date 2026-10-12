import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/formatters.dart';
import '../l10n/app_localizations.dart';
import '../reader/reader_book.dart';
import '../reader/reader_providers.dart';
import 'listening_player.dart';
import 'listening_providers.dart';
import 'player_sheets.dart';
import 'tts_engine.dart';

/// «استمع» (من آخر موضع) و«استمع من هنا» (من [paragraphId]). [book] إن كان
/// نص الكتاب محمّلاً سلفاً (القارئ)، وإلا يُقرأ من القاعدة.
Future<void> startListening(
  BuildContext context,
  WidgetRef ref, {
  required String bookId,
  ReaderBook? book,
  String? paragraphId,
}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final screenReader = MediaQuery.accessibleNavigationOf(context);
  final repo = ref.read(readingRepositoryProvider);
  final StartResult result;
  try {
    final loaded = book ?? await repo.loadBook(bookId);
    if (loaded == null || loaded.paragraphs.isEmpty) return;
    var index = 0;
    final id = paragraphId ?? (await repo.position(bookId))?.paragraphId;
    if (id != null) {
      index =
          loaded.paragraphIndexOf(id) ??
          loaded.paragraphIndexOf(await repo.resolveParagraph(id)) ??
          0;
    }
    final settings = await ref.read(audioSettingsProvider.future);
    result = await ref
        .read(listeningPlayerProvider)
        .start(
          loaded,
          index,
          voiceName: settings.voiceName,
          speed: settings.speed,
        );
  } on Exception {
    _snack(messenger, l10n.audioEngineError, screenReader);
    return;
  }
  if (!context.mounted) return;
  switch (result) {
    case StartResult.started:
      if (screenReader &&
          await ref
              .read(audioSettingsProvider.notifier)
              .takeScreenReaderWarning()) {
        _snack(messenger, l10n.audioScreenReaderWarning, true);
      }
    case StartResult.noArabicVoice:
      await showNoArabicVoiceSheet(context, ref);
    case StartResult.failed:
      _snack(messenger, l10n.audioEngineError, screenReader);
    case StartResult.cancelled:
      // أُلغي عمداً (✕ أو بدء آخر): لا رسالة.
      break;
  }
}

void _snack(ScaffoldMessengerState messenger, String text, bool longer) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text),
        // ٤ ثوانٍ على الأقل، وتُضاعف مع قارئ الشاشة (DESIGN §16.7).
        duration: Duration(seconds: longer ? 8 : 4),
      ),
    );
}

/// «١٫٢٥» أو «1.25» حسب اللغة، بلا أصفار زائدة.
String formatSpeed(double speed, String languageCode) {
  var s = speed.toString();
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  return localizeDigits(s, languageCode);
}

/// «عربي (مصر) — صوت ١» (DESIGN §10.2): الأصوات مرقّمة داخل كل بلد.
String voiceLabel(
  AppLocalizations l10n,
  List<TtsVoice> voices,
  TtsVoice voice,
  String languageCode,
) {
  final region = voice.region;
  final same = voices.where((v) => v.region == region).toList();
  final number = formatInt(
    same.contains(voice) ? same.indexOf(voice) + 1 : 1,
    languageCode,
  );
  final regionName = region == null ? '' : l10n.audioRegion(region);
  return regionName.isEmpty
      ? l10n.audioVoiceNoRegion(number)
      : l10n.audioVoiceWithRegion(regionName, number);
}
