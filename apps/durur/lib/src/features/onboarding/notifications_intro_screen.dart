import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../formatting/digits.dart';
import '../../providers.dart';
import '../../routing/app_routes.dart';
import 'onboarding_layout.dart';

/// شرح التنبيهات (DESIGN 8.2 د، SPEC 8 معيار 8): آخر شاشات البداية بعد
/// اختيار المدينة. «فعّل التنبيهات» يطلب إذن النظام، وقبوله أو رفضه ينهي
/// الإعداد الأولي ويفتح الرئيسية؛ «ليس الآن» ينهيه بلا طلب. المفتاحان يبقيان
/// على قيمتهما (المواسم المهمة مفعّل)، وتظهر ملاحظة الإذن في الإعدادات.
class NotificationsIntroScreen extends ConsumerStatefulWidget {
  const NotificationsIntroScreen({super.key});

  static const allowKey = Key('notificationsIntroAllow');
  static const notNowKey = Key('notificationsIntroNotNow');

  @override
  ConsumerState<NotificationsIntroScreen> createState() =>
      _NotificationsIntroScreenState();
}

class _NotificationsIntroScreenState
    extends ConsumerState<NotificationsIntroScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final digits = ref.watch(digitStyleProvider);
    return OnboardingLayout(
      icon: Icons.notifications_active_outlined,
      title: l10n.onboardingNotificationsTitle,
      body: localizeDigits(l10n.onboardingNotificationsBody, digits),
      actions: [
        FilledButton(
          key: NotificationsIntroScreen.allowKey,
          style: OnboardingLayout.buttonStyle,
          onPressed: _busy ? null : () => _finish(request: true),
          child: Text(l10n.onboardingNotificationsAllow),
        ),
        TextButton(
          key: NotificationsIntroScreen.notNowKey,
          style: OnboardingLayout.buttonStyle,
          onPressed: _busy ? null : () => _finish(request: false),
          child: Text(l10n.commonNotNow),
        ),
      ],
    );
  }

  Future<void> _finish({required bool request}) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    if (request) {
      // القبول والرفض سواء: الرئيسية في الحالتين.
      await ref.read(notificationPermissionProvider.notifier).request();
    }
    try {
      await ref.read(settingsProvider.notifier).completeOnboarding();
    } on Object {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.citySaveError),
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    router.go(AppRoutes.home);
  }
}
