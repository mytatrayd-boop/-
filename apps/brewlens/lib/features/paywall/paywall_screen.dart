import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/failure_text.dart';
import '../../app/legal_links.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../domain/models/purchase_offer.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_logo.dart';
import '../legal/legal_screen.dart';

final offersProvider = FutureProvider.autoDispose<List<PurchaseOffer>>(
  (ref) => ref.watch(purchasesRepositoryProvider).offers(),
);

/// شاشة الاشتراك (F9، DESIGN §3.8). [fromSettings] يغيّر العنوان فقط.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PlanPeriod _selected = PlanPeriod.annual;
  var _busy = false;
  var _done = false;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// في وضع العرض أو غياب RevenueCat: رسالة فقط بلا محاولة شراء.
  bool _guardUnavailable() {
    if (ref.read(purchasesRepositoryProvider).isAvailable) return false;
    final l = AppLocalizations.of(context);
    _snack(ref.read(appConfigProvider).isDemo ? l.purchaseUnavailableDemo : l.failurePurchaseUnavailable);
    return true;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || _guardUnavailable()) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      if (mounted) _snack(failureText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _subscribed() {
    ref.invalidate(usageProvider);
    if (mounted) setState(() => _done = true);
  }

  Future<void> _purchase(PurchaseOffer offer) => _run(() async {
        if (await ref.read(purchasesRepositoryProvider).purchase(offer)) _subscribed();
      });

  Future<void> _restore() => _run(() async {
        await ref.read(purchasesRepositoryProvider).restore();
        _subscribed();
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l.close, icon: const Icon(Icons.close), onPressed: () => context.pop()),
        actions: [
          if (!_done)
            TextButton(
              key: const Key('restore_purchases'),
              onPressed: _busy ? null : _restore,
              child: Text(l.restorePurchases),
            ),
        ],
      ),
      body: SafeArea(child: _done ? _success(l) : _offers(l)),
    );
  }

  Widget _success(AppLocalizations l) => Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 72, color: successColor(context)),
              const SizedBox(height: 16),
              Text(l.subscribedTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pushReplacement(Routes.capture),
                child: Text(l.startCapturing),
              ),
            ],
          ),
        ),
      );

  Widget _offers(AppLocalizations l) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final offers = ref.watch(offersProvider);
    final list = offers.value ?? const <PurchaseOffer>[];
    final selected = list.where((o) => o.period == _selected).firstOrNull;
    // الأسعار الاحتياطية (D8) تُنسَّق بالريال؛ أسعار المتجر تُعرض كما هي.
    final fallback = !ref.watch(purchasesRepositoryProvider).isAvailable;
    String price(PurchaseOffer o) => fallback ? l.priceSar(o.priceLabel) : o.priceLabel;
    final annual = list.where((o) => o.period == PlanPeriod.annual).firstOrNull;
    final monthly = list.where((o) => o.period == PlanPeriod.monthly).firstOrNull;
    final annualValue = double.tryParse(annual?.priceLabel ?? '');
    final monthlyValue = double.tryParse(monthly?.priceLabel ?? '');
    final saving = fallback && annualValue != null && monthlyValue != null && monthlyValue > 0
        ? ((1 - annualValue / (monthlyValue * 12)) * 100).floor()
        : null;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      children: [
        const Center(child: AppLogo(size: 72)),
        const SizedBox(height: 16),
        Text(
          widget.fromSettings ? l.paywallTitleSettings : l.paywallTitleLimit,
          style: text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(l.paywallRenews,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        for (final benefit in [l.paywallBenefitLimit, l.paywallBenefitReport, l.paywallBenefitHistory])
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(benefit, style: text.bodyLarge)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (offers.isLoading)
          for (var i = 0; i < 2; i++)
            Container(
              height: 88,
              margin: const EdgeInsetsDirectional.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
            )
        else if (offers.hasError)
          Text(failureText(l, offers.error!), textAlign: TextAlign.center)
        else ...[
          if (annual != null)
            _PlanCard(
              key: const Key('plan_annual'),
              selected: _selected == PlanPeriod.annual,
              title: l.planAnnual,
              price: l.perYear(price(annual)),
              secondary: fallback && annualValue != null ? l.perMonthApprox(l.priceSar((annualValue / 12).toStringAsFixed(2))) : null,
              badges: [
                if (annual.trialDays > 0) l.trialDays(annual.trialDays),
                if (saving != null && saving > 0) l.savePercent(saving),
              ],
              onTap: () => setState(() => _selected = PlanPeriod.annual),
            ),
          if (monthly != null)
            _PlanCard(
              key: const Key('plan_monthly'),
              selected: _selected == PlanPeriod.monthly,
              title: l.planMonthly,
              price: l.perMonth(price(monthly)),
              onTap: () => setState(() => _selected = PlanPeriod.monthly),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('subscribe'),
          onPressed: selected == null || _busy ? null : () => _purchase(selected),
          child: _busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(selected != null && selected.trialDays > 0 ? l.startFreeTrial : l.subscribeNow),
        ),
        const SizedBox(height: 12),
        Text(l.subscriptionTerms,
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(onPressed: () => openLegal(context, LegalDoc.terms), child: Text(l.termsShort)),
            TextButton(onPressed: () => openLegal(context, LegalDoc.privacy), child: Text(l.privacyShort)),
          ],
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    super.key,
    required this.selected,
    required this.title,
    required this.price,
    required this.onTap,
    this.secondary,
    this.badges = const [],
  });

  final bool selected;
  final String title;
  final String price;
  final String? secondary;
  final List<String> badges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: scheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(title, style: text.titleMedium),
                            for (final b in badges)
                              Container(
                                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(b,
                                    style: text.labelMedium?.copyWith(color: scheme.onSecondaryContainer)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(price, style: text.titleLarge),
                        if (secondary != null)
                          Text(secondary!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
