import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'access.dart';
import 'providers.dart';

final receiptCheckerProvider = Provider<ReceiptChecker>((ref) => ServerReceiptChecker());

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
    Widget option(String id, String label, {bool best = false}) {
      final p = store.product(id);
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Text(p?.price ?? '—', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            FilledButton(onPressed: p == null || store.checking ? null : () => store.buy(p), child: Text(t.paywallStartTrial)),
          ]),
        ),
      );
    }

    final err = store.error;
    final errText = err == null
        ? null
        : switch (err) {
            'store-unavailable' => t.paywallUnavailable,
            'not-active' => t.paywallNotActive,
            _ => t.paywallVerifyFailed,
          };
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 12),
          const Center(child: Text('🕌', style: TextStyle(fontSize: 54))),
          const SizedBox(height: 8),
          Text(t.paywallTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(t.paywallSub, textAlign: TextAlign.center, style: const TextStyle(height: 1.6)),
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
          TextButton(onPressed: () => launchUrl(Uri.parse(LamhaAccess.privacyUrl), mode: LaunchMode.externalApplication), child: Text(t.paywallPrivacy)),
        ]),
      ),
    );
  }
}
