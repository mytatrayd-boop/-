import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../domain/models/video_ref.dart';
import '../../domain/ports/playback_queue.dart';
import '../../l10n/gen/app_localizations.dart';
import '../player/format_duration.dart';
import '../player/text_direction.dart';

/// عنوان المقطع أو بديل مترجم حين لا يُعرف (رابط ملصق قبل استخراجه).
String videoTitle(AppLocalizations l, VideoRef r) => r.title ?? l.untitledVideo;

/// عنوان مختصر لرسائل التأكيد.
String shortTitle(AppLocalizations l, VideoRef r, {int max = 40}) {
  final t = videoTitle(l, r);
  return t.length <= max ? t : '${t.substring(0, max - 1)}…';
}

String formatCount(BuildContext context, int n) =>
    NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).format(n);

/// «{n} مقاطع · {المدة}» (المدة للمعروف فقط، وتُحذف إن كانت صفراً).
String itemsSummary(BuildContext context, int count, Duration total) {
  final l = AppLocalizations.of(context);
  if (total <= Duration.zero) return l.itemsCount(count);
  return l.itemsSummary(count, formatDuration(total, Localizations.localeOf(context).languageCode));
}

Duration totalDuration(Iterable<VideoRef> refs) =>
    refs.fold(Duration.zero, (sum, r) => sum + (r.duration ?? Duration.zero));

/// رسالة قصيرة ٤ ثوانٍ مع «تراجع» على الجهة الأخيرة؛ الجديدة تستبدل السابقة.
void showUndoSnack(ScaffoldMessengerState messenger, AppLocalizations l, String text, {VoidCallback? onUndo, String? actionLabel}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 4),
      persist: false,
      action: onUndo == null ? null : SnackBarAction(label: actionLabel ?? l.undo, onPressed: onUndo),
    ));
}

/// يضيف عبر المنفذ الوحيد ويُظهر رسالة التأكيد مع «تراجع» (DESIGN: Snackbar الطابور).
/// إن كان الطابور فارغاً أو الخيار «شغّل الآن» يبدأ التشغيل ولا رسالة (يظهر المشغّل).
Future<void> enqueueWithFeedback(
  BuildContext context,
  PlaybackQueue queue,
  List<VideoRef> refs,
  QueuePlacement placement,
) async {
  if (refs.isEmpty) return;
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final wasEmpty = queue.queueState.value.isEmpty;
  final r = await queue.enqueue(refs, placement);
  final truncatedLine = r.truncated ? l.queueTruncated(PlaybackQueue.maxLength) : null;
  if (wasEmpty || placement == QueuePlacement.playNow || r.count == 0) {
    if (truncatedLine != null) showUndoSnack(messenger, l, truncatedLine);
    return;
  }
  final String msg;
  if (refs.length > 1) {
    msg = l.snackAddedCount(r.count);
  } else if (placement == QueuePlacement.playNext) {
    msg = l.snackPlayNext(shortTitle(l, refs.first));
  } else {
    msg = l.snackAddedToEnd;
  }
  showUndoSnack(messenger, l, truncatedLine == null ? msg : '$msg\n$truncatedLine',
      onUndo: () => queue.removeEntries(r.keys));
}

