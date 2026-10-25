import 'package:flutter/material.dart';

import '../app/router.dart';
import '../app/theme.dart';
import '../l10n/app_localizations.dart';

/// يضع شريط «نسخة عرض» ثابتاً أعلى كل شاشة ويدفع المحتوى تحته (DESIGN §2.1).
class DemoBannerFrame extends StatelessWidget {
  const DemoBannerFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DemoBanner(),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  void _explain() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.demoDialogTitle),
        content: Text(l.demoDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.ok),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: demoBannerForeground,
          fontWeight: FontWeight.w700,
        );
    return Material(
      color: demoBannerBackground,
      child: InkWell(
        onTap: _explain,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 28),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: demoBannerForeground),
                  const SizedBox(width: 6),
                  Flexible(child: Text(l.demoBanner, style: style, textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
