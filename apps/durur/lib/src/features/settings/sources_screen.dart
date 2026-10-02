import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/source_catalog.dart';
import '../../domain/tables.dart';
import '../../formatting/digits.dart';
import '../../providers.dart';
import '../../theme/app_theme.dart';
import '../item_detail/item_detail_view.dart' show PendingApprovalText;

/// صفحة المصادر (DESIGN 8.7، 8.11، D27): بطاقة نسخة البيانات (آخر تحديث أو
/// «المرفقة مع نسخة التطبيق»، ثم النسخة ورقمها)، ثم مصادر كل الجداول بلا تكرار مع مرجع
/// اعتمادها، وقسم ثابت «رخص البيانات» فيه إشارة GeoNames (CC BY 4.0)
/// ورابطاها، ومصدر تقويم أم القرى.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  static const screenKey = Key('sourcesScreen');
  static const geoNamesLinkKey = Key('sourcesGeoNamesLink');
  static const licenseLinkKey = Key('sourcesLicenseLink');
  static const dataCardKey = Key('sourcesDataCard');

  /// عناوين ثابتة عامة (ليست أسراراً، D27).
  static final geoNamesUrl = Uri.parse('https://www.geonames.org/');
  static final ccByUrl = Uri.parse(
    'https://creativecommons.org/licenses/by/4.0/',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final tables = ref.watch(tablesProvider).value;
    final entries = tables == null
        ? const <SourceEntry>[]
        : collectSources(tables);

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 24, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );

    Future<void> open(Uri uri) async {
      final messenger = ScaffoldMessenger.of(context);
      var ok = false;
      try {
        ok = await ref.read(urlOpenerProvider)(uri);
      } on Object {
        ok = false;
      }
      if (!ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.linkOpenError),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }

    Widget link(Key key, String label, Uri uri) => Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: key,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => open(uri),
        icon: const Icon(Icons.open_in_new, size: 20),
        label: Text(label),
      ),
    );

    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(l10n.settingsSources)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
        children: [
          if (tables != null) ...[
            const SizedBox(height: 16),
            _DataVersionCard(meta: tables.meta),
          ],
          heading(l10n.sourcesTablesTitle),
          for (final e in entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(e.source.title, style: theme.textTheme.bodyMedium),
                  if (_byline(e, l10n, ref.watch(digitStyleProvider))
                      case final byline?)
                    Text(byline, style: theme.textTheme.bodySmall),
                  if (!e.approved)
                    const PendingApprovalText()
                  else if (e.reviewers.isNotEmpty)
                    Text(
                      l10n.sourcesApprovedBy(
                        e.reviewers.join(l10n.listSeparator),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
          heading(l10n.sourcesLicensesTitle),
          Text(l10n.sourcesGeoNames, style: theme.textTheme.bodyMedium),
          link(geoNamesLinkKey, l10n.sourcesGeoNamesLink, geoNamesUrl),
          link(licenseLinkKey, l10n.sourcesLicenseLink, ccByUrl),
          heading(l10n.sourcesHijriTitle),
          Text(l10n.sourcesHijri, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  /// «المؤلف، السنة» إن وُجدا.
  static String? _byline(
    SourceEntry e,
    AppLocalizations l10n,
    DigitStyle digits,
  ) {
    final parts = [
      if ((e.source.author ?? '').trim().isNotEmpty) e.source.author!.trim(),
      if (e.source.year case final year? when year > 0) formatInteger(year, digits),
    ];
    return parts.isEmpty ? null : parts.join(l10n.listSeparator);
  }
}

/// بطاقة نسخة البيانات (DESIGN 8.11): عنصر واحد لقارئ الشاشة يُقرأ سطراه معاً.
class _DataVersionCard extends ConsumerWidget {
  const _DataVersionCard({required this.meta});

  final TablesMeta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    final digits = ref.watch(digitStyleProvider);
    final origin = ref.watch(dataOriginProvider).value;
    final appVersion = ref.watch(appVersionProvider).value;
    final first = switch (origin) {
      DownloadedData(:final publishedAt) => l10n.sourcesDataUpdated(
        l10n.gregorianDateSpoken(
          formatInteger(publishedAt.day, digits),
          'g${publishedAt.month}',
          formatInteger(publishedAt.year, digits),
        ),
      ),
      BundledData() when appVersion != null => l10n.sourcesDataBundled(
        localizeDigits(appVersion, digits),
      ),
      _ => null,
    };
    final second = l10n.sourcesDataVersion(
      localizeDigits(meta.dataVersion, digits),
      formatInteger(meta.dataSeq, digits),
    );
    return Card(
      key: SourcesScreen.dataCardKey,
      margin: EdgeInsetsDirectional.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ExcludeSemantics(child: Icon(Icons.info_outline)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (first != null)
                      Text(first, style: theme.textTheme.bodyMedium),
                    Text(
                      second,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