/// إجراء في ورقة سفلية (صف 56dp بأيقونة على الجهة الأولى).
class SheetAction {
  const SheetAction({required this.key, required this.icon, required this.label, required this.onTap, this.color});
  final Key key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

/// ورقة إجراءات سفلية (بمتناول الإبهام). [title] اختياري أعلاها.
Future<void> showActionSheet(BuildContext context, List<SheetAction> actions, {String? title}) {
  return showModalBottomSheet<void>(
    context: context,
    // فوق الشريط السفلي والمصغّر: لا تُحشر داخل متصفّح الوجهة (D29).
    useRootNavigator: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: textDirectionFor(title),
                    style: Theme.of(sheet).textTheme.titleMedium),
              ),
            for (final a in actions)
              ListTile(
                key: a.key,
                minTileHeight: 56,
                leading: Icon(a.icon, color: a.color),
                title: Text(a.label, style: a.color == null ? null : TextStyle(color: a.color)),
                onTap: () {
                  Navigator.of(sheet).pop();
                  a.onTap();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

/// خيارات الإضافة: «شغّل الآن» (اختياري) و«شغّل التالي» و«أضف للنهاية».
Future<QueuePlacement?> showPlacementSheet(BuildContext context, {required bool includePlayNow, String? title}) async {
  final l = AppLocalizations.of(context);
  QueuePlacement? chosen;
  await showActionSheet(
    context,
    [
      if (includePlayNow)
        SheetAction(
          key: const Key('placement_playNow'),
          icon: Icons.play_arrow,
          label: l.actionPlayNow,
          color: AppColors.primary,
          onTap: () => chosen = QueuePlacement.playNow,
        ),
      SheetAction(
        key: const Key('placement_playNext'),
        icon: Icons.queue_play_next,
        label: l.actionPlayNext,
        onTap: () => chosen = QueuePlacement.playNext,
      ),
      SheetAction(
        key: const Key('placement_addToEnd'),
        icon: Icons.playlist_add,
        label: l.actionAddToEnd,
        onTap: () => chosen = QueuePlacement.addToEnd,
      ),
    ],
    title: title,
  );
  return chosen;
}

/// صف مقطع 64dp: صورة 16:9 بعرض 88 على الجهة الأولى، العنوان (سطر) وسطر ثانوي،
/// و[trailing] على الجهة الأخيرة (مقبض السحب).
class VideoRow extends StatelessWidget {
  const VideoRow({
    super.key,
    required this.video,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.dimmed = false,
    this.highlighted = false,
    this.leadingOverlay,
  });

  final VideoRef video;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dimmed;
  final bool highlighted;
  final Widget? leadingOverlay;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = videoTitle(l, video);
    final locale = Localizations.localeOf(context).languageCode;
    final secondary = [
      if (video.author != null) video.author!,
      if (video.duration != null) formatDuration(video.duration!, locale),
    ].join(' · ');
    return Material(
      color: highlighted ? AppColors.surfaceHigh : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: highlighted
              ? const BoxDecoration(
                  border: BorderDirectional(start: BorderSide(color: AppColors.primary, width: 2)),
                )
              : null,
          padding: const EdgeInsetsDirectional.only(start: 16, top: 6, bottom: 6),
          child: Row(
            children: [
              _Thumb(url: video.thumbUrl, overlay: leadingOverlay),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: textDirectionFor(title),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: dimmed ? AppColors.textSecondary : AppColors.textPrimary,
                        fontWeight: highlighted ? FontWeight.w600 : null,
                      ),
                    ),
                    subtitle ??
                        (secondary.isEmpty
                            ? const SizedBox.shrink()
                            : Text(secondary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: textDirectionFor(secondary),
                                style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
              ?trailing,
              if (trailing == null) const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, this.overlay});
  final String? url;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.surface,
      child: Center(child: Icon(Icons.music_note, color: AppColors.textSecondary, size: 20)),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 88,
        height: 49.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (u == null)
              placeholder
            else
              Image.network(u, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
            if (overlay != null) ColoredBox(color: const Color(0x99000000), child: Center(child: overlay)),
          ],
        ),
      ),
    );
  }
}

/// مقبض السحب ≡ بهدف 48×48 (السحب يبدأ منه فقط).
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: Tooltip(
        message: AppLocalizations.of(context).dragToReorder,
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.drag_handle, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// خلفية الحذف بالسحب الجانبي: لون الخطأ وأيقونة سلة ونص «حذف» من جهة السحب.
Widget dismissBackground(BuildContext context, {required bool fromStart}) {
  final l = AppLocalizations.of(context);
  return Container(
    color: AppColors.error,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 24),
    alignment: fromStart ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.delete_outline, color: AppColors.background),
        const SizedBox(width: 8),
        Text(l.delete, style: const TextStyle(color: AppColors.background, fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
