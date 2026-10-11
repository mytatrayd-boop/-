import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../library/generated_cover.dart';
import 'reader_providers.dart';

/// بطاقة «تابع القراءة» أعلى المكتبة (DESIGN §7.1): تظهر فقط إذا وُجد آخر
/// موضع في كتاب محمّل. زر «استمع» يأتي مع القراءة الصوتية (الميزة 5).
class ContinueReadingCard extends ConsumerWidget {
  const ContinueReadingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(continueReadingProvider).value;
    if (position == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final source = l10n.breadcrumb(position.bookTitle, position.chapterTitle);
    final firstLine = position.paragraphText
        .split('\n')
        .first
        .replaceAll('\t', ' ');
    void open() => context.push('/read/${position.bookId}');

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GeneratedCover(
                  bookId: position.bookId,
                  title: position.bookTitle,
                  width: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        label: l10n.continueReadingSemantics(source, firstLine),
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.continueReading,
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              source,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              firstLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontFamily: bookFont,
                                fontSize: 18,
                                height: 1.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: open,
                          child: Text(l10n.continueReading),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
