import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/legal_links.dart';
import '../../app/router.dart';
import '../../l10n/app_localizations.dart';

/// يفتح الرابط المنشور إن وُجد، وإلا الصفحة الداخلية المؤقتة.
Future<void> openLegal(BuildContext context, LegalDoc doc) async {
  final url = LegalLinks.of(doc);
  if (url != null && await launchUrl(url, mode: LaunchMode.externalApplication)) return;
  if (context.mounted) await context.push(Routes.legalPath(doc));
}

/// صفحة مؤقتة بنص مختصر حتى ينشر المالك السياسة والشروط.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final privacy = doc == LegalDoc.privacy;
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? l.privacyPolicy : l.termsOfUse)),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(16),
        child: Text(
          privacy ? l.privacyBody : l.termsBody,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
