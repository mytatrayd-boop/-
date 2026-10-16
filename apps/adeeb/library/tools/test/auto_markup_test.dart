// وسوم JK وغيرها في الوضع الآلي (auto_markup.dart): أبيات «% … % … %» و«( … % … )»، والفاصل «|».
import 'dart:convert';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

import 'auto_convert_test.dart' show conv, bookOf, goodBook;

List<String> norm(List<String> lines, [RemovalStats? st]) => normalizeAutoMarkup(lines, st ?? RemovalStats());

List<Map<String, Object?>> parasOf(Map<String, Object?> b) => [
      for (final c in (b['chapters']! as List).cast<Map<String, Object?>>())
        ...(c['paragraphs']! as List).cast<Map<String, Object?>>(),
    ];

void main() {
  group('أبيات JK «% صدر % عجز %»', () {
    test('الصيغ المختلفة ← «صدر %~% عجز»، ورقم البيت يُحذف وتبقى العلامة', () {
      final st = RemovalStats();
      expect(
        norm([
          '# % لخولة أطلال ببرقة ثهمد ، % تلوح كباقي الوشم في ظاهر اليد % 3',
          '# % وقوفا بها صحبي علي مطيهم ، % يقولون : لا تهلك أسى وتجلد % % 4',
          '# % يشق حباب الماء حيزومها بها % % كما قسم الترب المفايل باليد % 7',
          '# % أخي ثقة لا ينثني عن ضريبة % % إذا قيل مهلا قال حاجزه قدي',
          '# % وأنك فيض ذو سجال غزيرة % ينال الأعادي نفعها والأقارب % PageV01P004 21',
          '# % أنا أبو المقدام عقا فطا % %',
        ], st),
        [
          '# لخولة أطلال ببرقة ثهمد ، %~% تلوح كباقي الوشم في ظاهر اليد',
          '# وقوفا بها صحبي علي مطيهم ، %~% يقولون : لا تهلك أسى وتجلد',
          '# يشق حباب الماء حيزومها بها %~% كما قسم الترب المفايل باليد',
          '# أخي ثقة لا ينثني عن ضريبة %~% إذا قيل مهلا قال حاجزه قدي',
          '# وأنك فيض ذو سجال غزيرة %~% ينال الأعادي نفعها والأقارب PageV01P004',
          '# أنا أبو المقدام عقا فطا %~%',
        ],
      );
      expect(st.counts[statJkNumber], 4);
      expect(st.counts[statJkVerse], 6);
    });

    test('بيت ممتد على سطر ~~ يوصل؛ و«~~PageV… 12» بعد البيت يفقد رقمه', () {
      expect(
        norm([
          '# % ووجه كأن الشمس ألقت رداءها % % عليه نقي اللون',
          '~~لم يتخدد % 12',
          '# % وإني لأمضي الهم عند احتضاره % بعوجاء مرقال تروح وتغتدي %',
          '~~PageV01P001 13',
          '# % بيت آخر في القصيدة % وعجزه هنا %',
          '~~% PageV01P002 14',
        ]),
        [
          '# ووجه كأن الشمس ألقت رداءها %~% عليه نقي اللون لم يتخدد',
          '# وإني لأمضي الهم عند احتضاره %~% بعوجاء مرقال تروح وتغتدي',
          '~~PageV01P001',
          '# بيت آخر في القصيدة %~% وعجزه هنا',
          '~~PageV01P002',
        ],
      );
    });

    test('نثر بعد البيت في السطر نفسه فقرة جديدة', () {
      expect(norm(['# % كأن ابان في افانين ودقه % % كبير أناس في بجاد مزمل % % وإن كانت']), [
        '# كأن ابان في افانين ودقه %~% كبير أناس في بجاد مزمل',
        '# وإن كانت',
      ]);
    });
  });

  group('أبيات بين قوسين «( صدر % عجز )»', () {
    test('وحده أو برقمه، وداخل سطر نثر', () {
      expect(norm(['# 3 ( أجادت وبل مد جنة فدرت % عليهم صوب سارية درور )']), [
        '# أجادت وبل مد جنة فدرت %~% عليهم صوب سارية درور',
      ]);
      expect(norm(['~~ومثله قول الشاعر ( يا ساريا بالليل لا تخش ضلة % سعيد بن سلم ضوء كل بلاد ) وقال آخر']), [
        '~~ومثله قول الشاعر',
        '# يا ساريا بالليل لا تخش ضلة %~% سعيد بن سلم ضوء كل بلاد',
        '# وقال آخر',
      ]);
      expect(norm(['# ( هما خطتا إما إسار ومنة % )']), ['# هما خطتا إما إسار ومنة %~%']);
    });

    test('سطر %~% المعتاد وسطر بلا «%» لا يُمسّان', () {
      const lines = ['# صدر البيت %~% عجز البيت', '# نثر (فيه قوس) بلا شعر', '~~تتمة'];
      expect(norm(lines), lines);
    });
  });

  test('الفاصل «|» ← فقرة جديدة، ورقم الطبعة بعده يُحذف', () {
    final st = RemovalStats();
    expect(norm(['# وعق والده يعقه عقا | وماء عق : شديد المرارة | 5800', '~~ومات رحمه الله | 12 وقال غيره'], st), [
      '# وعق والده يعقه عقا',
      '# وماء عق : شديد المرارة',
      '~~ومات رحمه الله',
      '# وقال غيره',
    ]);
    expect(st.counts['فاصل «|» (JK) ← فقرة جديدة'], 3);
  });

  test('كتاب ديوان JK كامل: فقرات شعر بشطرين، بلا وسم مجهول، ويُقبل', () {
    final b = StringBuffer('######OpenITI#\n\n#META# 020.BookTITLE\t:: ديوان\n#META#Header#End#\n');
    var n = 0;
    for (var poem = 0; poem < 8; poem++) {
      b.writeln('# البحر : طويل 1');
      for (var v = 0; v < 15; v++) {
        n++;
        final num = '${v + 2}';
        b.writeln('# % صدر البيت ${_w(n)} من القصيدة ${_w(poem)} والشاعر يقول % % عجز البيت ${_w(n + 7)} في '
            'وصف ${_w(n * 3)} وذكر ${_w(n * 5)} % $num');
        if (v % 6 == 5) b.writeln('~~PageV01P${n.toString().padLeft(3, '0')} ${v + 3}');
      }
    }
    final o = conv(b.toString());
    expect(o.unknown, isEmpty);
    expect(o.metrics['unknown_per_10k'], 0);
    expect(o.decision, GateDecision.accept, reason: o.reasons.join('; '));
    final paras = parasOf(bookOf(o));
    final verses = paras.where((p) => p['kind'] == 'verse').toList();
    expect(verses, hasLength(8));
    final lines = (verses.first['text']! as String).split('\n');
    expect(lines, hasLength(15));
    expect(lines.first.split('\t'), hasLength(2));
    expect(lines.first, isNot(contains('%')));
    expect(verses.every((p) => !RegExp('[0-9]').hasMatch(p['text']! as String)), isTrue);
    expect(paras.first['text'], 'البحر : طويل');
  });

  test('تقرير الدفعة يحصي أنواع الوسم المجهول', () {
    final o = conv(goodBook().replaceFirst('# قال', '# ^ قال').replaceFirst('# قال', '# ^ ^ قال'));
    expect(o.unknown['رمز وسم متبقٍّ «^» (حُذف)'], 3);
    final r = BatchReport([
      BookReport('a', 'أ', o.decision, o.reasons, o.metrics, unknown: o.unknown),
      BookReport('b', 'ب', o.decision, o.reasons, o.metrics, unknown: o.unknown),
    ]);
    expect(r.unknownTally().first, ('رمز وسم متبقٍّ «^» (حُذف)', 6, 2));
    expect(jsonDecode(r.toJson())['unknown'], isNotEmpty);
    expect(r.toMarkdown(), contains('«^» (حُذف): 6 في 2'));
  });
}

const _ws = ['الغيث', 'الظعائن', 'الأطلال', 'الناقة', 'السيف', 'الخيل', 'الرماح', 'الكرم', 'الحي', 'الليل', 'البرق'];
String _w(int i) => '${_ws[i % _ws.length]} ${_ws[(i ~/ _ws.length) % _ws.length]}';
