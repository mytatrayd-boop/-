// الاختيار (6.1) والتحويل الآلي والبوابات والسجل وredirects (6.2). النصوص اصطناعية للاختبار،
// وملف TSV صفوف حقيقية قليلة من بيانات OpenITI 2025.1.9.
import 'dart:convert';
import 'dart:io';

import 'package:adeeb_library_tools/adeeb_library_tools.dart';
import 'package:test/test.dart';

const _header = '######OpenITI#\n\n#META# 020.BookTITLE\t:: كتاب\n#META# bkid: 1\n#META#Header#End#\n';

final scope = Scope.load(File('scope.yaml'));

const _words = [
  'الخليل', 'الأصمعي', 'العتبي', 'المدائني', 'الرياشي', 'الزبير', 'أبو', 'عبيدة', 'الكلبي', 'الهيثم',
  'البصرة', 'الكوفة', 'بغداد', 'الحجاز', 'اليمامة', 'الشام', 'مصر', 'اليمن', 'خراسان', 'فارس',
];

/// فقرة نثر فريدة بنحو 25 كلمة (لا أرقام ولا رموز).
String prose(int i) {
  final w = [for (var k = 0; k < 6; k++) _words[(i ~/ (k + 1) + k * 7) % _words.length]];
  return 'قال ${w[0]} حدثني ${w[1]} عن ${w[2]} أنه رأى رجلا من أهل ${w[3]} يحدث قوما من أهل ${w[4]} '
      'بخبر طويل عن ${w[5]} في الخبر ${_ord(i)} فعجبوا منه وكتبوه عنه.';
}

String _ord(int i) {
  const units = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر'];
  const tens = ['', 'بعد العشرة', 'بعد العشرين', 'بعد الثلاثين', 'بعد الأربعين', 'بعد الخمسين', 'بعد الستين',
    'بعد السبعين', 'بعد الثمانين', 'بعد التسعين'];
  return '${units[i % 10]} ${tens[(i ~/ 10) % 10]} من المئة ${units[(i ~/ 100) % 10]}';
}

/// كتاب سليم: [chapters] أبواب، في كل منها [per] فقرة، مع علامات صفحات ومعالم.
String goodBook({int chapters = 4, int per = 20, int start = 0}) {
  final b = StringBuffer(_header);
  var i = start;
  for (var c = 0; c < chapters; c++) {
    b.writeln('### | باب ${_ord(c)}');
    for (var p = 0; p < per; p++) {
      b.writeln('# ${prose(i++)} ms$i');
      if (p % 5 == 4) b.writeln('# PageV01P${(i ~/ 5).toString().padLeft(3, '0')}');
    }
  }
  return b.toString();
}

AutoMeta meta([String uri = '0300Test.Kitab.Test0001-ara1']) => AutoMeta(
      bookUri: bookUriOf(uri),
      versionUri: uri,
      titleAr: 'كتاب الاختبار',
      titleEn: 'Test',
      authorAr: 'مؤلف',
      authorEn: 'Author',
      deathHijri: 300,
      localPath: 'data/0300Test/0300Test.Kitab/$uri',
    );

AutoOutcome conv(String text, {String id = 'o00001', int version = 1, Map<String, Object?>? previous}) =>
    autoConvert(
      meta: meta(),
      sourceBytes: utf8.encode(text),
      scope: scope,
      id: id,
      retrieved: '2026-10-16',
      version: version,
      previous: previous,
    );

Map<String, Object?> bookOf(AutoOutcome o) => jsonDecode(utf8.decode(o.json!)) as Map<String, Object?>;

List<String> idsOf(Map<String, Object?> b) => [
      for (final c in (b['chapters']! as List).cast<Map<String, Object?>>())
        for (final p in (c['paragraphs']! as List).cast<Map<String, Object?>>()) p['id']! as String,
    ];

