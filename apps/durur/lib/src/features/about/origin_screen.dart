import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../formatting/digits.dart';
import '../../providers.dart';

/// صفحة «أصل التقويم» (`/about/origin`، D24 وقرار المالك في عرض السعودية):
/// سطران لكل طبقة، أصل الطوالع والمواسم وأصل الدرور. النصوص في ARB لأنها
/// عامة لا تخص منطقة، إلا عبارة «معروض هنا للمقارنة» فتُلحق فقط إن كانت
/// منطقة المستخدم الحالية تستعير الدرور (DESIGN 8.10).
class OriginScreen extends ConsumerWidget {
  const OriginScreen({super.key});

  static const screenKey = Key('originScreen');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borrows = ref.watch(
      engineProvider.select((e) => e?.dururBorrow != null),
    );
    final digits = ref.watch(digitStyleProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget section(String title, String body) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(l10n.originTitle)),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
        children: [
          section(l10n.originTawaliTitle, l10n.originTawaliBody),
          section(
            l10n.originDururTitle,
            localizeDigits(
              borrows
                  ? '${l10n.originDururBody} ${l10n.originDururComparison}'
                  : l10n.originDururBody,
              digits,
            ),
          ),
        ],
      ),
    );
  }
}
