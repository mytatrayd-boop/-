import 'package:flutter/material.dart';

import '../domain/models/usage.dart';
import '../l10n/app_localizations.dart';

/// شارة العدّاد «متبقٍّ لك اليوم: 1 من 2» (DESIGN §1.4).
class UsageCounter extends StatelessWidget {
  const UsageCounter({super.key, required this.usage, this.onHero = false});

  final Usage usage;

  /// على خلفية primary في بطاقة البطل: خلفية بيضاء شفافة 20%.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final empty = usage.remaining <= 0;
    final background = empty
        ? scheme.errorContainer
        : onHero
            ? scheme.onPrimary.withValues(alpha: 0.2)
            : scheme.primaryContainer;
    final foreground = empty
        ? scheme.onErrorContainer
        : onHero
            ? scheme.onPrimary
            : scheme.onPrimaryContainer;
    final label = usage.period == UsagePeriod.month
        ? l.usageRemainingMonth(usage.remaining, usage.limit)
        : l.usageRemainingDay(usage.remaining, usage.limit);
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_cafe_outlined, size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
