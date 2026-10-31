import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// محتوى هيكلي فارغ للشاشات إلى أن تُبنى ميزاتها.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).placeholderSoon,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
