import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import 'reader_book.dart';

/// نص الفقرة مع سطر المصدر: الكتاب والمؤلف والباب (DESIGN §9.3). الشطران
/// يُفصلان بمسافات بدل علامة الجدولة.
String passageWithSource(
  AppLocalizations l10n,
  ReaderBook book,
  ReaderParagraph p,
) => l10n.passageCitation(
  p.text.replaceAll('\t', '    '),
  book.title.ar,
  book.author.ar,
  book.chapters[p.chapterIndex].title,
);

Future<void> copyPassage(String text) =>
    Clipboard.setData(ClipboardData(text: text));

/// قائمة المشاركة في النظام (share_plus، D20). تُستبدل في الاختبارات.
final shareTextProvider =
    Provider<Future<void> Function(String text, String subject)>(
      (ref) => (text, subject) async {
        await SharePlus.instance.share(
          ShareParams(text: text, subject: subject),
        );
      },
    );
