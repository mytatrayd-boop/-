import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa_app/editor.dart';
import 'package:tilawa_app/look.dart';
import 'package:tilawa_app/project.dart';
import 'package:tilawa_app/quran.dart';
import 'package:tilawa_app/sync.dart';

void main() {
  test('الشكل يُحفظ ويُسترجع كاملاً عبر JSON', () {
    final a = Look()
      ..fontSize = 77
      ..trans = 'en.sahih'
      ..boxOn = true
      ..boxColor = const Color(0xFF555555)
      ..reciter = 'القارئ'
      ..transFont = 'Amiri'
      ..bgEvery = 12;
    final j = jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>;
    final b = Look()..fromJson(j);
    expect(b.toJson(), a.toJson());
    expect(b.fontSize, 77);
    expect(b.boxColor, const Color(0xFF555555));
  });

  test('الحقول المفقودة تعود للقيم الافتراضية ({} = إعادة الضبط)', () {
    final l = Look()
      ..fontSize = 99
      ..reciter = 'x';
    l.fromJson({});
    expect(l.fontSize, Look().fontSize);
    expect(l.reciter, '');
  });

  test('المقطع يحفظ آيته وسورته، والمشروع القديم بلا سورة يُقرأ', () {
    final g = Segment.fromJson(Segment('نص', 1, 2.5, 5, 70).toJson());
    expect((g.ayah, g.surah, g.end), (5, 70, 2.5));
    final old = Segment.fromJson({'text': 'x', 'start': 0, 'end': 1});
    expect((old.ayah, old.surah), (0, 0));
  });

  test('المقطع الصوتي يُحفظ بمكانه في الخط الزمني', () {
    final c = ClipInfo.fromJson(ClipInfo('clip1.mp3', 'a.mp3', 10.5, 20).toJson());
    expect((c.file, c.start, c.end), ('clip1.mp3', 10.5, 20.0));
  });

  test('ترجمة المقطع المقسوم تقابل كلماته فقط، وحدودها متصلة بلا تكرار', () {
    const ayah = 'قَالَ رَبِّ إِنِّي دَعَوْتُ قَوْمِي لَيْلًا وَنَهَارًا';
    const tr = 'He said, My Lord, indeed I invited my people night and day.';
    final a = ayahRange(ayah, 'قَالَ رَبِّ إِنِّي دَعَوْتُ')!;
    final b = ayahRange(ayah, 'قَوْمِي لَيْلًا وَنَهَارًا ٥')!;
    expect(a.$1, 0);
    expect(b.$2, 1);
    expect(a.$2, closeTo(b.$1, 1e-9));
    final p1 = sliceTranslation(tr, a.$1, a.$2), p2 = sliceTranslation(tr, b.$1, b.$2);
    expect('$p1 $p2', tr);
    expect(p1.isNotEmpty && p2.isNotEmpty, true);
    expect(ayahRange(ayah, 'نص مختلف تماما'), isNull); // معدّل يدوياً: يُعرض كاملاً
    expect(sliceTranslation(tr, 0, 1), tr);
  });

  test('تكرار المقطع يعيد نفس الجزء من الترجمة', () {
    const ayah = 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ';
    final x = ayahRange(ayah, 'رَبِّ الْعَالَمِينَ'), y = ayahRange(ayah, 'رَبِّ الْعَالَمِينَ');
    expect(x, y);
  });

  test('التراجع والإعادة يشملان حالة الشكل المحفوظة مع المقاطع', () {
    var state = 'قبل';
    final m = EditorModel()
      ..extraSnap = (() => state)
      ..extraRestore = ((s) => state = s);
    m.setAudio(Float32List(16000));
    m.checkpoint(extra: 'قبل'); // تعديل شكل: الحالة السابقة تُحفظ صراحةً
    state = 'بعد';
    m.undo();
    expect(state, 'قبل');
    m.redo();
    expect(state, 'بعد');
    m.checkpoint(); // تعديل مقاطع: الحالة الحالية تُلتقط تلقائياً
    state = 'ثالث';
    m.undo();
    expect(state, 'بعد');
  });

  test('نقل قطعة صوت إلى المسار الثاني ونسخها، مع التراجع', () {
    final m = EditorModel()..setAudio(Float32List(sr * 20));
    m.segs = [Segment('أ', 1, 3), Segment('ب', 6, 8)];
    m.audioSel = (5.0, 9.0);
    m.toLane2(move: true);
    expect(m.overlays.single.at, 5.0);
    expect(m.overlays.single.len, 4.0);
    expect(m.cuts, [(5.0, 9.0)]); // النقل يحذفها من الأول ويُغلق مكانها
    expect(m.segs.length, 1);
    m.undo();
    expect(m.overlays, isEmpty);
    expect(m.cuts, isEmpty);
    expect(m.segs.length, 2);
    m.audioSel = (5.0, 9.0);
    m.toLane2(move: false); // النسخ يُبقي المسار الأول كما هو
    expect(m.cuts, isEmpty);
    expect(m.overlays.length, 1);
    final l = AudioLayer.fromJson(m.overlays.single.toJson());
    expect((l.src0, l.src1, l.at, l.vol), (5.0, 9.0, 5.0, 1.0));
  });
}
