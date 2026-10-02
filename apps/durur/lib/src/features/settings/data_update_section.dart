import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/local_date.dart';
import '../../formatting/digits.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../../updates/data_updater.dart';

/// نتيجة «تحقق الآن» المعروضة تحت الزر (DESIGN 8.7، جدول الحالات).
enum _CheckResult { upToDate, networkError, verifyError }

/// قسم «تحديث البيانات» في الإعدادات (DESIGN 8.7، D21، ARCHITECTURE §16):
/// المفتاح، وسطر الحالة، وزر «تحقق الآن»، وسطر النتيجة. يُخفى كاملاً إن لم
/// يكن التحديث متاحاً في هذه النسخة (لا رابط أو لا مفتاح موثوق).
/// سطر النتيجة حالة محلية: يُمسح عند مغادرة الإعدادات.
class DataUpdateSection extends ConsumerStatefulWidget {
  const DataUpdateSection({super.key, required this.header});

  /// عنوان القسم بنمط عناوين الإعدادات.
  final Widget Function(String text) header;

  static const autoSwitchKey = Key('settingsUpdateAuto');
  static const statusKey = Key('settingsUpdateStatus');
  static const checkNowKey = Key('settingsUpdateCheckNow');
  static const resultKey = Key('settingsUpdateResult');

  @override
  ConsumerState<DataUpdateSection> createState() => _DataUpdateSectionState();
}

class _DataUpdateSectionState extends ConsumerState<DataUpdateSection> {
  bool _checking = false;
  _CheckResult? _result;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(dataUpdateAvailableProvider)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final digits = ref.watch(digitStyleProvider);
    final autoUpdate = ref.watch(settingsProvider.select((s) => s.autoUpdate));
    final version = ref.watch(tablesProvider).value?.meta.dataVersion;
    final lastOk = ref.watch(lastDataCheckOkProvider);
    final today = ref.watch(todayProvider);

    String? status;
    if (version != null) {
      final v = localizeDigits(version, digits);
      status = lastOk == null
          ? l10n.settingsUpdateStatusNever(v)
          : l10n.settingsUpdateStatus(
              v,
              _dateLabel(l10n, lastOk, today, digits),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        widget.header(l10n.settingsSectionUpdate),
        SwitchListTile(
          key: DataUpdateSection.autoSwitchKey,
          minTileHeight: 64,
          title: Text(l10n.settingsUpdateAuto),
          subtitle: Text(l10n.settingsUpdateAutoDesc),
          value: autoUpdate,
          onChanged: _setAuto,
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 0),
            child: Text(
              status,
              key: DataUpdateSection.statusKey,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.inkSoft),
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
          child: Semantics(
            liveRegion: _checking,
            child: OutlinedButton.icon(
              key: DataUpdateSection.checkNowKey,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _checking ? null : _checkNow,
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 20),
              label: Text(
                _checking
                    ? l10n.settingsUpdateChecking
                    : l10n.settingsUpdateCheckNow,
              ),
            ),
          ),
        ),
        if (_result case final result?)
          Padding(
            key: DataUpdateSection.resultKey,
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    result == _CheckResult.upToDate
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    size: 20,
                    color: result == _CheckResult.upToDate
                        ? colors.sea
                        : colors.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      switch (result) {
                        _CheckResult.upToDate => l10n.settingsUpdateUpToDate,
                        _CheckResult.networkError =>
                          l10n.settingsUpdateNetworkError,
                        _CheckResult.verifyError =>
                          l10n.settingsUpdateVerifyError,
                      },
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// «اليوم» أو «أمس» أو التاريخ الميلادي بلا لاحقة (بتوقيت الجهاز ومنتصف
  /// ليله). نفس الصيغة تُقرأ لقارئ الشاشة (`gregorianDateSpoken`).
  static String _dateLabel(
    AppLocalizations l10n,
    DateTime at,
    DateTime today,
    DigitStyle digits,
  ) {
    final day = dateOnly(at);
    if (day == today) return l10n.settingsUpdateDateToday;
    if (day == addDays(today, -1)) return l10n.settingsUpdateDateYesterday;
    return l10n.gregorianDateSpoken(
      formatInteger(day.day, digits),
      'g${day.month}',
      formatInteger(day.year, digits),
    );
  }

  /// لا رسالة عند التغيير؛ اهتزاز خفيف فقط (DESIGN 8.7، القسم 10). فشل الحفظ
  /// ← الرسالة العامة والقيمة لا تتغير.
  Future<void> _setAuto(bool on) async {
    HapticFeedback.lightImpact();
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(settingsProvider.notifier).setAutoUpdate(on);
    } on Object {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.citySaveError),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  /// «تحقق الآن»: «حُدّثت البيانات» تظهرها جذر التطبيق رسالةً أسفل الشاشة
  /// (فلا سطر هنا، حتى لا يُعلن الخبر مرتين).
  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    final outcome = await ref.read(dataUpdateProvider.notifier).checkNow();
    if (!mounted) return;
    final failure = ref.read(dataUpdateProvider).failure;
    setState(() {
      _checking = false;
      _result = switch (outcome) {
        UpdateOutcome.upToDate => _CheckResult.upToDate,
        UpdateOutcome.failed =>
          failure == UpdateFailure.network
              ? _CheckResult.networkError
              : _CheckResult.verifyError,
        UpdateOutcome.updated ||
        UpdateOutcome.disabled ||
        UpdateOutcome.notDue => null,
      };
    });
  }
}
