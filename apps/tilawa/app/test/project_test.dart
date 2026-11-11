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

  test('سحب قطعة إلى المسار الثاني: تسقط كاملة، صوت فقط، والفيديو يمتد للأطول', () {
    final m = EditorModel()..setAudio(Float32List(sr * 20));
    m.segs = [Segment('أ', 1, 3), Segment('ب', 6, 8)];
    m.liftToLane2(5.0, 9.0, 17.0); // أُسقطت عند الثانية 17
    final o = m.overlays.single;
    expect((o.src0, o.src1, o.at), (5.0, 9.0, 17.0));
    expect(m.muted, [(5.0, 9.0)]); // مكانها في الأول فراغ صامت
    expect(m.cuts, isEmpty);
    expect(m.segs.length, 2); // النص كما هو
    expect(m.audioClips.any((c) => c.$1 < 9 && c.$2 > 5), false); // لا تظهر في الأول
    expect(m.totalDisp, 21.0); // الأطول: 17 + 4
    m.seekDisp(20.5);
    expect((m.playhead, m.tail), (20.0, 0.5));
    m.seekDisp(3);
    expect((m.playhead, m.tail), (3.0, 0.0));
    // أدوات المسار الثاني: تقسيم وتكرار وإرجاع
    m.seekDisp(19);
    m.splitOverlay();
    expect(m.overlays.length, 2);
    expect((m.overlays[0].src1, m.overlays[1].src0, m.overlays[1].at), (7.0, 7.0, 19.0));
    m.duplicateOverlay();
    expect(m.overlays.length, 3);
    m.returnToLane1(m.overlays.first);
    expect(m.muted, isEmpty);
    m.undo();
    expect(m.muted, [(5.0, 9.0)]);
    final l = AudioLayer.fromJson(m.overlays.first.toJson());
    expect((l.src0, l.at, l.vol), (5.0, 17.0, 1.0));
  });
}
