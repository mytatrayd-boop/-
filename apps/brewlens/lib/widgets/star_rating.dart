import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// النجوم 1–5 (DESIGN §1.4): أيقونات 32 في مناطق لمس 48، تُرسم من البداية
/// (يميناً في RTL). الضغط على النجمة المختارة نفسها يلغي التقييم.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 32});

  final int? value;
  final ValueChanged<int?>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = value ?? 0;
    final stars = [
      for (var i = 1; i <= 5; i++)
        Icon(
          i <= current ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: i <= current ? scheme.secondary : scheme.outline,
        ),
    ];
    if (onChanged == null) {
      return Semantics(
        label: l.ratingSemantics(current),
        child: ExcludeSemantics(child: Row(mainAxisSize: MainAxisSize.min, children: stars)),
      );
    }
    return Semantics(
      label: l.ratingSemantics(current),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              button: true,
              selected: i == current,
              label: l.starSemantics(i),
              child: InkResponse(
                key: Key('star_$i'),
                radius: 24,
                onTap: () => onChanged!(i == current ? null : i),
                child: SizedBox(width: 48, height: 48, child: Center(child: stars[i - 1])),
              ),
            ),
        ],
      ),
    );
  }
}