void main() {
  group('scope.yaml والاختيار (6.1)', () {
    final rows = parseMetadataTsv(File('test/fixtures/openiti_metadata_sample.tsv').readAsStringSync());
    final registry = Registry.load(File('../registry.tsv'));
    final sel = selectBooks(scope, rows, registry);
    String decisionOf(String uri) {
      final s = sel.firstWhere((s) => s.row.versionUri == uri);
      return '${s.decision.name}|${s.reason.split(':').first}';
    }

    test('scope.yaml يُقرأ ويثبّت إصدار 2025.1.9', () {
      expect(scope.releaseCommit, 'cfc4157a3cf2054c0888f133970a4eaa3e22e58c');
      expect(scope.maxDeathHijri, 1300);
      expect(scope.status, 'pri');
      expect(scope.rawUrl('data/a b/c'),
          'https://raw.githubusercontent.com/OpenITI/RELEASE/cfc4157a3cf2054c0888f133970a4eaa3e22e58c/data/a%20b/c');
    });

    test('الكتب الخمسة تُكتشف ومعلَّمة «موجودة» بمعرّفاتها', () {
      final ex = sel.where((s) => s.decision == Decision.existing).map((s) => s.existingId).toSet();
      expect(ex, {'kalila', 'bayan', 'uyun', 'kamil', 'adab'});
    });

    test('أسباب الاستبعاد والإدراج', () {
      expect(decisionOf('0001AwsIbnHajar.Diwan.JK007502-ara1'), 'include|tags');
      expect(decisionOf('0001AbuTalibCabdManaf.Diwan.ShamAY0037822-ara1'), 'exclude|status');
      expect(decisionOf('0001Quran.Mushaf.QuranAnalysis001-ara1'), 'exclude|scope');
      expect(decisionOf('0110HasanBasri.FadailMakka.Shamela0005722-ara1'), 'exclude|mixed');
      expect(decisionOf('0200AbuGhanimKhurasani.MudawwanaKubra.Kraken2108092202141-ara1'), 'exclude|ocr');
      expect(decisionOf('0313IbnZakariyyaRazi.KhawassAshya.AOCP20251117001-per1'), 'exclude|language');
      expect(decisionOf('1301AdibIshaq.Andromak.Hindawi094742841-ara1'), 'exclude|date');
    });

    test('تسريبات الدفعة الأولى مستبعدة: رجال، حديث، أذكار، فقه؛ وكتب اللغة والتاريخ باقية', () {
      // رجال (نقد الرواة) بوسوم التراجم وحدها: يكشفها العنوان.
      expect(decisionOf('0385Daraqutni.TacliqatCalaMajruhin.Shamela0010843-ara1'), 'exclude|title');
      expect(decisionOf('0744IbnCabdHadi.TabaqatCulama.Sham19Y0001994-ara1'), 'exclude|title');
      expect(decisionOf('0748Dhahabi.MucjamShuyukh.Shamela0012531-ara1'), 'exclude|title');
      // فقه بوسم «الغريب والمعاجم ولغة الفقه».
      expect(decisionOf('0909IbnMabrid.DurrNaqi.Sham19Y0131003-ara1'), 'exclude|title');
      // صلوات على النبي.
      expect(decisionOf('0902Sakhawi.QawlBadic.Shamela0001391-ara1'), 'exclude|title');
      // وسم الحديث الموضوعي _HADITH مع وسم تراجم ← مختلط.
      expect(decisionOf('0303Nasai.DhikrMudallisin.Shamela0025868-ara1'), 'exclude|mixed');
      // «فقه اللغة» ليس فقهاً؛ و«فضائل مصر» تاريخ محسوم بالاسم.
      expect(decisionOf('0395IbnFarisQazwini.Sahibi.JK010092-ara1'), 'include|tags');
      expect(decisionOf('0350MuhammadKindi.FadailMisr.Shamela0000405-ara1'), 'include|name');
    });

    test('exclude_titles: كل فئة تطابق عنوانها ولا تطابق عناوين الأدب', () {
      String? cat(String title) =>
          scope.excludeTitles.entries.where((e) => e.value.hasMatch(title)).map((e) => e.key).firstOrNull;
      expect(cat('ديوان الضعفاء والمتروكين'), 'rijal');
      expect(cat('المسند'), 'hadith');
      expect(cat('الأربعين في الحديث'), 'hadith');
      expect(cat('دلائل الأذكار'), 'devotional');
      expect(cat('مناقب الإمام أحمد'), 'devotional');
      expect(cat('مختصر الفقه'), 'fiqh');
      expect(cat('تسمية شيوخ أبي داود'), 'rijal');
      expect(cat('المعلم بشيوخ البخاري ومسلم'), 'rijal');
      expect(cat('أسباب النزول'), 'tafsir');
      for (final t in ['الصاحبي في فقه اللغة', 'المناقب المزيدية', 'غريب الحديث', 'البيان والتبيين', 'تفسير أبيات المعاني']) {
        expect(cat(t), isNull, reason: t);
      }
    });

    test('المختلط يُحسم بالاسم، والنسخة تُستبدل بالاسم', () {
      final y = File('scope.yaml').readAsStringSync();
      final s2 = Scope.parse(y
          .replaceFirst('include_books:\n', "include_books:\n  0110HasanBasri.FadailMakka: 'اختبار'\n")
          .replaceFirst('version_overrides: {}',
              'version_overrides:\n  0001AbuTalibCabdManaf.Diwan: 0001AbuTalibCabdManaf.Diwan.ShamAY0037822-ara1'));
      final sel2 = selectBooks(s2, rows, registry);
      String d(String uri) => sel2.firstWhere((s) => s.row.versionUri == uri).reason.split(':').first;
      expect(d('0110HasanBasri.FadailMakka.Shamela0005722-ara1'), 'name');
      expect(d('0001AbuTalibCabdManaf.Diwan.ShamAY0037822-ara1'), 'tags');
      expect(d('0001AbuTalibCabdManaf.Diwan.JK007501-ara1'), 'version');
    });

    test('حتمي: الترتيب نفسه والملف نفسه لأي ترتيب للمدخلات', () {
      final a = selectionToTsv(sel);
      final b = selectionToTsv(selectBooks(scope, rows.reversed.toList(), registry));
      expect(a, b);
      final back = parseSelectionTsv(a);
      expect(back.length, rows.length);
      expect(back.first.versionUri, sel.first.row.versionUri);
    });

    test('pickBatch: أول N أو موزّعة بالتساوي', () {
      final list = [for (var i = 0; i < 10; i++) SelectedBook({'decision': 'include', 'version_uri': 'v$i'})];
      expect(pickBatch(list, 3).map((s) => s.versionUri), ['v0', 'v1', 'v2']);
      expect(pickBatch(list, 3, spread: true).map((s) => s.versionUri), ['v0', 'v3', 'v6']);
    });
  });

  group('registry.tsv', () {
    test('سجل المكتبة: الخمسة بمعرّفاتها', () {
      final r = Registry.load(File('../registry.tsv'));
      expect(r.idOf('0139IbnMuqaffac.KalilaWaDimna'), 'kalila');
      expect(r.idOf('0450AbuHasanMawardi.AdabDunyaWaDin'), 'adab');
      expect(r.nextId(), 'o00001');
    });

    test('إلحاقي: معرّف جديد بالترتيب، وثابت عند إعادة الطلب، والملف القديم بادئة للجديد', () {
      final dir = Directory.systemTemp.createTempSync('reg');
      final f = File('${dir.path}/registry.tsv')..writeAsStringSync(File('../registry.tsv').readAsStringSync());
      final before = f.readAsStringSync();
      final r = Registry.load(f);
      expect(r.assign('0300A.B', '0300A.B.X-ara1'), 'o00001');
      expect(r.assign('0400C.D', '0400C.D.X-ara1'), 'o00002');
      expect(r.assign('0300A.B', '0300A.B.Y-ara1'), 'o00001');
      final after = f.readAsStringSync();
      expect(after.startsWith(before), isTrue);
      final again = Registry.load(f);
      expect(again.idOf('0400C.D'), 'o00002');
      expect(again.nextId(), 'o00003');
      dir.deleteSync(recursive: true);
    });

    test('معرّف أو كتاب مكرر خطأ', () {
      expect(() => Registry.parse('$registryHeader\na.b\to00001\t1\ta.b.c\nc.d\to00001\t1\tc.d.e\n'),
          throwsFormatException);
      expect(() => Registry.parse('$registryHeader\na.b\to00001\t1\ta.b.c\na.b\to00002\t1\ta.b.e\n'),
          throwsFormatException);
    });
  });

  group('التحويل الآلي والبوابات (6.2)', () {
    test('كتاب سليم يُقبل، بمعرّفات o00001 وصفحات، والمدقق راضٍ', () {
      final o = conv(goodBook());
      expect(o.decision, GateDecision.accept, reason: o.reasons.join('; '));
      final b = bookOf(o);
      expect(b['id'], 'o00001');
      expect(idsOf(b).first, 'o00001-b001-p00001');
      expect(b.containsKey('structure'), isFalse);
      expect((b['source']! as Map)['openiti'], containsPair('commit', scope.releaseCommit));
      expect(validateBookBytes(o.json!, 'x', autoIds: true).where((i) => !i.warning), isEmpty);
    });

    test('حتمي بايتاً ببايت', () {
      final a = conv(goodBook());
      final b = conv(goodBook());
      expect(a.json, b.json);
      expect(gzipDeterministic(a.json!), gzipDeterministic(b.json!));
    });

    test('الوسم المجهول لا يوقف التحويل بل يُعدّ ويدخل البوابة', () {
      final t = goodBook().replaceFirst('# قال', '# <<قال>> ^^ ').replaceFirst('### | باب', '### |FOO| باب');
      final o = conv(t);
      expect(o.result, isNotNull);
      expect(o.result!.stats.counts.keys.where((k) => k.startsWith(autoUnknownPrefix)), isNotEmpty);
      expect(o.metrics['unknown_per_10k'], greaterThan(0));
    });

    test('فاسد: حواشٍ متبقية ← رفض', () {
      final t = goodBook().replaceAllMapped(RegExp(r'فعجبوا منه'), (m) => 'فعجبوا (12) منه) 3 وكتبوه (45)');
      final o = conv(t);
      expect(o.decision, GateDecision.reject);
      expect(o.reasons.join(), contains('footnote_per_10k'));
    });

    test('فاسد: OCR (رموز ومحارف مجهولة) ← رفض', () {
      final t = goodBook().replaceAllMapped(RegExp(r' عن '), (m) => ' ع|ن ~ %@ ');
      final o = conv(t);
      expect(o.decision, GateDecision.reject);
      expect(o.reasons.join(), contains('unknown_per_10k'));
    });

    test('فاسد: لاتيني ← رفض', () {
      final t = goodBook().replaceAll(' بخبر ', ' Lorem ipsum dolor sit amet ');
      final o = conv(t);
      expect(o.decision, GateDecision.reject);
      expect(o.reasons.join(), contains('latin_ratio'));
    });

    test('فاسد: بلا فقرات (فقرة واحدة > 20 ألف حرف) ← رفض', () {
      final b = StringBuffer('$_header### | باب\n# ');
      for (var i = 0; i < 300; i++) {
        b.write('${prose(i)} ');
      }
      final o = conv(b.toString());
      expect(o.decision, GateDecision.reject);
      expect(o.reasons.join(), contains('max_paragraph_chars'));
    });

    test('فاسد: قصير (< 1000 كلمة) أو ليس mARkdown ← رفض بسببه', () {
      expect(conv(goodBook(chapters: 1, per: 5)).reasons.join(), contains('words'));
      final o = conv('# نص بلا ترويسة\n');
      expect(o.decision, GateDecision.reject);
      expect(o.reasons.single, startsWith('convert:'));
    });

    test('فقرات مكررة > 3% ← رفض', () {
      final t = '${goodBook()}${'# ${prose(3)}\n' * 5}';
      expect(conv(t).reasons.join(), contains('duplicate_ratio'));
    });

    test('أثر مقدمة محقق في أول النص ← مراجعة', () {
      final t = goodBook().replaceFirst('### | باب الأول', '### | باب الأول\n# تحقيق: فلان بن فلان الطبعة الثانية');
      final o = conv(t);
      expect(o.decision, GateDecision.review);
      expect(o.reasons.join(), contains('editor_intro'));
    });

    test('كشف البنية: بلا عناوين ← الجزء/القسم مولّدة و structure: generated', () {
      final b = StringBuffer(_header);
      for (var i = 0; i < 400; i++) {
        b.writeln('# ${prose(i)}');
        b.writeln('# PageV${i < 250 ? '01' : '02'}P${(i + 1).toString().padLeft(3, '0')}');
      }
      final o = conv(b.toString());
      expect(o.generated, isTrue);
      final book = bookOf(o);
      expect(book['structure'], 'generated');
      final toc = [for (final c in (book['chapters']! as List).cast<Map<String, Object?>>()) '${c['level']}:${c['title']}'];
      expect(toc, ['1:الجزء ١', '2:القسم ١', '2:القسم ٢', '1:الجزء ٢']);
      expect(o.decision, isNot(GateDecision.reject), reason: o.reasons.join('; '));
    });

    test('كتاب بمجلد واحد بلا عناوين يبدأ بـ«القسم ١»', () {
      final b = StringBuffer(_header);
      for (var i = 0; i < 160; i++) {
        b.writeln('# ${prose(i)}');
      }
      final toc = [for (final c in conv(b.toString()).result!.chapters) c['title']];
      expect(toc, ['القسم ١', 'القسم ٢']);
    });
  });

  group('redirects الآلية', () {
    String drop(String src, int i) => src.replaceFirst('# ${prose(i)} ms${i + 1}\n', '');

    test('إصدار 2 مصطنع: المطابقة بالنص، والمعدّلة بأقرب فقرة في الباب، والمدقق لا يجد معرّفاً مفقوداً', () {
      final v1 = bookOf(conv(goodBook()));
      // الإصدار 2: حذف فقرة من البابين الأول والثاني، وتعديل آخر فقرة في الثاني، وحذف الباب الرابع.
      final src2 = drop(drop(goodBook(chapters: 3), 5), 25).replaceFirst(prose(39), '${prose(39)} وزاد فيه كلمة');
      final o2 = conv(src2, version: 2, previous: v1);
      final v2 = bookOf(o2);
      final red = (v2['redirects']! as Map).cast<String, String>();
      final ids2 = idsOf(v2).toSet();
      // آخر فقرة في الباب الأول اختفى معرّفها ونصها صار في الفقرة 19.
      expect(red['o00001-b001-p00020'], 'o00001-b001-p00019');
      // آخر فقرة في الثاني عُدّل نصها ← أقرب فقرة في الباب نفسه.
      expect(red['o00001-b002-p00020'], 'o00001-b002-p00019');
      // المعرّفات الموجودة لا تُحوَّل (المدقق يمنع تحويل معرّف موجود).
      expect(red.keys.where(ids2.contains), isEmpty);
      // الباب الرابع المحذوف ← فقرة موجودة.
      expect(ids2.contains(red['o00001-b004-p00001']), isTrue);
      for (final id in idsOf(v1)) {
        expect(ids2.contains(id) || red.containsKey(id), isTrue, reason: id);
      }
      expect(red.values.every(ids2.contains), isTrue);
      expect(validateBookBytes(o2.json!, 'x', autoIds: true, expectedVersion: 2).where((i) => !i.warning), isEmpty);
    });

    test('تحويلات الإصدار السابق تُحمل إلى وجهتها الجديدة', () {
      final v1 = bookOf(conv(goodBook()));
      v1['redirects'] = {'o00001-b009-p00001': 'o00001-b004-p00001', 'o00001-b009-p00002': 'o00001-b001-p00001'};
      final red = autoRedirects(v1, bookOf(conv(goodBook(chapters: 3), version: 2)));
      expect(red['o00001-b009-p00001'], red['o00001-b004-p00001']);
      expect(red['o00001-b009-p00002'], 'o00001-b001-p00001');
    });
  });

  group('دفعة convert --auto', () {
    test('تقرير بالقبول/المراجعة/الرفض وأسبابها، وسجل ملحَق، ومسار مقسّم، وإصدار 2 عند تغيّر المصدر', () {
      final dir = Directory.systemTemp.createTempSync('batch');
      final src = Directory('${dir.path}/src')..createSync();
      final out = Directory('${dir.path}/out');
      final reg = File('${dir.path}/registry.tsv')..writeAsStringSync(File('../registry.tsv').readAsStringSync());
      String row(String uri) => [
            'include', 'tags: x', uri, bookUriOf(uri), '', '300', '1000', 'كتاب', 'مؤلف', 'Kitab', 'Author', 'data/$uri',
          ].join('\t');
      final selection = parseSelectionTsv([
        selectionColumns.join('\t'),
        row('0300A.Good.X-ara1'),
        row('0300B.Bad.X-ara1'),
        row('0300C.Missing.X-ara1'),
        row('0300D.Review.X-ara1'),
        'exclude\tmixed: x\t0300E.Out.X-ara1\t0300E.Out\t\t300\t1\tt\ta\tt\ta\tp',
      ].join('\n'));
      File('${src.path}/0300A.Good.X-ara1').writeAsStringSync(goodBook());
      File('${src.path}/0300B.Bad.X-ara1').writeAsStringSync(goodBook(chapters: 1, per: 3));
      File('${src.path}/0300D.Review.X-ara1')
          .writeAsStringSync(goodBook(start: 500).replaceFirst('### | باب الأول', '### | باب الأول\n# حققه فلان'));
      BatchReport run() => runAutoBatch(
            selection: selection,
            sourcesDir: src,
            outDir: out,
            scope: scope,
            registry: Registry.load(reg),
            date: '2026-10-16',
          );
      final r = run();
      expect([r.count(GateDecision.accept), r.count(GateDecision.review), r.count(GateDecision.reject)], [1, 1, 2]);
      expect(r.reasonCounts(GateDecision.reject), {'words': 1, 'fetch:': 1});
      final j = jsonDecode(r.toJson()) as Map<String, Object?>;
      expect(j['accept'], 1);
      expect(r.toMarkdown(), contains('| reject |'));
      expect(Registry.load(reg).idOf('0300A.Good'), 'o00001');
      expect(Registry.load(reg).idOf('0300D.Review'), 'o00002');
      expect(Registry.load(reg).idOf('0300B.Bad'), isNull);
      final f1 = File('${out.path}/books/01/o00001/o00001.v1.json.gz');
      expect(f1.existsSync(), isTrue);
      final bytes = f1.readAsBytesSync();

      // التشغيل مرة ثانية بالمصدر نفسه: لا إصدار جديد ولا تغيير ولا معرّف جديد.
      final r2 = run();
      expect(r2.books.first.version, 1);
      expect(f1.readAsBytesSync(), bytes);
      expect(Registry.load(reg).entries.length, 7);

      // مصدر معدّل: إصدار 2 بـ redirects والمعرّف نفسه.
      File('${src.path}/0300A.Good.X-ara1').writeAsStringSync(goodBook(chapters: 3));
      final r3 = run();
      expect(r3.books.first.version, 2);
      final v2 = jsonDecode(utf8.decode(gzip.decode(File('${out.path}/books/01/o00001/o00001.v2.json.gz').readAsBytesSync())))
          as Map<String, Object?>;
      expect((v2['redirects']! as Map).keys, contains('o00001-b004-p00001'));
      dir.deleteSync(recursive: true);
    });
  });
}
