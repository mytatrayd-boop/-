import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:adeeb_voice_lab/lab_core.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _book(List<Map<String, Object?>> paragraphs) => {
  'title': {'ar': 'كتاب'},
  'chapters': [
    {'id': 'x-b001', 'paragraphs': paragraphs},
  ],
};

void main() {
  group('selectLabParagraphs', () {
    test('takes the first four when verse is among them', () {
      final p = selectLabParagraphs(
        _book([
          {'id': 'p1', 'text': 'أ'},
          {'id': 'p2', 'kind': 'verse', 'text': 'ب\tج'},
          {'id': 'p3', 'text': 'د'},
          {'id': 'p4', 'text': 'هـ'},
          {'id': 'p5', 'text': 'و'},
        ]),
      );
      expect(p.map((e) => e.id), ['p1', 'p2', 'p3', 'p4']);
      expect(p[1].kind, 'verse');
      expect(p.first.bookTitle, 'كتاب');
    });

    test('swaps the last one for the first verse when none is picked', () {
      final p = selectLabParagraphs(
        _book([
          for (var i = 1; i <= 6; i++) {'id': 'p$i', 'text': 'نص $i'},
          {'id': 'v', 'kind': 'verse', 'text': 'ب\tج'},
        ]),
      );
      expect(p.map((e) => e.id), ['p1', 'p2', 'p3', 'v']);
      expect(p.last.number, 7);
    });

    test('skips empty paragraphs', () {
      final p = selectLabParagraphs(
        _book([
          {'id': 'e', 'text': '  '},
          {'id': 'p1', 'text': 'أ'},
        ]),
      );
      expect(p.map((e) => e.id), ['p1']);
    });

    test('the five real books give 20 paragraphs with prose and verse', () {
      final dir = Directory('../library/books');
      final all = <LabParagraph>[];
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.json.gz')) continue;
        final json = jsonDecode(utf8.decode(gzip.decode(f.readAsBytesSync())));
        all.addAll(selectLabParagraphs(json as Map<String, Object?>));
      }
      expect(all, hasLength(20));
      expect(all.where((p) => p.kind == 'verse'), isNotEmpty);
      expect(all.where((p) => p.kind == 'prose'), isNotEmpty);
    });
  });

  test('labChunks keeps chunks at or below 300 characters', () {
    final long = List.filled(80, 'كلمة طويلة.').join(' ');
    final chunks = labChunks(
      LabParagraph(bookTitle: '', id: '', number: 1, kind: 'prose', text: long),
    );
    expect(chunks.length, greaterThan(1));
    expect(chunks.every((c) => c.text.length <= labChunkMax), isTrue);
  });

  test('encodeWav writes a 16-bit mono PCM header and clamps samples', () {
    final wav = encodeWav(Float32List.fromList([0, 1, -1, 2]), 16000);
    final b = ByteData.sublistView(wav);
    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
    expect(b.getUint32(24, Endian.little), 16000);
    expect(b.getUint16(34, Endian.little), 16);
    expect(b.getUint32(40, Endian.little), 8);
    expect(wav.length, 52);
    expect(b.getInt16(46, Endian.little), 32767);
    expect(b.getInt16(48, Endian.little), -32767);
    expect(b.getInt16(50, Endian.little), 32767);
  });

  test('procStatusKb reads VmHWM and VmRSS', () {
    const status = 'Name:\tapp\nVmHWM:\t  204800 kB\nVmRSS:\t  102400 kB\n';
    expect(procStatusKb(status, 'VmHWM'), 204800);
    expect(procStatusKb(status, 'VmRSS'), 102400);
    expect(procStatusKb(status, 'VmSwap'), isNull);
  });

  test('LabStats computes RTF per paragraph and overall', () {
    final s = LabStats()
      ..startParagraph()
      ..addChunk(generation: const Duration(seconds: 1), audioSeconds: 4)
      ..startParagraph()
      ..addChunk(generation: const Duration(seconds: 3), audioSeconds: 4);
    expect(s.rtfLast, closeTo(0.75, 1e-9));
    expect(s.rtfAll, closeTo(0.5, 1e-9));
    s
      ..addFirstAudio(const Duration(milliseconds: 900))
      ..addFirstAudio(const Duration(milliseconds: 400));
    expect(s.lastFirstAudio, const Duration(milliseconds: 400));
    expect(s.worstFirstAudio, const Duration(milliseconds: 900));
  });
}
