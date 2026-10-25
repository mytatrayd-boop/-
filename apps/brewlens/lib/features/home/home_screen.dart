import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/usage_counter.dart';

/// رئيسية مبدئية (الدفعة أ): الترحيب والعدّاد. الكاميرا والسجل في الدفعة ب.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.signOutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.signOut)),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final usage = ref.watch(usageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.homeWelcome),
        actions: [
          const AppLogo(size: 32),
          IconButton(
            tooltip: l.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: [
          Container(
            padding: const EdgeInsetsDirectional.all(16),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.homeHeroTitle, style: text.titleLarge?.copyWith(color: scheme.onPrimary)),
                const SizedBox(height: 4),
                Text(l.homeHeroBody, style: text.bodyMedium?.copyWith(color: scheme.onPrimary)),
                const SizedBox(height: 12),
                // خطأ العدّاد: يُخفى فقط (DESIGN §3.4).
                switch (usage) {
                  AsyncData(:final value) => UsageCounter(usage: value, onHero: true),
                  AsyncError() => const SizedBox.shrink(),
                  _ => Text('…', style: TextStyle(color: scheme.onPrimary)),
                },
              ],
            ),
          ),
          const SizedBox(height: 48),
          Icon(Icons.local_cafe_outlined, size: 96, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(l.homeEmpty, style: text.titleMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
