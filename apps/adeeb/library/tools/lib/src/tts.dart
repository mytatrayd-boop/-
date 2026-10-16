/// نص النطق المشكول `tts` (اختياري لكل فقرة، ARCHITECTURE §4.2): يستعمله تقسيم
/// الصوت وحده؛ العرض والبحث والاقتباس على `text`. يولَّد آلياً بـ CATT
/// (`tool/diacritize_tts.py`) ثم يُكتب في إصدار جديد بـ [applyTts].
library;

import 'dart:convert';
import 'dart:io';

import 'book_builder.dart';
import 'catalog.dart';

/// التطويل والحركات (U+064B–U+0652) والألف الخنجرية: ما يُسمح لـ `tts` بإضافته.
final _marks = RegExp('[ـً-ْٰ]');

String stripDiacritics(String s) => s.replaceAll(_marks, '');

/// `tts` صالح إن طابقت حروفه حروف الأصل بعد حذف التشكيل من الطرفين (بايتاً ببايت).
bool ttsMatchesText(String tts, String text) =>
    stripDiacritics(tts) == stripDiacritics(text);

/// نتيجة [applyTts] لكتاب واحد.
class TtsApplyResult {
  TtsApplyResult(this.id, this.fromVersion, this.toVersion, this.withTts, this.file);
  final String id;
  final int fromVersion;

  /// يساوي [fromVersion] إن لم يتغير شيء (لا إصدار جديد).
  final int toVersion;
  final int withTts;
  final File? file;
}

/// يكتب `tts` من [ttsById] في نسخة من أحدث إصدار لكتاب [id] كإصدار N+1
/// (المعرّفات كما هي). `tts` الموجودة سابقاً تُستبدل بما في [ttsById] أو تُحذف.
/// إن لم يتغير شيء لا يُكتب ملف. يرمي إن لم يطابق `tts` نصه.
TtsApplyResult applyTts(Directory libraryRoot, String id, Map<String, String> ttsById) {
  final latest = latestBookFiles(libraryRoot)
      .where((f) => f.uri.pathSegments.last.startsWith('$id.v'))
      .firstOrNull;
  if (latest == null) throw StateError('الكتاب $id غير موجود');
  final book = decodeGzJson(latest.readAsBytesSync());
  final version = book['version']! as int;
  var changed = false;
  var withTts = 0;
  for (final p in paragraphsOf(book)) {
    final text = p['text']! as String;
    final tts = ttsById[p['id']];
    final next = tts == null || tts == text ? null : tts;
    if (next != null && !ttsMatchesText(next, text)) {
      throw StateError('tts لا يطابق نص ${p['id']}');
    }
    if (p['tts'] != next) changed = true;
    if (next == null) {
      p.remove('tts');
    } else {
      p['tts'] = next;
      withTts++;
    }
  }
  if (!changed) return TtsApplyResult(id, version, version, withTts, null);
  book['version'] = version + 1;
  final file = File('${libraryRoot.path}/${bookRelativePath(id, version + 1)}');
  if (file.existsSync()) throw StateError('${file.path} موجود مسبقاً');
  file.writeAsBytesSync(gzipDeterministic(encodeBookJson(book)));
  return TtsApplyResult(id, version, version + 1, withTts, file);
}

/// يدمج ملفات `{paragraph_id: tts}` (أجزاء التشغيل المتوازي).
Map<String, String> loadTtsParts(Iterable<File> parts) => {
      for (final f in parts)
        ...(jsonDecode(f.readAsStringSync()) as Map<String, Object?>).cast<String, String>(),
    };
