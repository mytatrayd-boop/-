import 'package:flutter/material.dart';

import '../../domain/validators.dart';
import '../../l10n/app_localizations.dart';

/// حقل البريد: اتجاهه LTR حتى في العربية (DESIGN §1.4).
class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller, this.enabled = true, this.onSubmitted});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      key: const Key('email'),
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      textDirection: TextDirection.ltr,
      autofillHints: const [AutofillHints.email],
      textInputAction: onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      decoration: InputDecoration(labelText: l.emailLabel),
      validator: (v) => isValidEmail(v ?? '') ? null : l.errorInvalidEmail,
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.helperText,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscure,
      textDirection: TextDirection.ltr,
      autofillHints: const [AutofillHints.password],
      textInputAction: widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        suffixIcon: IconButton(
          tooltip: _obscure ? l.showPassword : l.hidePassword,
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// صندوق خطأ أعلى الزر بلون errorContainer.
class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// زر رئيسي بحالة تحميل: مؤشر 20 بدل النص والزر معطّل.
class LoadingButton extends StatelessWidget {
  const LoadingButton({super.key, required this.label, required this.loading, required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      );
}
