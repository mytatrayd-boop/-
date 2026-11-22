import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'access.dart';
import 'providers.dart';

final receiptCheckerProvider = Provider<ReceiptChecker>((ref) => ServerReceiptChecker());
final codeRedeemerProvider = Provider<CodeRedeemer>((ref) => ServerCodeRedeemer());

/// Holds the store while the gate is on; every change (price loaded, purchase confirmed) re-checks the gate.
class LamhaAccessNotifier extends Notifier<int> {
  LamhaStore? store;

  @override
  int build() {
    ref.onDispose(() => store?.dispose());
    return 0;
  }

  Future<void> ensure() async {
    if (store != null) return;
    final prefs = await ref.read(preferencesProvider.future);
    store = LamhaStore(prefs, ref.read(receiptCheckerProvider), () => state++);
    unawaited(store!.start());
    state++;
  }

  /// Binds a free code to this phone on the server, then opens the app here.
  Future<void> redeem(String code) async {
    final id = await LamhaAccess.deviceId();
    await ref.read(codeRedeemerProvider).redeem(code.trim(), id);
    final prefs = await ref.read(preferencesProvider.future);
    await LamhaAccess.saveCode(prefs, code.trim().toUpperCase());
    state++;
  }
}

final lamhaAccessProvider = NotifierProvider<LamhaAccessNotifier, int>(LamhaAccessNotifier.new);

/// Shows the app when the gate is off or the subscription is active; otherwise the subscription screen.
class AccessGate extends ConsumerStatefulWidget {
  const AccessGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AccessGate> createState() => _AccessGateState();
}

class _AccessGateState extends ConsumerState<AccessGate> {
  @override
  void initState() {
    super.initState();
    if (LamhaAccess.gated) Future.microtask(() => ref.read(lamhaAccessProvider.notifier).ensure());
  }

  @override
  Widget build(BuildContext context) {
    if (!LamhaAccess.gated) return widget.child;
    ref.watch(lamhaAccessProvider);
    final prefs = ref.watch(preferencesProvider).value;
    final store = ref.read(lamhaAccessProvider.notifier).store;
    if (prefs == null || store == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (LamhaAccess.allowed(prefs, DateTime.now())) return widget.child;
    return PaywallScreen(store: store);
  }
}

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key, required this.store});
  final LamhaStore store;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final android = LamhaAccess.platform == 'android';
    Widget option(String id, String label, {bool best = false}) {
      final p = store.product(id);
      final o = p == null ? null : LamhaStore.offer(p);
      final period = o == null ? '—' : (id == LamhaAccess.yearlyId ? t.paywallPerYear(o.price) : t.paywallPerMonth(o.price));
      final priceLine = o == null ? '—' : (o.trial == true ? t.paywallTrialThen(period) : (o.trial == false ? period : o.price));
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(priceLine, style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            FilledButton(onPressed: p == null || store.checking ? null : () => store.buy(p), child: Text(o?.trial == false ? t.paywallSubscribe : t.paywallStartTrial)),
          ]),
        ),
      );
    }

    final err = store.error;
    final errText = err == null
        ? null
        : switch (err) {
            'store-unavailable' => t.paywallUnavailable,
            'not-active' => android ? t.paywallNotActiveAndroid : t.paywallNotActive,
            // الرمز بعد الرسالة (مثل receipt-invalid 21004) ليُعرف سبب الفشل من لقطة الشاشة.
            _ => '${t.paywallVerifyFailed}\n($err)',
          };
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 12),
          const Center(child: Text('🕌', style: TextStyle(fontSize: 54))),
          const SizedBox(height: 8),
          Text(t.paywallTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(android ? t.paywallSubAndroid : t.paywallSub, textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 16),
          if (store.loading || store.checking)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.4)),
                const SizedBox(width: 10),
                Text(t.paywallChecking),
              ]),
            ),
          option(LamhaAccess.monthlyId, t.paywallMonthly),
          option(LamhaAccess.yearlyId, t.paywallYearly, best: true),
          if (errText != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(errText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: store.restore, child: Text(t.paywallRestore)),
          TextButton(onPressed: () => showDialog<void>(context: context, builder: (_) => const CodeDialog()), child: Text(t.codeOpen)),
          TextButton(onPressed: () => launchUrl(Uri.parse(LamhaAccess.privacyUrl), mode: LaunchMode.externalApplication), child: Text(t.paywallPrivacy)),
        ]),
      ),
    );
  }
}

/// «عندي كود تفعيل»: a free code opens the app on this phone (one phone per code), like «أسرتي».
class CodeDialog extends ConsumerStatefulWidget {
  const CodeDialog({super.key});
  @override
  ConsumerState<CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends ConsumerState<CodeDialog> {
  final _ctl = TextEditingController();
  String? _err;
  var _busy = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await ref.read(lamhaAccessProvider.notifier).redeem(_ctl.text);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      final code = e is ReceiptCheckError ? e.code : '';
      if (mounted) {
        setState(() {
          _busy = false;
          _err = switch (code) {
            'code-invalid' => t.codeInvalid,
            'code-used' => t.codeUsed,
            'rate-limited' => t.codeRateLimited,
            _ => t.codeFailed,
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.codeTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.codeSub),
        const SizedBox(height: 10),
        TextField(
          controller: _ctl,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          decoration: const InputDecoration(hintText: 'LAM-XXXX-XXXX'),
        ),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.redAccent))),
      ]),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(t.codeCancel)),
        FilledButton(onPressed: _busy ? null : _activate, child: Text(t.codeActivate)),
      ],
    );
  }
}
