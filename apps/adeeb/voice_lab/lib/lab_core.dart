/// منطق تجربة T0 بلا Flutter: اختيار الفقرات، والمقاطع، وWAV، والقياسات.
library;

import 'dart:typed_data';

import 'package:adeeb/audio/speech_text.dart';

/// حد المقطع للمحرك المدمج (ARCHITECTURE §17.3).
const labChunkMax = 300;

class LabParagraph {
  const LabParagraph({
    required this.bookTitle,
    required this.id,
    required this.number,
    required this.kind,
    required this.text,
  });

  final String bookTitle;
  final String id;

  /// ترتيب الفقرة في الكتاب (من 1).
  final int number;

  /// `prose` أو `verse`.
  final String kind;
  final String text;
}

/// أول [perBook] فقرات من كتاب بصيغة library/books (schema 1). إن لم يكن
/// بينها شعر وفي الكتاب شعر، تُستبدل الأخيرة بأول فقرة شعرية، فتجمع العيّنة
/// النثر والشعر.
List<LabParagraph> selectLabParagraphs(
  Map<String, Object?> book, {
  int perBook = 4,
}) {
  final title = (book['title'] as Map<String, Object?>?)?['ar'] as String? ?? '';
  final all = <LabParagraph>[];
  for (final chapter in (book['chapters'] as List<Object?>? ?? const [])) {
    final paragraphs =
        (chapter as Map<String, Object?>)['paragraphs'] as List<Object?>? ??
        const [];
    for (final p in paragraphs) {
      final m = p as Map<String, Object?>;
      final text = (m['text'] as String? ?? '').trim();
      if (text.isEmpty) continue;
      all.add(
        LabParagraph(
          bookTitle: title,
          id: m['id'] as String? ?? '',
          number: all.length + 1,
          kind: m['kind'] as String? ?? 'prose',
          text: text,
        ),
      );
    }
  }
  final picked = all.take(perBook).toList();
  if (picked.isNotEmpty && !picked.any((p) => p.kind == 'verse')) {
    final verse = all.skip(perBook).where((p) => p.kind == 'verse');
    if (verse.isNotEmpty) picked[picked.length - 1] = verse.first;
  }
  return picked;
}

/// مقاطع النطق بالحد الأقصر للمحرك المدمج.
List<SpeechChunk> labChunks(LabParagraph p) =>
    speechChunks(p.text, p.kind, maxLength: labChunkMax);

/// WAV أحادي 16 بت من عينات [-1، 1].
Uint8List encodeWav(Float32List samples, int sampleRate) {
  final dataBytes = samples.length * 2;
  final b = ByteData(44 + dataBytes);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      b.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  b.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  b.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    b.setInt16(44 + i * 2, v, Endian.little);
  }
  return b.buffer.asUint8List();
}

/// قيمة سطر مثل `VmHWM:  123456 kB` من /proc/self/status بالكيلوبايت.
int? procStatusKb(String status, String key) {
  final m = RegExp('^$key:\\s+(\\d+)\\s+kB', multiLine: true).firstMatch(status);
  return m == null ? null : int.parse(m.group(1)!);
}

/// تجميع القياسات: RTF = زمن التوليد ÷ مدة الصوت المولَّد.
class LabStats {
  double _genAll = 0, _audioAll = 0, _genLast = 0, _audioLast = 0;
  Duration? lastFirstAudio;
  Duration? worstFirstAudio;

  void startParagraph() {
    _genLast = 0;
    _audioLast = 0;
  }

  void addChunk({required Duration generation, required double audioSeconds}) {
    final g = generation.inMicroseconds / 1e6;
    _genLast += g;
    _genAll += g;
    _audioLast += audioSeconds;
    _audioAll += audioSeconds;
  }

  void addFirstAudio(Duration d) {
    lastFirstAudio = d;
    if (worstFirstAudio == null || d > worstFirstAudio!) worstFirstAudio = d;
  }

  double? get rtfLast => _audioLast > 0 ? _genLast / _audioLast : null;
  double? get rtfAll => _audioAll > 0 ? _genAll / _audioAll : null;
}
