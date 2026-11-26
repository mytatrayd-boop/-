import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../domain/ports/local_playlist_repository.dart';
import '../../l10n/gen/app_localizations.dart';

/// حوار اسم القائمة: حقل مملوء مسبقاً ولوحة المفاتيح مفتوحة، و«حفظ» معطّل والاسم
/// فارغ. يعيد الاسم بعد القص أو null عند الإلغاء. الأسماء المكررة مسموحة (D27).
Future<String?> showPlaylistNameDialog(BuildContext context, {required String title, String initial = ''}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(title: title, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});
  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _text = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final n = _text.text.trim();
    if (n.isNotEmpty) Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text(widget.title),
      content: TextField(
        key: const Key('playlistNameField'),
        controller: _text,
        autofocus: true,
        maxLength: LocalPlaylistRepository.maxNameLength,
        decoration: InputDecoration(labelText: l.playlistNameLabel),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(
          key: const Key('playlistNameSave'),
          onPressed: _text.text.trim().isEmpty ? null : _submit,
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// حوار تأكيد بزر إجراء بلون الخطأ و«إلغاء».
Future<bool> confirmDestructive(BuildContext context,
    {required String title, required String body, required String action}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(l.cancel)),
        TextButton(
          key: const Key('confirmDestructive'),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(c).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}
