import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/ports/auth_service.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_status_provider.dart';
import 'login_screen.dart';

/// يعرض حوار "انتهت جلستك" مرة عند كل تحوّل إلى expired (DESIGN: حوار بزر واحد).
class SessionExpiredListener extends ConsumerStatefulWidget {
  const SessionExpiredListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SessionExpiredListener> createState() => _SessionExpiredListenerState();
}

class _SessionExpiredListenerState extends ConsumerState<SessionExpiredListener> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AuthStatus>(authStatusProvider, (prev, next) {
      if (next == AuthStatus.expired && prev != AuthStatus.expired) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _show());
      }
    }, fireImmediately: true);
  }

  Future<void> _show() async {
    if (!mounted || _showing) return;
    _showing = true;
    final l = AppLocalizations.of(context);
    final signIn = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const Key('sessionExpiredDialog'),
        content: Text(l.sessionExpired),
        actions: [
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text(l.signIn)),
        ],
      ),
    );
    _showing = false;
    if (signIn == true && mounted) await openLoginScreen(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
