import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../app/widgets/placeholder_body.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: const PlaceholderBody(icon: Icons.history),
    );
  }
}
