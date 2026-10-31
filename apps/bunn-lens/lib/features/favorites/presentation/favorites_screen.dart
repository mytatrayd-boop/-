import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../../../app/widgets/placeholder_body.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.favoritesTitle)),
      body: const PlaceholderBody(icon: Icons.star_border),
    );
  }
}
