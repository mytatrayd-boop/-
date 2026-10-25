import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../l10n/app_localizations.dart';
import 'auth_widgets.dart';

/// استعادة كلمة المرور، الخطوة 1 (DESIGN §3.3). في وضع العرض الإرسال شكلي.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const resendCooldown = 60;

  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _loading = false;
  bool _sent = false;
  Object? _error;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_loading || !_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _sent = true;
        _cooldown = resendCooldown;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.forgotTitle, style: text.headlineMedium),
                const SizedBox(height: 24),
                if (_sent) ...[
                  Icon(Icons.mark_email_read_outlined, size: 64, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l.resetSentBody(_email.text.trim()),
                    style: text.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(Routes.login),
                    child: Text(l.backToSignIn),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _cooldown > 0 || _loading ? null : _send,
                    child: Text(_cooldown > 0 ? l.resendIn(_cooldown) : l.resendButton),
                  ),
                ] else ...[
                  Text(l.forgotBody, style: text.bodyLarge),
                  const SizedBox(height: 16),
                  EmailField(controller: _email, enabled: !_loading, onSubmitted: _send),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    ErrorBox(message: failureText(l, _error!)),
                    const SizedBox(height: 12),
                  ],
                  LoadingButton(label: l.sendLinkButton, loading: _loading, onPressed: _send),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
