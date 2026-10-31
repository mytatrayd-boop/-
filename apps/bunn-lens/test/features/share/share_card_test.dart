import 'dart:io';
import 'dart:ui' as ui;

import 'package:bunn_lens/domain/cafe.dart';
import 'package:bunn_lens/domain/scan.dart';
import 'package:bunn_lens/features/share/fit_text.dart';
import 'package:bunn_lens/features/share/share_card_data.dart';
import 'package:bunn_lens/features/share/share_card_renderer.dart';
import 'package:bunn_lens/features/share/share_flow.dart';
import 'package:bunn_lens/features/share/signed_logo.dart';
import 'package:bunn_lens/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Scan _scan({Cafe? cafe, String? roaster = 'محمصة الصباح', int score = 82}) => Scan(
      id: 1,
      type: ScanType.bean,
      score: score,
      notes: const ['تحميص متوسط متجانس', 'لمعان زيتي خفيف', 'حبات سليمة بلا كسور'],
      imagePath: '/x.jpg',
      createdAt: DateTime(2026, 1, 1),
      roasterName: roaster,
      cafe: cafe,
    );

Cafe _cafe(String name, {bool loc = true}) =>
    Cafe(id: 1, name: name, savedAt: DateTime(2026), lat: loc ? 24.7136 : null, lng: loc ? 46.6753 : null);

/// يرسم البطاقة عبر الـOverlay ويعيد أبعاد PNG الناتج. إن وُجد SHARE_CARD_OUT يُحفظ الملف للمعاينة.
Future<ui.Size> _render(
  WidgetTester tester, {
  required Scan scan,
  required String userName,
  int photoW = 1600,
  int photoH = 1200,
  Locale locale = const Locale('ar'),
  String? saveAs,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final l10n = await AppLocalizations.delegate.load(locale);
  late BuildContext ctx;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: SizedBox());
    }),
  ));
  final dir = Directory.systemTemp.createTempSync('share_card_');
  addTearDown(() => dir.deleteSync(recursive: true));

  final prepared = (await tester.runAsync(() async {
    final photo = await _makeImage(width: photoW, height: photoH);
    final logo = await loadLogoMark(rootBundle);
    return (photo, logo);
  }))!;
  final data = ShareCardData.fromScan(
    l10n: l10n,
    scan: scan,
    userName: userName,
    photo: prepared.$1,
    logo: prepared.$2,
    textDirection: Directionality.of(ctx),
  );
  final session = ShareCardSession.start(ctx, data);
  await tester.pump();
  final size = (await tester.runAsync(() async {
    final png = await session.capture();
    final out = Platform.environment['SHARE_CARD_OUT'];
    if (saveAs != null && out != null) File('$out/$saveAs.png').writeAsBytesSync(png);
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    return ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }))!;
  session.dispose();
  return size;
}

Future<ui.Image> _makeImage({required int width, required int height}) {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(width.toDouble(), height.toDouble()), [const Color(0xFF5A3A22), const Color(0xFFC89B6A)]));
  c.drawCircle(Offset(width / 2, height / 2), height / 4, Paint()..color = const Color(0xFF2B1B12));
  return rec.endRecording().toImage(width, height);
}

