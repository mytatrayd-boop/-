import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

const logoAsset = 'assets/branding/logo_full.png';

/// «عن الأديب الذكي» بالشعار الكامل مع الاسم (D27).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 24, 24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                // مربع ثابت حتى لا تقفز الصفحة عند اكتمال تحميل الصورة.
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.asset(
                    logoAsset,
                    semanticLabel: l10n.aboutLogoLabel,
                    // الملف 1254×1254؛ يُفك بحجم العرض فقط لتوفير الذاكرة.
                    cacheWidth: (240 * dpr).round(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text(
                l10n.appTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.aboutDescription,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.aboutFree,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
