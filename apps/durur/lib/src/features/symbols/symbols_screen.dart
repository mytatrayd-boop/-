import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../domain/weather_symbol.dart';
import '../../theme/app_theme.dart';
import '../common/glass.dart';
import '../common/weather_icon.dart';

/// «دليل الرموز» (تبويب «الرموز»، SPEC 16.8، DESIGN R2.6): رموز الجو الـ17
/// كاملة، لكل رمز أيقونته واسمه وسطر شرحه.
class SymbolsScreen extends StatelessWidget {
  const SymbolsScreen({super.key});

  static const screenKey = Key('symbolsScreen');
  static Key rowKey(WeatherSymbol s) => Key('symbolRow_${s.code}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = DururColors.of(context);
    return Scaffold(
      key: screenKey,
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.symbolsTitle)),
      body: Stack(
        children: [
          const Positioned.fill(child: NightSky(glowCenter: 0.1, rose: false)),
          ListView.separated(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
            itemCount: WeatherSymbol.values.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = WeatherSymbol.values[i];
              final name = weatherSymbolLabel(l10n, s);
              final desc = l10n.weatherSymbolDesc(s.code);
              return Semantics(
                key: rowKey(s),
                container: true,
                label: '$name. $desc',
                excludeSemantics: true,
                child: GlassSurface(
                  radius: 16,
                  padding: const EdgeInsetsDirectional.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WeatherIcon(s, size: 24, color: colors.weatherTone(s.code)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(desc, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
