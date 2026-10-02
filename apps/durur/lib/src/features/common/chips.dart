import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/weather_symbol.dart';
import '../../theme/app_theme.dart';
import 'weather_icon.dart';

/// شريحة موسم: نقطة بلونه + اسمه، قابلة للضغط (DESIGN 5.3).
class SeasonChip extends StatelessWidget {
  const SeasonChip({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

/// شريحة جو للعرض فقط: أيقونة + كلمة (DESIGN 5.3).
class WeatherChip extends StatelessWidget {
  const WeatherChip({super.key, required this.symbol});

  final WeatherSymbol symbol;

  @override
  Widget build(BuildContext context) {
    final colors = DururColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WeatherIcon(symbol, color: colors.ink),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              weatherSymbolLabel(AppLocalizations.of(context), symbol),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
