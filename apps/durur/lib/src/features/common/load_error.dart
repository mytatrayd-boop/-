import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// تعذّر قراءة البيانات المضمّنة، مع «إعادة المحاولة» (DESIGN 8.1). تستخدمها
/// الرئيسية وصفحة العنصر/الدَّرّ.
class DataLoadError extends StatelessWidget {
  const DataLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.dataLoadErrorTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.dataLoadErrorBody, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
        ],
      ),
    );
  }
}
