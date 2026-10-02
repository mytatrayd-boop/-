import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// صفحة «أصل التقويم» (`/about/origin`، D24 وقرار المالك في عرض السعودية):
/// سطران لكل طبقة، أصل الطوالع والمواسم وأصل الدرور. النصوص في ARB لأنها
/// عامة لا تخص منطقة.
class OriginScreen extends StatelessWidget {
  const OriginScreen({super.key});

  static const screenKey = Key('originScreen');

  @override
  Widget build(BuildContext context) {
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
          section(l10n.originDururTitle, l10n.originDururBody),
        ],
      ),
    );
  }
}
