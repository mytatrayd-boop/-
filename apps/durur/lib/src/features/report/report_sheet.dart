import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/tables.dart';
import '../../formatting/date_labels.dart';
import '../../formatting/digits.dart';
import '../../providers.dart';
import '../../report/report_service.dart';
import '../../theme/app_theme.dart';

/// محتوى البلاغ (SPEC الميزة 9 معيار 2 و4): العنصر (إن وُجد)، ومنطقة الجدول،
/// والتاريخ المعروض، ونسخة التطبيق، ونسخة البيانات. **لا شيء غيرها**: لا
/// مدينة ولا إحداثيات ولا معرّف جهاز.
ReportMessage buildReportMessage(
  AppLocalizations l10n, {
  String? itemName,
  String? regionName,
  required DateTime date,
  required String appVersion,
  required TablesMeta? meta,
  DigitStyle digits = DigitStyle.arabicIndic,
}) {
  final day = DateTime(date.year, date.month, date.day);
  final dataVersion = meta == null
      ? null
      : (version: meta.dataVersion, seq: meta.dataSeq);
  return ReportMessage(
    lines: [
      if (itemName != null) l10n.reportItem(itemName),
      if (regionName != null) l10n.reportRegion(regionName),
      l10n.reportDate(gregorianDateLabel(l10n, day, digits: digits)),
      l10n.reportVersion(localizeDigits(appVersion, digits)),
      if (dataVersion != null)
        l10n.reportDataVersion(
          dataVersion.version,
          formatInteger(dataVersion.seq, digits),
        ),
    ],
    values: {
      ReportField.item: ?itemName,
      ReportField.region: ?regionName,
      ReportField.date: _isoDate(day),
      ReportField.appVersion: appVersion,
      if (dataVersion != null)
        ReportField.dataVersion: '${dataVersion.version} (${dataVersion.seq})',
    },
  );
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// يفتح ورقة البلاغ (DESIGN 8.8). [itemName] null ← بلاغ عام (الإعدادات،
/// خطأ الحساب في الرئيسية).
Future<void> showReportSheet(
  BuildContext context, {
  String? itemName,
  String? regionName,
  required DateTime date,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        ReportSheet(itemName: itemName, regionName: regionName, date: date),
  );
}

enum _Phase {
  /// قبل الضغط.
  ready,

  /// فُتح النموذج بلا تعبئة ونُسخ النص: «الصقها في النموذج».
  pasted,

  /// تعذّر فتح النموذج: نافذة النسخ.
  failed,
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    this.itemName,
    this.regionName,
    required this.date,
  });

  static const sheetKey = Key('reportSheet');
  static const summaryKey = Key('reportSummary');
  static const openFormKey = Key('reportOpenForm');
  static const copyKey = Key('reportCopy');
  static const copiedKey = Key('reportCopied');
  static const messageKey = Key('reportMessage');
  static const closeKey = Key('reportClose');

  final String? itemName;
  final String? regionName;
  final DateTime date;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  _Phase _phase = _Phase.ready;
  bool _copied = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final config = ref.watch(reportConfigProvider);
    final version = ref.watch(appVersionProvider);
    final ready = !version.isLoading;
    final message = buildReportMessage(
      l10n,
      itemName: widget.itemName,
      regionName: widget.regionName,
      date: widget.date,
      // تعذّر قراءة النسخة: شرطة بدل الرقم، والبلاغ يبقى ممكناً.
      appVersion: version.value ?? '-',
      meta: ref.watch(tablesProvider).value?.meta,
      digits: ref.watch(digitStyleProvider),
    );

    final String intro;
    var live = false;
    switch (_phase) {
      case _Phase.ready:
        intro = !config.hasForm
            ? l10n.reportIntroCopy
            : config.prefills
            ? l10n.reportIntroForm
            : l10n.reportIntroFormPaste;
      case _Phase.pasted:
        intro = l10n.reportPasteHint;
        live = true;
      case _Phase.failed:
        intro = l10n.reportFormOpenError;
        live = true;
    }
    // «نسخ» وحده إن لم يُضبط نموذج (ARCHITECTURE §10)؛ وبعد فتح النموذج أو
    // فشله يبقى النسخ متاحاً.
    final showForm = config.hasForm && _phase == _Phase.ready;
    final showCopy = !config.hasForm || _phase != _Phase.ready;
    const buttonSize = Size.fromHeight(52);

    return SingleChildScrollView(
      key: ReportSheet.sheetKey,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.reportTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              TextButton(
                key: ReportSheet.closeKey,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: live,
            child: Text(
              intro,
              key: ReportSheet.messageKey,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            key: ReportSheet.summaryKey,
            margin: EdgeInsetsDirectional.zero,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in message.lines)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 4),
                      child: Text(line, style: theme.textTheme.bodyMedium),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (showForm)
            FilledButton(
              key: ReportSheet.openFormKey,
              style: FilledButton.styleFrom(minimumSize: buttonSize),
              onPressed: ready && !_busy ? () => _send(message) : null,
              child: Text(l10n.reportOpenForm),
            ),
          if (showCopy) ...[
            if (!config.hasForm)
              FilledButton(
                key: ReportSheet.copyKey,
                style: FilledButton.styleFrom(minimumSize: buttonSize),
                onPressed: ready ? () => _copy(message) : null,
                child: Text(l10n.reportCopyDetails),
              )
            else
              OutlinedButton(
                key: ReportSheet.copyKey,
                style: OutlinedButton.styleFrom(minimumSize: buttonSize),
                onPressed: ready ? () => _copy(message) : null,
                child: Text(l10n.reportCopyDetails),
              ),
          ],
          if (_copied) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.reportDetailsCopied,
                key: ReportSheet.copiedKey,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.reportNothingSent,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
          ),
        ],
      ),
    );
  }

  /// نموذج ← نسخ (ARCHITECTURE §10).
  Future<void> _send(ReportMessage message) async {
    setState(() => _busy = true);
    final outcome = await ref.read(reportServiceProvider).report(message);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      // DESIGN 8.8: يفتح التطبيق الخارجي ويغلق الورقة.
      case ReportOutcome.formPrefilled:
        Navigator.of(context).pop();
      // تبقى الورقة لتذكّر المستخدم أن يلصق النص عند رجوعه.
      case ReportOutcome.formWithCopiedText:
        setState(() => _phase = _Phase.pasted);
      case ReportOutcome.copy:
        setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _copy(ReportMessage message) async {
    try {
      await ref.read(clipboardWriterProvider)(message.text);
    } on Object {
      return; // لا تأكيد إن لم يُنسخ.
    }
    if (mounted) setState(() => _copied = true);
  }
}
