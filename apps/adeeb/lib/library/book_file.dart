/// ملف الكتاب `<id>.v<N>.json.gz` (ARCHITECTURE §4.2): فك الضغط والتحليل
/// والتحقق من القواعد التي يعتمد عليها التطبيق. Dart صافٍ.
library;

import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'catalog.dart';

class BookParagraph {
  const BookParagraph({
    required this.id,
    required this.kind,
    required this.text,
    this.tts,
  });
  final String id;

  /// `prose` أو `verse`.
  final String kind;
  final String text;

  /// نص النطق المشكول (اختياري): للصوت فقط؛ العرض والبحث والاقتباس على [text].
  final String? tts;
}

class BookChapter {
  const BookChapter({
    required this.id,
    required this.title,
    required this.level,
    required this.paragraphs,
  });
  final String id;
  final String title;
  final int level;
  final List<BookParagraph> paragraphs;
}

class BookFile {
  const BookFile({
    required this.id,
    required this.version,
    required this.title,
    required this.author,
    required this.authorDeathHijri,
    required this.sourceName,
    required this.sourceUrl,
    required this.license,
    required this.chapters,
    required this.redirects,
    this.edition,
    this.original,
    this.removed,
  });

  final String id;
  final int version;
  final LocalizedName title;
  final LocalizedName author;
  final int? authorDeathHijri;
  final String sourceName;
  final String sourceUrl;
  final String license;

  /// الطبعة الأصلية والمصدر الأصلي (مثل رقم الشاملة) وما حُذف، اختيارية
  /// (`source.edition`، `source.original`، `removed`) لشاشة المصادر.
  final String? edition;
  final String? original;
  final String? removed;
  final List<BookChapter> chapters;
  final Map<String, String> redirects;

  int get paragraphCount => chapters.fold(0, (n, c) => n + c.paragraphs.length);
}

/// يفك gzip ثم يحلل. يرمي [LibraryFormatException] لأي خلل، أو إن تجاوز
/// النص المفكوك [maxUncompressedBytes] (`uncompressed_bytes` في الفهرس)،
/// ويتوقف الفك فور التجاوز فلا يُستهلك الذاكرة ملف مضغوط خبيث.
BookFile decodeBookGz(List<int> gz, {int? maxUncompressedBytes}) {
  final String text;
  try {
    final out = _LimitedSink(maxUncompressedBytes);
    final input = gzip.decoder.startChunkedConversion(out);
    const chunk = 64 * 1024;
    for (var i = 0; i < gz.length; i += chunk) {
      input.addSlice(
        gz,
        i,
        i + chunk > gz.length ? gz.length : i + chunk,
        false,
      );
    }
    input.close();
    text = utf8.decode(out.bytes.takeBytes());
  } on FormatException catch (e) {
    throw LibraryFormatException(
      'ملف الكتاب ليس gzip/UTF-8 صالحاً: ${e.message}',
    );
  }
  return parseBook(text);
}

class _LimitedSink implements ByteConversionSink {
  _LimitedSink(this.limit);
  final int? limit;
  final bytes = BytesBuilder(copy: true);

  @override
  void add(List<int> chunk) {
    final max = limit;
    if (max != null && bytes.length + chunk.length > max) {
      throw const LibraryFormatException(
        'النص المفكوك أكبر من المعلن في الفهرس',
      );
    }
    bytes.add(chunk);
  }

  @override
  void addSlice(List<int> chunk, int start, int end, bool isLast) =>
      add(chunk.sublist(start, end));

  @override
  void close() {}
}

