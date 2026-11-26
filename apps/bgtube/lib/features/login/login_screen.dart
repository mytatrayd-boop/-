import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_failure.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../domain/ports/auth_service.dart';
import '../../l10n/gen/app_localizations.dart';
import '../player/failure_message.dart';

/// يفتح شاشة الدخول. يعيد true عند نجاح الدخول.
Future<bool> openLoginScreen(BuildContext context) async {
  final ok = await Navigator.of(context)
      .push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
  return ok ?? false;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  bool _asking = false;
  AppFailure? _failure;

  Future<void> _continue() async {
    if (_busy || _asking) return;
    _asking = true;
    final acknowledged = await _ensureRiskAcknowledged();
    _asking = false;
    if (!acknowledged || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final outcome = await ref.read(authServiceProvider).signIn();
      if (!mounted) return;
      if (outcome == SignInOutcome.signedIn) {
        Navigator.of(context).pop(true);
      }
      // الإلغاء/الرفض: نبقى هنا دون خطأ.
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } catch (_) {
      if (mounted) setState(() => _failure = const AppFailure(FailureKind.signInFailed));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// D10: إقرار مرة واحدة قبل أول دخول.
  Future<bool> _ensureRiskAcknowledged() async {
    final store = ref.read(riskAckStoreProvider);
    bool acknowledged;
    try {
      acknowledged = await store.isAcknowledged();
    } catch (_) {
      acknowledged = false;
    }
    if (acknowledged) return true;
    if (!mounted) return false;
    final accepted = await showRiskAckDialog(context);
    if (!accepted) return false;
    try {
      await store.acknowledge();
    } catch (_) {
      // فشل الحفظ: يُسأل مجدداً في المرة القادمة، ولا يمنع الدخول الآن.
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final failure = _failure;
    final unavailable = failure?.kind == FailureKind.signInUnavailable;

    return Scaffold(
      appBar: AppBar(title: Text(l.signIn)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.headphones, size: 48, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(l.loginExplain,
                      textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 32),
                  if (failure != null)
                    Row(
                      key: const Key('loginError'),
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(failureMessage(l, failure),
                              style: const TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (!unavailable)
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('loginContinue'),
                        onPressed: _busy ? null : _continue,
                        child: _busy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(failure == null ? l.loginContinue : l.retry,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      key: const Key('loginNotNow'),
                      onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                      child: Text(l.loginNotNow),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l.loginNoPassword,
                      textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// حوار إقرار الخطر (D10). true = أقرّ المستخدم.
Future<bool> showRiskAckDialog(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const Key('riskDialog'),
      icon: const Icon(Icons.warning_amber_outlined, color: AppColors.warning),
      title: Text(l.riskTitle),
      content: SingleChildScrollView(child: Text(l.riskBody)),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(c).pop(true), child: Text(l.riskAccept)),
      ],
    ),
  );
  return ok ?? false;
}
