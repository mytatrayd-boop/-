import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../core/theme.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/models/youtube_content.dart';
import '../../domain/ports/playback_queue.dart';
import '../../l10n/gen/app_localizations.dart';
import '../player/failure_message.dart';
import '../queue/queue_ui.dart';

/// يجلب صفحة من قائمة مقاطع ([pageToken] null للأولى).
typedef ListPageFetcher = Future<ApiPage<VideoRef>> Function(String? pageToken);

/// صفحة واحدة لقائمة محلية جاهزة (المفضلة والسجل).
ListPageFetcher localList(List<VideoRef> items) => (_) async => ApiPage(items);

/// ناتج جلب كل الصفحات: ما جُلب بترتيبه، والصفحة التي فشلت (للإكمال منها).
class WholeListFetch {
  const WholeListFetch({required this.items, this.failure, this.resumeToken, this.total});

  final List<VideoRef> items;

  /// فشل في المنتصف (أو في الأولى) أوقف الجلب.
  final AppFailure? failure;

  /// رمز الصفحة التي فشلت (null = الأولى).
  final String? resumeToken;

  /// العدد المعلن للقائمة إن عُرف.
  final int? total;
}

/// يجلب الصفحات بالتتابع حتى نهايتها أو حتى [limit] عنصراً (حد الطابور)، أو حتى
/// أول فشل. رد فارغ ينهي الجلب (كما في PagedLoader)، لا صفحة صُفّيت كلها. [maxPages] حماية.
Future<WholeListFetch> fetchAllPages(
  ListPageFetcher fetch, {
  String? startToken,
  required int limit,
  void Function(int fetched, int? total)? onProgress,
  int maxPages = 40,
}) async {
  final items = <VideoRef>[];
  String? token = startToken;
  int? total;
  for (var page = 0; page < maxPages; page++) {
    final ApiPage<VideoRef> p;
    try {
      p = await fetch(token);
    } on AppFailure catch (f) {
      return WholeListFetch(items: items, failure: f, resumeToken: token, total: total);
    } catch (e) {
      return WholeListFetch(
          items: items, failure: AppFailure(FailureKind.apiFailed, e.runtimeType.toString()), resumeToken: token, total: total);
    }
    total ??= p.total;
    items.addAll(p.items);
    onProgress?.call(items.length, total);
    if (items.length >= limit) return WholeListFetch(items: items.sublist(0, limit), total: total);
    final next = p.nextPageToken;
    // رد فارغ ينهي الجلب؛ صفحة صُفّيت كلها (خاص/محذوف) لا تنهيه (السقف maxPages).
    if (p.emptyResponse || next == null) break;
    token = next;
  }
  return WholeListFetch(items: items, total: total);
}

/// تشغيل واحد في كل مرة (نقرتان متتاليتان لا تضيفان القائمة مرتين).
bool _busy = false;

/// مدة رسالة «أُضيف n من m» و«إعادة المحاولة»: أطول من رسائل التأكيد (4 ث) حتى
/// لا يضيع الإكمال (مراجعة D30).
const retrySnackDuration = Duration(seconds: 15);

/// الجلسة تغيّرت (خروج أو انتهاء أو حساب آخر): لا يُضاف شيء جُلب من الحساب السابق.
bool _isSessionFailure(AppFailure f) => f.kind == FailureKind.notSignedIn || f.kind == FailureKind.authExpired;

/// عملية إضافة واحدة وإعاداتها: أي حدث على [cancelOn] (تغيّر حالة الحساب) يبطلها،
/// فلا تُضاف نتائج جزئية ولا تعمل «إعادة المحاولة» بعده.
class _Session {
  _Session(Stream<Object?>? cancelOn) {
    _sub = cancelOn?.listen((_) => cancelled = true);
  }
  bool cancelled = false;
  StreamSubscription<Object?>? _sub;
  Timer? _expiry;

  /// لا إعادة معلّقة: يتوقف الاستماع.
  void end() {
    _expiry?.cancel();
    _sub?.cancel();
  }

  /// إعادة معلّقة في رسالة: يبقى الاستماع حتى تختفي الرسالة.
  void keepFor(Duration d) {
    _expiry?.cancel();
    _expiry = Timer(d + const Duration(seconds: 1), end);
  }
}

/// «تشغيل الكل» و«أضف القائمة كلها» لقائمة قد تكون طويلة (DESIGN §2، D30): تُجلب
/// كل الصفحات (حتى حد الطابور) مع رسالة تقدّم، ثم تُضاف بترتيبها مرة واحدة عبر
/// المنفذ. فشل في المنتصف: يُضاف ما جُلب ورسالة «أُضيف n من m» مع «إعادة المحاولة»
/// التي تكمل من الصفحة الفاشلة وتدرج الباقي بعد آخر ما أُضيف. [cancelOn] لقوائم
/// الحساب: تغيّر حالة الحساب أثناءها يلغيها دون إضافة.
Future<void> enqueueWholeList(
  BuildContext context,
  PlaybackQueue queue,
  ListPageFetcher fetch,
  QueuePlacement placement, {
  int? total,
  Stream<Object?>? cancelOn,
}) async {
  if (_busy) return;
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final session = _Session(cancelOn);
  _busy = true;
  try {
    await _run(messenger, l, queue, fetch, placement, session, total: total);
  } finally {
    _busy = false;
  }
}

