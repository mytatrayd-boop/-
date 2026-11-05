import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/access.dart';
import '../backend/backend.dart';
import '../core/models.dart';
import 'common.dart';
import 'providers.dart';
import 'shell.dart';
import 'theme.dart';

/// Who may use the app (the family admin: a free code on this device, or a plan the server recorded),
/// and the store.
class AccessNotifier extends Notifier<int> {
  Store? _store;
  var _synced = false, _syncing = false;

  Store get store => _store ??= (Store(() => state++, _sink)..startSoon());

  /// A bought or restored subscription: the server checks Apple's receipt and records the tier.
  Future<void> _sink(String productId, String receipt) async {
    try {
      await ref.read(backendProvider).activatePlan(receipt, platform: defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios');
    } on AppError catch (e) {
      throw StoreSinkError(e.code);
    }
  }

  bool get hasCode => Access.savedCode(ref.read(prefsProvider)) != null;

  /// The owner may use the app now (always true when the gate is off, e.g. Android or the demo).
  bool ownerAllowed(FamilyPlan? plan, DateTime now) => Access.ownerAllowed(ref.read(prefsProvider), plan, now);

  /// Whether the server was already asked to mark an old family as "legacy" in this run.
  bool get synced => _synced;

  Future<void> syncOnce() async {
    if (_synced || _syncing) return;
    _syncing = true;
    try {
      await ref.read(backendProvider).syncPlan();
    } catch (_) {
      // Offline: the paywall shows; the next start asks again.
    }
    _synced = true;
    _syncing = false;
    state++;
  }

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

/// The subscription screen: three levels by the number of members (5 / 10 / 20), each monthly or yearly
/// with a 7-day trial. Compact: a monthly/yearly switch, one row per level (pick one), one button.
/// Shown to a family admin without an active plan or code; also opened as "ترقية"
/// ([upgrade]) from the add-member page when the family reaches its limit.
class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key, this.upgrade = false});
  final bool upgrade;

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  var _yearly = true;
  var _tier = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(accessProvider);
    final t = context.t, store = ref.read(accessProvider.notifier).store, pal = context.pal;
    final upgrade = widget.upgrade;
    String idOf(int i) => _yearly ? Access.tiers[i].yearly : Access.tiers[i].monthly;
    final chosen = store.product(idOf(_tier));

    Widget row(int i) {
      final selected = i == _tier, tier = Access.tiers[i];
      return Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _tier = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: selected ? pal.mintBg : null,
              border: Border.all(color: selected ? pal.brandInk : pal.line, width: selected ? 2 : 1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? pal.brandInk : pal.muted),
              const SizedBox(width: 10),
              Expanded(child: Text('${t.planTierUpTo} ${tier.members} ${t.planTierMembers}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text(store.product(idOf(i))?.price ?? '—', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: pal.brandInk)),
            ]),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (upgrade) BackLink(t.settings) else const SizedBox(height: 8),
      if (!upgrade) const Center(child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 54))),
      H2(t.paywallTitle),
      Muted(t.paywallSub),
      SegTabs<bool>(tabs: [(false, t.planMonthly, 0), (true, t.planYearly, 0)], value: _yearly, onChanged: (v) => setState(() => _yearly = v)),
      if (store.loading) const Center(child: Padding(padding: EdgeInsets.all(16), child: PulseDot(size: 32))),
      for (var i = 0; i < Access.tiers.length; i++) row(i),
      const SizedBox(height: 4),
      Btn(upgrade ? t.upgradePlan : t.startTrial, kind: BtnKind.sun, expand: true, onPressed: chosen == null ? null : () => store.buy(chosen)),
      if (store.error != null) ...[const SizedBox(height: 8), ErrBox(store.error == 'store-unavailable' ? t.storeUnavailable : errorText(t, AppError(store.error!)))],
      const SizedBox(height: 8),
      Muted(t.paywallFamily),
      const SizedBox(height: 6),
      Btn(t.restorePurchases, kind: BtnKind.ghost, onPressed: store.restore),
      if (!upgrade) ...[
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => showActivation(context, ref),
            style: TextButton.styleFrom(foregroundColor: pal.brandInk),
            child: Text(t.orUseCode, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ]);
  }
}
