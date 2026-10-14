import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/library_text.dart';

/// صف باب في الفهرس (صفحة الكتاب وورقة الفهرس في القارئ، DESIGN §8.1، §8.3):
/// رقم الباب واسمه، وعلامة «أنت هنا» على الباب الحالي. قارئ الشاشة يقرأ
/// «الباب ٣ من ١٢: باب البيان، أنت هنا» كعنوان.
class ChapterTile extends StatelessWidget {
  const ChapterTile({
    super.key,
    required this.number,
    required this.total,
    required this.title,
    required this.level,
    required this.current,
    required this.onTap,
  });

  final int number;
  final int total;
  final String title;
  final int level;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final numberText = l10n.number(context, number);
    final label = l10n.chapterSemantics(
      numberText,
      l10n.number(context, total),
      title,
    );
    return Semantics(
      header: true,
      button: onTap != null,
      selected: current,
      label: current ? l10n.chapterHereSemantics(label) : label,
      excludeSemantics: true,
      onTap: onTap,
      child: ListTile(
        minTileHeight: 48,
        onTap: onTap,
        selected: current,
        selectedTileColor: theme.colorScheme.primaryContainer,
        contentPadding: EdgeInsetsDirectional.only(
          start: 16.0 + (level - 1) * 16,
          end: 16,
        ),
        leading: Text(numberText, style: theme.textTheme.labelMedium),
        title: Text(
          title,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: bookFont,
            fontSize: 18,
            height: 1.6,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: current
            ? Row(
                children: [
                  Icon(Icons.place, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      l10n.youAreHere,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
