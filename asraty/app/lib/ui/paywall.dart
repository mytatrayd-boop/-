import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/access.dart';
import 'common.dart';
import 'providers.dart';
import 'theme.dart';

/// Whether this device may use the app (activation code or subscription), with the store.
class AccessNotifier extends Notifier<int> {
  Store? _store;
  Store get store => _store ??= (Store(ref.read(prefsProvider), () => state++)..startSoon());

  bool get allowed => Access.allowed(ref.read(prefsProvider));

  @override
  int build() {
    ref.onDispose(() => _store?.dispose());
    return 0;
  }

  Future<void> redeem(String code) async {
    final id = await Access.deviceId();
    await ref.read(backendProvider).redeemCode(code, id);
    await Access.saveCode(ref.read(prefsProvider), code.trim().toUpperCase());
    state++;
  }
}

final accessProvider = NotifierProvider<AccessNotifier, int>(AccessNotifier.new);

/// "استخدم كود للتسجيل": enter a free activation code (one device per code).
Future<void> showActivation(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => const _ActivationDialog());
  if (ok == true && context.mounted) toast(context, context.t.activated);
}

class _ActivationDialog extends ConsumerStatefulWidget {
  const _ActivationDialog();
  @override
  ConsumerState<_ActivationDialog> createState() => _ActivationDialogState();
}

class _ActivationDialogState extends ConsumerState<_ActivationDialog> {
  final _ctl = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return AlertDialog(
      title: Text(t.activationTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.activationSub, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          controller: _ctl,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: InputDecoration(hintText: t.activationHint),
        ),
        if (_err != null) ...[const SizedBox(height: 8), ErrBox(_err!)],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
        Btn(t.activate, small: true, onPressed: () async {
          try {
            await ref.read(accessProvider.notifier).redeem(_ctl.text);
            if (context.mounted) Navigator.pop(context, true);
          } catch (e) {
            if (mounted) setState(() => _err = errorText(t, e));
          }
        }),
      ],
    );
  }
}

/// Shown on iPhone builds with the subscription gate on, when this device has
/// neither an activation code nor a subscription.
class PaywallPage extends ConsumerWidget {
  const PaywallPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(accessProvider);
    final t = context.t, store = ref.read(accessProvider.notifier).store;
    String priceOf(String id, String fallback) => store.products.where((p) => p.id == id).firstOrNull?.price ?? fallback;
    Widget plan(String id, String title, String fallback, {bool best = false}) {
      final p = store.products.where((p) => p.id == id).firstOrNull;
      return OutlineCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              Muted(priceOf(id, fallback)),
            ]),
          ),
          Btn(t.startTrial, kind: best ? BtnKind.sun : BtnKind.main, small: true, onPressed: p == null ? null : () => store.buy(p)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 8),
      const Center(child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 54))),
      H2(t.paywallTitle),
      Muted(t.paywallSub),
      const SizedBox(height: 12),
      if (store.loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
      plan(Access.monthlyId, t.planMonthly, t.planMonthlyPrice),
      plan(Access.yearlyId, t.planYearly, t.planYearlyPrice, best: true),
      if (store.error == 'store-unavailable') ErrBox(t.storeUnavailable),
      const SizedBox(height: 6),
      Muted(t.paywallFamily),
      const SizedBox(height: 6),
      Btn(t.restorePurchases, kind: BtnKind.ghost, onPressed: store.restore),
      const SizedBox(height: 14),
      Center(
        child: TextButton(
          onPressed: () => showActivation(context, ref),
          style: TextButton.styleFrom(foregroundColor: context.pal.brandInk),
          child: Text(t.orUseCode, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}
