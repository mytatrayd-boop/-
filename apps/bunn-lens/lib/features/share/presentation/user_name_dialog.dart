import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../user_name.dart';

/// يطلب اسم المستخدم للتوقيع. يعيد الاسم المنظَّف أو null عند الإلغاء. الاسم الفارغ لا يُقبل.
Future<String?> showUserNameDialog(
  BuildContext context, {
  required String title,
  String? body,
  String initial = '',
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _UserNameDialog(title: title, body: body, initial: initial),
    );

class _UserNameDialog extends StatefulWidget {
  const _UserNameDialog({required this.title, required this.body, required this.initial});
  final String title;
  final String? body;
  final String initial;

  @override
  State<_UserNameDialog> createState() => _UserNameDialogState();
}

class _UserNameDialogState extends State<_UserNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = normalizeUserName(_controller.text);
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.body != null) ...[Text(widget.body!), const SizedBox(height: 12)],
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: userNameMaxLength,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.shareNameLabel,
              errorText: _showError ? l10n.shareNameRequired : null,
            ),
            onChanged: (_) {
              if (_showError) setState(() => _showError = false);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.shareNameSave)),
      ],
    );
  }
}
