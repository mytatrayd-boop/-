import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tilawa_app/look.dart';
import 'package:tilawa_app/project.dart';
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
}
