import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../domain/models/app_failure.dart';
import '../../domain/validators.dart';
import '../../l10n/app_localizations.dart';
import 'auth_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
          );
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
    final minLength = minPasswordLength(isDemo: ref.watch(appConfigProvider).isDemo);
    final error = _error;
    final emailTaken = error is AppFailure && error.code == FailureCode.emailTaken;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(16),
          child: Form(
            key: _form,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.signUpTitle, style: text.headlineMedium),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsetsDirectional.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: scheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l.signUpReason,
                            style: text.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  EmailField(controller: _email, enabled: !_loading),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _password,
                    label: l.passwordLabel,
                    enabled: !_loading,
                    helperText: l.passwordHint(minLength),
                    validator: (v) =>
                        (v ?? '').length < minLength ? l.errorPasswordShort(minLength) : null,
                  ),
                  const SizedBox(height: 16),
                  PasswordField(
                    controller: _confirm,
                    label: l.confirmPasswordLabel,
                    enabled: !_loading,
                    onSubmitted: _submit,
                    validator: (v) => v != _password.text ? l.errorPasswordMismatch : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l.termsNotice,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (error != null) ...[
                    ErrorBox(
                      message: failureText(l, error),
                      action: emailTaken
                          ? TextButton(
                              onPressed: () => context.go(Routes.login),
                              child: Text(l.signInLink),
                            )
                          : offlineRetryAction(context, error, _submit),
                    ),
                    const SizedBox(height: 12),
                  ],
                  LoadingButton(label: l.signUpButton, loading: _loading, onPressed: _submit),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l.haveAccountPrompt),
                      TextButton(
                        onPressed: _loading ? null : () => context.go(Routes.login),
                        child: Text(l.signInLink),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
