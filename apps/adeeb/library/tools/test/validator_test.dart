import 'dart:convert';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

import 'helpers.dart';

List<String> codes(Map<String, Object?> b) => validateBook(b, 't').map((i) => i.code).toList();

Map<String, Object?> para(Map<String, Object?> b, int i) =>
    ((((b['chapters']! as List)[0] as Map)['paragraphs']! as List)[i] as Map).cast<String, Object?>();

void main() {
  test('كتاب سليم بلا أخطاء', () {
    expect(validateBook(validBook(), 't'), isEmpty);
  });

  test('الحقول الإلزامية', () {
    for (final k in ['title', 'author', 'author_death_hijri', 'source', 'license', 'removed']) {
      final b = validBook()..remove(k);
      expect(codes(b), contains('missing_field'), reason: k);
    }
    final b = validBook()..['chapters'] = <Object>[];
    expect(codes(b), contains('missing_field'));
    final s = validBook();
    (s['source']! as Map)['url'] = 'http://insecure';
    expect(codes(s), contains('missing_field'));
  });

  test('المعرّفات المكررة', () {
    final b = validBook();
    para(b, 1)['id'] = 'kalila-b01-p0001';
    expect(codes(b), contains('duplicate_id'));
  });

  test('صيغة المعرّفات وثبات عرضها', () {
    final b = validBook();
    para(b, 0)['id'] = 'kalila-b01-p1';
    expect(codes(b), contains('paragraph_id'));
    final w = validBook();
    para(w, 1)['id'] = 'kalila-b01-p00002';
    expect(codes(w), contains('id_width'));
    final other = validBook();
    para(other, 0)['id'] = 'kalila-b02-p0001';
    expect(codes(other), contains('paragraph_id'));
    expect(codes(validBook()..['id'] = 'Kalila1'), contains('book_id'));
  });

  test('لا فقرات فارغة', () {
    final b = validBook();
    para(b, 0)['text'] = '   ';
    expect(codes(b), contains('empty_text'));
  });

  test('علامات الحواشي وبقايا الترميز', () {
    const bad = {
      'نص [1] تام': 'footnote_bracket_number',
      'نص (٢) تام': 'footnote_paren_number',
      'نص¹ تام': 'footnote_superscript',
      'كلمة١ تام': 'footnote_attached_number',
      'نص * تام': 'footnote_asterisk',
      'نص {{قالب}}': 'wiki_template',
      'نص [[رابط]]': 'wiki_link',
      "نص '''غامق'''": 'wiki_bold_italic',
      'نص <ref>x</ref>': 'html_tag',
      'نص&nbsp;تام': 'html_entity',
      'انظر https://x.org': 'url',
    };
    bad.forEach((text, code) {
      final b = validBook();
      para(b, 0)['text'] = text;
      expect(codes(b), contains(code), reason: text);
    });
  });

  test('محارف التحكم وNFC والمسافات', () {
    final b = validBook();
    para(b, 0)['text'] = 'سطر\nسطر';
    expect(codes(b), contains('control_char'));
    final r = validBook();
    para(r, 0)['text'] = 'نص‏خفي';
    expect(codes(r), contains('control_char'));
    final n = validBook();
    para(n, 0)['text'] = 'بَّ';
    expect(codes(n), contains('nfc'));
    final s = validBook();
    para(s, 0)['text'] = ' نص';
    expect(codes(s), contains('whitespace'));
  });

  test('UTF-8 وBOM', () {
    final ok = utf8.encode(jsonEncode(validBook()));
    expect(validateBookBytes(ok, 't'), isEmpty);
    expect(validateBookBytes([0xEF, 0xBB, 0xBF, ...ok], 't').map((i) => i.code), contains('bom'));
    expect(validateBookBytes([...ok.take(10), 0xC3, 0x28, ...ok.skip(10)], 't').map((i) => i.code), contains('utf8'));
  });

  test('redirects: المصدر غير موجود والوجهة موجودة', () {
    final b = validBook()..['redirects'] = {'kalila-b01-p0009': 'kalila-b01-p0001'};
    expect(validateBook(b, 't'), isEmpty);
    final bad = validBook()..['redirects'] = {'kalila-b01-p0001': 'kalila-b01-p0009'};
    expect(codes(bad), everyElement('redirects'));
  });

  test('باب فارغ بلا أبواب فرعية خطأ', () {
    final b = validBook();
    (b['chapters']! as List).add({'id': 'kalila-b02', 'title': 'فارغ', 'level': 1, 'paragraphs': <Object>[]});
    expect(codes(b), contains('empty_chapter'));
  });
}
