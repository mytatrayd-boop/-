import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../routing/app_router.dart';
import 'onboarding_layout.dart';

/// الترحيب (DESIGN 8.2 أ): أول شاشة في أول تشغيل.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const startKey = Key('welcomeStart');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OnboardingLayout(
      icon: Icons.wb_twilight,
      title: l10n.onboardingWelcomeTitle,
      body: l10n.onboardingWelcomeBody,
      actions: [
        FilledButton(
          key: startKey,
          style: OnboardingLayout.buttonStyle,
          onPressed: () => context.push(AppRoutes.onboardingLocation),
          child: Text(l10n.onboardingWelcomeStart),
        ),
      ],
    );
  }
}
