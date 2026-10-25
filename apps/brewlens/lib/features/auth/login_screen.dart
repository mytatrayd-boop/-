import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/failure_text.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../domain/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_logo.dart';
import 'auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // النجاح يغيّر الجلسة، وredirect ينقل للرئيسية.
      await ref.read(authRepositoryProvider).signIn(
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
    final text = Theme.of(context).textTheme;
    final minLength = minPasswordLength(isDemo: ref.watch(appConfigProvider).isDemo);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(16),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo()),
                    const SizedBox(height: 16),
                    Text(l.appTitle, style: text.headlineMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      l.appTagline,
                      style: text.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    EmailField(controller: _email, enabled: !_loading),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: _password,
                      label: l.passwordLabel,
                      enabled: !_loading,
                      onSubmitted: _submit,
                      validator: (v) => (v ?? '').length < minLength
                          ? l.errorPasswordShort(minLength)
                          : null,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => context.push(Uri(
                                  path: Routes.forgot,
                                  queryParameters: {'email': _email.text.trim()},
                                ).toString()),
                        child: Text(l.forgotPasswordLink),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_error != null) ...[
                      ErrorBox(message: failureText(l, _error!)),
                      const SizedBox(height: 12),
                    ],
                    LoadingButton(label: l.signInButton, loading: _loading, onPressed: _submit),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(l.noAccountPrompt),
                        TextButton(
                          onPressed: _loading ? null : () => context.push(Routes.signup),
                          child: Text(l.createAccountLink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
