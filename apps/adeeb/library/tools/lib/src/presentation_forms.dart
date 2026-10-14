/// فكّ أشكال العرض العربية إلى حروفها العادية قبل التحويل، ورفض ما لا مقابل له.
///
/// أشكال العرض (U+FB50–U+FDFF وU+FE70–U+FEFF مثل ﻻ وﷲ وﷺ) تُفكّ بجدول NFKC
/// محدود بهذين النطاقين فقط (`presentation_forms_table.dart`، مولَّد بـ
/// `tool/gen_presentation_forms.py`). ما لا تفكيك له في Unicode (﴾ ﴿ ﷽ …)
/// والحروف U+0620 وU+063B–U+063F (حروف لغات أخرى بلا مقابل عربي قياسي) توقف
/// التحويل بخطأ، فلا يُخمَّن بديل لها. المدقق يرفض أي محرف متبقٍّ منها.
library;

import 'wikitext.dart' show RemovalStats, WikitextException;

part 'presentation_forms_table.dart';

/// محارف ممنوعة في ملفات الكتب: أشكال العرض وحروف U+0620 وU+063B–U+063F.
final forbiddenArabicChars = RegExp('[ﭐ-﷿ﹰ-﻾ؠػ-ؿ]');

/// يستبدل أشكال العرض بحروفها العادية ويعدّها في [stats] بمفتاح لكل محرف.
/// يرمي [WikitextException] عند محرف بلا مقابل قياسي.
String foldPresentationForms(String s, RemovalStats stats) {
  if (!forbiddenArabicChars.hasMatch(s)) return s;
  final b = StringBuffer();
  final unmapped = <int>{};
  for (final r in s.runes) {
    final m = _presentationFormMap[r];
    if (m != null) {
      stats.add('شكل عرض مفكوك U+${_hex(r)} ← $m');
      b.write(m);
    } else if (_presentationFormUnmapped.contains(r) || r == 0x0620 || (r >= 0x063B && r <= 0x063F)) {
      unmapped.add(r);
    } else {
      b.writeCharCode(r);
    }
  }
  if (unmapped.isNotEmpty) {
    throw WikitextException(
      'محارف عربية بلا مقابل قياسي (أضف قاعدة replace صريحة في الوصفة بعد المراجعة): '
      '${(unmapped.toList()..sort()).map((c) => 'U+${_hex(c)}').join(', ')}',
    );
  }
  return b.toString();
}

String _hex(int c) => c.toRadixString(16).toUpperCase().padLeft(4, '0');