Future<void> _run(
  ScaffoldMessengerState messenger,
  AppLocalizations l,
  PlaybackQueue queue,
  ListPageFetcher fetch,
  QueuePlacement placement,
  _Session session, {
  String? startToken,
  int? afterKey,
  List<int> addedBefore = const [],
  int? total,
}) async {
  if (session.cancelled) {
    session.end();
    showUndoSnack(messenger, l, l.errorNotSignedIn);
    return;
  }
  final room = PlaybackQueue.maxLength - queue.queueState.value.entries.length;
  if (room <= 0) {
    session.end();
    showUndoSnack(messenger, l, l.queueTruncated(PlaybackQueue.maxLength));
    return;
  }
  final fetched = ValueNotifier<int>(addedBefore.length);
  final knownTotal = ValueNotifier<int?>(total);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const Key('wholeListProgress'),
      duration: const Duration(minutes: 5),
      persist: false,
      content: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge([fetched, knownTotal]),
              builder: (_, _) {
                final t = knownTotal.value;
                return Text(t == null || fetched.value == 0
                    ? l.playlistAdding
                    : l.playlistAddingProgress(fetched.value, t));
              },
            ),
          ),
        ],
      ),
    ));
  // +1: لمعرفة أن القائمة أطول مما يتسع له الطابور (رسالة «ممتلئ»).
  final r = await fetchAllPages(
    fetch,
    startToken: startToken,
    limit: room + 1,
    onProgress: (n, t) {
      fetched.value = addedBefore.length + n;
      knownTotal.value ??= t;
    },
  );
  final m = knownTotal.value ?? r.total;
  messenger.hideCurrentSnackBar();

  // خرج المستخدم أو انتهت الجلسة أثناء الجلب: لا إضافة ولا «إعادة المحاولة».
  final f = r.failure;
  if (session.cancelled || (f != null && _isSessionFailure(f))) {
    session.end();
    showUndoSnack(messenger, l, f != null && f.kind == FailureKind.authExpired ? l.sessionExpired : l.errorNotSignedIn);
    return;
  }

  void retryFrom({required int? after, required List<int> added}) => _guarded(() => _run(
        messenger,
        l,
        queue,
        fetch,
        placement,
        session,
        startToken: r.resumeToken,
        afterKey: after,
        addedBefore: added,
        total: m,
      ));

  if (r.items.isEmpty) {
    if (f != null) {
      session.keepFor(retrySnackDuration);
      showUndoSnack(messenger, l, failureMessage(l, f),
          onUndo: () => retryFrom(after: afterKey, added: addedBefore),
          actionLabel: l.retry,
          duration: retrySnackDuration);
    } else {
      session.end();
      if (addedBefore.isEmpty) {
        showUndoSnack(messenger, l, l.libraryEmpty);
      } else {
        _done(messenger, l, queue, addedBefore, truncated: false, silent: false);
      }
    }
    return;
  }

  final wasEmpty = queue.queueState.value.isEmpty;
  final res = afterKey == null ? await queue.enqueue(r.items, placement) : await queue.enqueueAfter(afterKey, r.items);
  final keys = [...addedBefore, ...res.keys];
  if (f != null && !res.truncated) {
    session.keepFor(retrySnackDuration);
    final text = m == null ? l.playlistAddedPartialUnknown(keys.length) : l.playlistAddedPartial(keys.length, m);
    showUndoSnack(messenger, l, text,
        onUndo: () => retryFrom(after: keys.isEmpty ? null : keys.last, added: keys),
        actionLabel: l.retry,
        duration: retrySnackDuration);
    return;
  }
  session.end();
  // «تشغيل الكل» أو طابور كان فارغاً: يظهر المشغّل بدل الرسالة (كما في enqueueWithFeedback).
  final silent = afterKey == null && (wasEmpty || placement == QueuePlacement.playNow);
  _done(messenger, l, queue, keys, truncated: res.truncated, silent: silent);
}

void _done(ScaffoldMessengerState messenger, AppLocalizations l, PlaybackQueue queue, List<int> keys,
    {required bool truncated, required bool silent}) {
  final truncatedLine = truncated ? l.queueTruncated(PlaybackQueue.maxLength) : null;
  if (silent || keys.isEmpty) {
    if (truncatedLine != null) showUndoSnack(messenger, l, truncatedLine);
    return;
  }
  final msg = l.snackAddedCount(keys.length);
  showUndoSnack(messenger, l, truncatedLine == null ? msg : '$msg\n$truncatedLine',
      onUndo: () => queue.removeEntries(keys));
}

void _guarded(Future<void> Function() body) {
  if (_busy) return;
  _busy = true;
  body().whenComplete(() => _busy = false);
}

/// «تشغيل الكل» عائم في أسفل الجهة الأولى، وبجواره زر أيقونة 48 «أضف القائمة
/// كلها» يفتح ورقة «شغّل التالي / أضف للنهاية» (DESIGN §2).
class PlayAllBar extends StatelessWidget {
  const PlayAllBar({super.key, required this.queue, required this.fetch, this.total, this.cancelOn});

  final PlaybackQueue queue;
  final ListPageFetcher fetch;
  final int? total;

  /// لقوائم الحساب: تغيّر حالة الحساب يلغي الإضافة (D30).
  final Stream<Object?>? cancelOn;

  Future<void> _addAll(BuildContext context) async {
    final placement =
        await showPlacementSheet(context, includePlayNow: false, title: AppLocalizations.of(context).addWholeList);
    if (placement == null || !context.mounted) return;
    await enqueueWholeList(context, queue, fetch, placement, total: total, cancelOn: cancelOn);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: Row(
          children: [
            FilledButton.icon(
              key: const Key('playAll'),
              onPressed: () =>
                  enqueueWholeList(context, queue, fetch, QueuePlacement.playNow, total: total, cancelOn: cancelOn),
              icon: const Icon(Icons.play_arrow),
              label: Text(l.playAll),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: const Key('addWholeList'),
              tooltip: l.addWholeList,
              color: AppColors.primary,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              onPressed: () => _addAll(context),
              icon: const Icon(Icons.playlist_add),
            ),
          ],
        ),
      ),
    );
  }
}
