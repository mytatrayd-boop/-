import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/app_logo.dart';

/// شاشة اشتراك مبدئية عند انتهاء الحد (الدفعة ب). الشاشة الكاملة بالأسعار
/// والشراء في الدفعة ج (ARCHITECTURE §13).
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l.close, icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(size: 72),
              const SizedBox(height: 24),
              Text(l.failureLimitReached, style: text.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(l.paywallRenews, style: text.bodyLarge, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
