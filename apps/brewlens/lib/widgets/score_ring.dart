import 'package:flutter/material.dart';

import '../app/labels.dart';
import '../l10n/app_localizations.dart';

/// حلقة الدرجة (DESIGN §1.4): دائرة 160، سُمك 12، تمتلئ في 600ms.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 160});

  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final animate = !MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: l.scoreSemantics(formatScore(score)),
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : score / 10, end: score / 10),
            duration: animate ? const Duration(milliseconds: 600) : Duration.zero,
            builder: (context, value, _) => Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  color: scheme.secondary,
                  backgroundColor: scheme.outlineVariant,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.all(20),
                  child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    textDirection: TextDirection.ltr,
                    children: [
                      Text(formatScore(score), style: text.displayLarge),
                      Text(
                        l.scoreOutOf,
                        style: text.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
