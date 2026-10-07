import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../routing/app_routes.dart';

/// تبويب «التراث» (DESIGN R2.9): مدخل إلى «أصل التقويم» (D24) و«المصادر»
/// (D27). صفحات «عن هذا التقويم» (الميزة 13) لم تُبنَ بعد.
class HeritageScreen extends StatelessWidget {
  const HeritageScreen({super.key});

  static const screenKey = Key('heritageScreen');
  static const originRowKey = Key('heritageOriginRow');
  static const sourcesRowKey = Key('heritageSourcesRow');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: screenKey,
      appBar: AppBar(title: Text(l10n.tabHeritage)),
      body: ListView(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
        children: [
          ListTile(
            key: originRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.history_edu_outlined),
            title: Text(l10n.originTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.origin),
          ),
          ListTile(
            key: sourcesRowKey,
            minTileHeight: 56,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(l10n.settingsSources),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.sources),
          ),
        ],
      ),
    );
  }
}
