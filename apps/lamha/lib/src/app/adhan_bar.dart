import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'providers.dart';

/// شريط أسفل الشاشة يظهر والأذان الكامل يُشغَّل داخل التطبيق (آيفون)، وفيه زر الإيقاف.
class AdhanBar extends ConsumerWidget {
  const AdhanBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(adhanPlayerProvider);
    return ValueListenableBuilder<bool>(
      valueListenable: player.playing,
      builder: (context, playing, _) {
        if (!playing) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                key: const Key('adhan-bar'),
                color: const Color(0xFF0B2E5B),
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Icon(Icons.volume_up, color: Color(0xFFE0BD6E)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.adhanPlaying,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        key: const Key('adhan-stop'),
                        onPressed: player.stop,
                        child: Text(l.adhanStop, style: const TextStyle(color: Color(0xFFE0BD6E))),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
