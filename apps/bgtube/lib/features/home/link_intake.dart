import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../domain/incoming_link.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/playback_queue.dart';
import '../../domain/youtube_link_parser.dart';
import '../../l10n/gen/app_localizations.dart';
import '../player/failure_message.dart';
import '../queue/queue_ui.dart';

/// هل يبدو النص رابطاً (لا كلمة بحث)؟ الحقل نفسه يقبل الاثنين.
bool looksLikeLink(String text) {
  final t = text.trim().toLowerCase();
  return t.contains('://') || t.contains('youtu.be/') || t.contains('youtube.com/');
}

/// لصق أو مشاركة أو كتابة رابط (D28 كما كان في شاشة المشغّل): إن كان الطابور
/// فارغاً يبدأ التشغيل مباشرة، وإلا ورقة «شغّل الآن / شغّل التالي / أضف للنهاية».
/// الرابط غير الصالح: رسالة قصيرة (DESIGN).
Future<void> submitLink(BuildContext context, PlaybackQueue queue, String raw, {bool shared = false}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final link = shared ? parseSharedText(raw) : parseYoutubeLink(raw);
    final id = link.videoId;
    if (id == null) throw const AppFailure(FailureKind.playlistNotSupported);
    final refs = [VideoRef(videoId: id)];
    if (queue.queueState.value.isEmpty) {
      await queue.enqueue(refs, QueuePlacement.playNow);
      return;
    }
    final placement = await showPlacementSheet(context, includePlayNow: true);
    if (placement == null || !context.mounted) return;
    await enqueueWithFeedback(context, queue, refs, placement);
  } on AppFailure catch (f) {
    showUndoSnack(messenger, l, failureMessage(l, f));
  }
}

/// «لصق رابط»: يقرأ الحافظة ويشغّل، وإلا «لا يوجد رابط يوتيوب في الحافظة».
Future<void> pasteLink(BuildContext context, PlaybackQueue queue) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text?.trim() ?? '';
  if (!context.mounted) return;
  if (text.isEmpty) {
    showUndoSnack(messenger, l, l.clipboardEmpty);
    return;
  }
  await submitLink(context, queue, text);
}
