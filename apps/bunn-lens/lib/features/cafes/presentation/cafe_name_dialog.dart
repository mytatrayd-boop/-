import 'package:flutter/material.dart';

import '../../../l10n/gen/app_localizations.dart';

/// يطلب اسم المقهى (إلزامي) مع اقتراحات من أسماء محفوظة. يعيد الاسم بعد التقليم أو null عند الإلغاء.
Future<String?> showCafeNameDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  List<String> suggestions = const [],
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _CafeNameDialog(title: title, initial: initial, suggestions: suggestions),
    );

class _CafeNameDialog extends StatefulWidget {
  const _CafeNameDialog({required this.title, required this.initial, required this.suggestions});

  final String title;
  final String initial;
  final List<String> suggestions;

  @override
  State<_CafeNameDialog> createState() => _CafeNameDialogState();
}

class _CafeNameDialogState extends State<_CafeNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  final FocusNode _focus = FocusNode();
  bool _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
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
      content: RawAutocomplete<String>(
        textEditingController: _controller,
        focusNode: _focus,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          return widget.suggestions
              .where((s) => s.toLowerCase().contains(q) && s.toLowerCase() != q);
        },
        onSelected: (_) => setState(() => _showError = false),
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: l10n.cafeNameLabel,
            errorText: _showError ? l10n.cafeNameRequired : null,
          ),
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
          onSubmitted: (_) => _submit(),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180, maxWidth: 260),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(dense: true, title: Text(o), onTap: () => onSelected(o)),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.cafeSaveAction)),
      ],
    );
  }
}
