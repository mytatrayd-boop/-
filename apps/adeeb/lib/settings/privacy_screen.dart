import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// سياسة الخصوصية داخل التطبيق (DESIGN §15): نص محلي يعمل دون إنترنت.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sections = [
      (l10n.privacyAccountTitle, l10n.privacyAccountBody),
      (l10n.privacyLocalTitle, l10n.privacyLocalBody),
      (l10n.privacyAskTitle, l10n.privacyAskBody),
      (l10n.privacyPersonalTitle, l10n.privacyPersonalBody),
      (l10n.privacyDeviceTitle, l10n.privacyDeviceBody),
      (l10n.privacyAgeTitle, l10n.privacyAgeBody),
      (l10n.privacyNetworkTitle, l10n.privacyNetworkBody),
      (l10n.privacyAdsTitle, l10n.privacyAdsBody),
      (l10n.privacyControlTitle, l10n.privacyControlBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
          children: [
            Text(l10n.privacyIntro, style: theme.textTheme.bodyLarge),
            for (final (title, body) in sections) ...[
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(height: 6),
              Text(body, style: theme.textTheme.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }
}