/// للمعاينة البصرية فقط (SHARE_CARD_OUT): يحمّل الخطوط الحقيقية بدل خط Ahem الافتراضي في الاختبارات.
Future<void> _loadRealFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
    }
    await loader.load();
  }

  await load('IBMPlexSansArabic', [
    'assets/fonts/IBMPlexSansArabic-400.ttf',
  ]);
  await load('ArefRuqaa', ['assets/fonts/ArefRuqaa-400.ttf']);
  await load('MaterialIcons', ['/opt/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
}

void main() {
  setUpAll(() async {
    if (Platform.environment['SHARE_CARD_OUT'] != null) await _loadRealFonts();
  });

  const expected = ui.Size(1080, 1350);

  testWidgets('PNG بالأبعاد 1080×1350: مقهى بموقع، عربي', (tester) async {
    expect(
        await _render(tester,
            scan: _scan(cafe: _cafe('مقهى الورد')), userName: 'أحمد', saveAs: 'full_ar'),
        expected);
  });

  testWidgets('بلا موقع (اسم المقهى فقط)', (tester) async {
    expect(await _render(tester, scan: _scan(cafe: _cafe('مقهى الورد', loc: false)), userName: 'سارة', saveAs: 'nolocation'), expected);
  });

  testWidgets('بلا مقهى', (tester) async {
    expect(await _render(tester, scan: _scan(), userName: 'خالد', saveAs: 'nocafe'), expected);
  });

  testWidgets('اسم طويل جداً واسم مقهى طويل', (tester) async {
    expect(
        await _render(tester,
            scan: _scan(cafe: _cafe('مقهى الأصدقاء الجميل للقهوة المختصة في حي الياسمين الشمالي الكبير')),
            userName: 'عبدالرحمن بن محمد الفاضل الحربي الشمري',
            saveAs: 'long'),
        expected);
  });

  testWidgets('صورة كبيرة جداً (4000×3000) وصورة عمودية', (tester) async {
    expect(await _render(tester, scan: _scan(cafe: _cafe('مقهى')), userName: 'Sam', photoW: 4000, photoH: 3000), expected);
    expect(await _render(tester, scan: _scan(), userName: 'Sam', photoW: 600, photoH: 2400), expected);
  });

  testWidgets('إنجليزي LTR واسم لاتيني', (tester) async {
    expect(
        await _render(tester,
            scan: _scan(cafe: _cafe('Rose Cafe'), roaster: 'Acme', score: 45),
            userName: 'Alexander',
            locale: const Locale('en'),
            saveAs: 'en'),
        expected);
  });

  testWidgets('معاينة التوقيع: أسماء قصيرة وطويلة ولاتينية', (tester) async {
    expect(await _render(tester, scan: _scan(cafe: _cafe('مقهى الورد')), userName: 'أحمد', saveAs: 'sig_ahmad'), expected);
    expect(
        await _render(tester,
            scan: _scan(cafe: _cafe('مقهى الورد')), userName: 'عبدالرحمن بن محمد العتيبي', saveAs: 'sig_long'),
        expected);
    expect(
        await _render(tester,
            scan: _scan(cafe: _cafe('Rose Cafe'), roaster: 'Acme'),
            userName: 'Sara',
            locale: const Locale('en'),
            saveAs: 'sig_sara'),
        expected);
  });

  test('ذيل التوقيع: يقصر للأسماء الطويلة ويختفي إن لم يبقَ مكان خارج الحروف', () {
    expect(SignedLogo.tailLength(100), SignedLogo.tailMaxLength);
    final mid = SignedLogo.tailLength(230);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(SignedLogo.tailMaxLength));
    expect(SignedLogo.tailLength(SignedLogo.width), 0);
    expect(SignedLogo.tailLength(1000), 0);
  });

  test('sharePositionOrigin يصل إلى ShareParams (iPad)', () {
    const origin = Rect.fromLTWH(300, 40, 48, 48);
    expect(buildShareParams('t', '/a.png', origin).sharePositionOrigin, origin);
    expect(buildShareParams('t', '/a.png', null).sharePositionOrigin, isNull);
  });

  testWidgets('originFromContext: مستطيل الزر على الشاشة', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 30, top: 50),
          child: SizedBox(width: 48, height: 48, child: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          })),
        ),
      ),
    ));
    expect(originFromContext(ctx), const Rect.fromLTWH(30, 50, 48, 48));
  });

  test('fitFontSize: يصغر حتى الحد الأدنى ولا ينزل عنه', () {
    const style = TextStyle(fontFamily: 'ArefRuqaa');
    final short = fitFontSize(text: 'علي', style: style, maxWidth: 280, max: 52, min: 36);
    final long = fitFontSize(text: 'ع' * 60, style: style, maxWidth: 280, max: 52, min: 36);
    expect(short, 52);
    expect(long, 36);
  });

  test('containsArabic', () {
    expect(containsArabic('أحمد'), isTrue);
    expect(containsArabic('Ahmed'), isFalse);
  });

  test('loadScanPhoto: ملف مفقود = null، وصورة كبيرة تُصغَّر إلى 1200', () async {
    expect(await loadScanPhoto('/no/such/file.jpg'), isNull);
    final dir = Directory.systemTemp.createTempSync('photo_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final img = await _makeImage(width: 3000, height: 2000);
    final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final f = File('${dir.path}/big.png')..writeAsBytesSync(bytes);
    final loaded = await loadScanPhoto(f.path);
    expect(loaded!.width, 1200);
    expect(loaded.height, 800);
  });
}
