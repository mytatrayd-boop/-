import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../core/providers.dart';
import '../../domain/ports/auth_service.dart';
import '../../domain/incoming_link.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/playback_queue.dart';
import '../../domain/youtube_link_parser.dart';
import '../../l10n/gen/app_localizations.dart';
import '../library/whole_list.dart';
import '../login/auth_status_provider.dart';
import '../player/failure_message.dart';
import '../queue/queue_ui.dart';

/// هل يبدو النص رابطاً (لا كلمة بحث)؟ الحقل نفسه يقبل الاثنين.
bool looksLikeLink(String text) {
  final t = text.trim().toLowerCase();
  return t.contains('://') || t.contains('youtu.be/') || t.contains('youtube.com/');
}

/// لصق أو مشاركة أو كتابة رابط (D28 كما كان في شاشة المشغّل): إن كان الطابور
/// فارغاً يبدأ التشغيل مباشرة، وإلا ورقة «شغّل الآن / شغّل التالي / أضف للنهاية».
/// رابط قائمة (`playlist?list=…`): للمسجّل تُضاف القائمة كلها عبر الواجهة الرسمية
/// (D27/D30)، ولغيره رسالة «سجّل الدخول لإضافة قوائم يوتيوب». الرابط غير الصالح:
/// رسالة قصيرة (DESIGN).
Future<void> submitLink(BuildContext context, WidgetRef ref, String raw, {bool shared = false}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final queue = ref.read(playbackQueueProvider);
  try {
    final link = shared ? parseSharedText(raw) : parseYoutubeLink(raw);
    final id = link.videoId;
    final playlistId = link.playlistId;
    if (id == null && playlistId != null) {
      final kind = classifyPlaylistId(playlistId);
      if (kind == PlaylistLinkKind.watchLater) throw const AppFailure(FailureKind.playlistWatchLater);
      if (kind == PlaylistLinkKind.mix) throw const AppFailure(FailureKind.playlistMix);
      if (ref.read(authStatusProvider) != AuthStatus.signedIn) {
        throw const AppFailure(FailureKind.playlistNeedsSignIn);
      }
      final placement = queue.queueState.value.isEmpty
          ? QueuePlacement.playNow
          : await showPlacementSheet(context, includePlayNow: true);
      if (placement == null || !context.mounted) return;
      final api = ref.read(youTubeApiProvider);
      // LL = إعجابات المستخدم نفسه: عبر مسار الإعجابات (D30).
      final ListPageFetcher fetch = kind == PlaylistLinkKind.likes
          ? (token) => api.likedVideos(pageToken: token)
          : (token) => api.playlistVideos(playlistId, pageToken: token);
      await enqueueWholeList(context, queue, fetch, placement,
          cancelOn: ref.read(authServiceProvider).statusChanges);
      return;
    }
    if (id == null) throw const AppFailure(FailureKind.invalidLink);
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
Future<void> pasteLink(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text?.trim() ?? '';
  if (!context.mounted) return;
  if (text.isEmpty) {
    showUndoSnack(messenger, l, l.clipboardEmpty);
    return;
  }
  await submitLink(context, ref, text);
}