BookFile parseBook(String text) {
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    throw LibraryFormatException('JSON غير صالح: ${e.message}');
  }
  if (decoded is! Map<String, Object?>) {
    throw const LibraryFormatException('الكتاب ليس كائن JSON');
  }
  final schema = decoded['schema'];
  if (schema is! int) throw const LibraryFormatException('schema مفقود');
  if (schema > supportedSchema) throw UnsupportedSchemaException(schema);

  final id = decoded['id'];
  if (id is! String || !bookIdPattern.hasMatch(id)) {
    throw const LibraryFormatException('معرّف كتاب غير صالح');
  }
  final version = decoded['version'];
  if (version is! int || version < 1) {
    throw const LibraryFormatException('إصدار غير صالح');
  }
  final source = decoded['source'];
  if (source is! Map<String, Object?> ||
      source['name'] is! String ||
      source['url'] is! String) {
    throw const LibraryFormatException('المصدر مفقود');
  }
  final license = decoded['license'];
  if (license is! String) throw const LibraryFormatException('الترخيص مفقود');
  final death = decoded['author_death_hijri'];
  if (death != null && death is! int) {
    throw const LibraryFormatException('سنة الوفاة غير صالحة');
  }

  final chapterPattern = RegExp('^$id-b\\d{3}\$');
  final ids = <String>{};
  final rawChapters = decoded['chapters'];
  if (rawChapters is! List<Object?> || rawChapters.isEmpty) {
    throw const LibraryFormatException('لا أبواب');
  }
  final chapters = <BookChapter>[];
  for (final rc in rawChapters) {
    if (rc is! Map<String, Object?>) {
      throw const LibraryFormatException('باب غير صالح');
    }
    final cid = rc['id'];
    final title = rc['title'];
    final level = rc['level'];
    final paras = rc['paragraphs'];
    if (cid is! String || !chapterPattern.hasMatch(cid) || !ids.add(cid)) {
      throw LibraryFormatException('معرّف باب غير صالح أو مكرر: $cid');
    }
    if (title is! String || title.trim().isEmpty) {
      throw LibraryFormatException('عنوان باب فارغ: $cid');
    }
    if (level is! int || level < 1 || level > 3) {
      throw LibraryFormatException('مستوى باب غير صالح: $cid');
    }
    if (paras is! List<Object?>) {
      throw LibraryFormatException('فقرات الباب مفقودة: $cid');
    }
    final paraPattern = RegExp('^$cid-p\\d{5}\$');
    final paragraphs = <BookParagraph>[];
    for (final rp in paras) {
      if (rp is! Map<String, Object?>) {
        throw LibraryFormatException('فقرة غير صالحة في $cid');
      }
      final pid = rp['id'];
      final ptext = rp['text'];
      final kind = rp['kind'] ?? 'prose';
      if (pid is! String || !paraPattern.hasMatch(pid) || !ids.add(pid)) {
        throw LibraryFormatException('معرّف فقرة غير صالح أو مكرر: $pid');
      }
      if (ptext is! String || ptext.trim().isEmpty) {
        throw LibraryFormatException('فقرة فارغة: $pid');
      }
      if (kind != 'prose' && kind != 'verse') {
        throw LibraryFormatException('نوع فقرة غير معروف: $pid');
      }
      final tts = rp['tts'];
      if (tts != null && tts is! String) {
        throw LibraryFormatException('tts غير صالح: $pid');
      }
      paragraphs.add(
        BookParagraph(
          id: pid,
          kind: kind as String,
          text: ptext,
          tts: _optionalString(tts),
        ),
      );
    }
    chapters.add(
      BookChapter(
        id: cid,
        title: title,
        level: level,
        paragraphs: List.unmodifiable(paragraphs),
      ),
    );
  }

  final redirects = <String, String>{};
  final rawRedirects = decoded['redirects'] ?? const <String, Object?>{};
  if (rawRedirects is! Map<String, Object?>) {
    throw const LibraryFormatException('redirects غير صالح');
  }
  final redirectKey = RegExp('^$id-b\\d{3}-p\\d{5}\$');
  rawRedirects.forEach((from, to) {
    if (!redirectKey.hasMatch(from) || ids.contains(from)) {
      throw LibraryFormatException(
        'مفتاح تحويل غير صالح أو لا يخص الكتاب: $from',
      );
    }
    if (to is! String || !ids.contains(to)) {
      throw LibraryFormatException('تحويل إلى معرّف غير موجود: $from');
    }
    redirects[from] = to;
  });

  return BookFile(
    id: id,
    version: version,
    title: parseLocalizedName(decoded['title'], 'title'),
    author: parseLocalizedName(decoded['author'], 'author'),
    authorDeathHijri: death as int?,
    sourceName: source['name']! as String,
    sourceUrl: source['url']! as String,
    license: license,
    edition: _optionalString(source['edition']),
    original: _optionalString(source['original']),
    removed: _optionalString(decoded['removed']),
    chapters: List.unmodifiable(chapters),
    redirects: Map.unmodifiable(redirects),
  );
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value : null;
