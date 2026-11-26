import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers.dart';
import '../../domain/models/video_ref.dart';
import '../../l10n/gen/app_localizations.dart';
import '../browse/api_providers.dart';
import '../home/home_screen.dart';
import '../home/link_intake.dart';
import '../library/library_screen.dart';
import '../player/mini_player.dart';
import '../queue/queue_ui.dart';
import '../settings/settings_screen.dart';

/// الهيكل: شريط سفلي بثلاث وجهات (الرئيسية/البحث، المكتبة، الإعدادات) وفوقه
/// المشغّل المصغّر (DESIGN: التنقل). لكل وجهة متصفّحها فيبقى المصغّر ظاهراً
/// داخلها، والمشغّل الكامل يُفتح فوق الكل. يستقبل المشاركة هنا لأنه دائماً ظاهر.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  /// الوجهات تُبنى عند أول زيارة فقط (لا قراءة للتخزين ولا طلبات لوجهة لم تُفتح).
  final _visited = <int>{0};
  final _navigators = [GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>(), GlobalKey<NavigatorState>()];

  StreamSubscription<String>? _incomingSub;
  StreamSubscription<VideoRef>? _skippedSub;

  @override
  void initState() {
    super.initState();
    // مقطع فشل وتُخطّي: رسالة قصيرة (DESIGN 4أ).
    _skippedSub = ref.read(playbackQueueProvider).skippedFailures.listen((r) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      showUndoSnack(ScaffoldMessenger.of(context), l, l.queueSkippedSnack(shortTitle(l, r)));
    });
    final source = ref.read(incomingLinkSourceProvider);
    // أثناء التشغيل.
    _incomingSub = source.texts.listen(_handleIncoming);
    // بدء بارد.
    source.initialText().then((t) {
      if (t != null && mounted) _handleIncoming(t);
    }).catchError((Object _) {
      // فشل قراءة نية البدء لا يجب أن يُسقط التطبيق؛ يبدأ فارغاً.
    });
  }

  Future<void> _handleIncoming(String shared) async {
    if (!mounted) return;
    await submitLink(context, ref, shared, shared: true);
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _skippedSub?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) {
      // نقرة على الوجهة الحالية: عودة لأولها.
      _navigators[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    // الحصة تتغيّر بالاستعمال: تُقرأ من جديد عند فتح الإعدادات.
    if (i == 2) ref.invalidate(quotaTodayProvider);
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  /// رجوع النظام: داخل الوجهة أولاً، ثم إلى الرئيسية، ثم خروج.
  void _onBack() {
    final nav = _navigators[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
    } else if (_index != 0) {
      setState(() => _index = 0);
    } else {
      SystemNavigator.pop();
    }
  }

  Widget _tab(int i, Widget root) => !_visited.contains(i)
      ? const SizedBox.shrink()
      : Navigator(
        key: _navigators[i],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(settings: settings, builder: (_) => root),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _tab(0, const HomeScreen()),
            _tab(1, const LibraryScreen()),
            _tab(2, const SettingsScreen()),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              key: const Key('bottomNav'),
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                NavigationDestination(
                  key: const Key('navHome'),
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: l.navHome,
                ),
                NavigationDestination(
                  key: const Key('navLibrary'),
                  icon: const Icon(Icons.library_music_outlined),
                  selectedIcon: const Icon(Icons.library_music),
                  label: l.navLibrary,
                ),
                NavigationDestination(
                  key: const Key('navSettings'),
                  icon: const Icon(Icons.settings),
                  label: l.settings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
