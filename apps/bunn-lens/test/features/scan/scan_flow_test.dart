import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bunn_lens/app/app.dart';
import 'package:bunn_lens/app/locale_provider.dart';
import 'package:bunn_lens/data/providers.dart';
import 'package:bunn_lens/data/services/analysis_service.dart';
import 'package:bunn_lens/domain/analysis.dart';
import 'package:bunn_lens/domain/scan.dart';
import 'package:bunn_lens/features/scan/scan_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class _FakeImagePort implements ImagePort {
  _FakeImagePort({this.fail = false});
  final bool fail;
  PickSource? last;
  @override
  Future<Uint8List?> pick(PickSource source) async {
    last = source;
    if (fail) throw StateError('denied');
    return Uint8List.fromList(_png);
  }
}

class _FakeAnalysis implements AnalysisService {
  final queue = <Object>[];
  Completer<AnalysisResult>? gate;
  int calls = 0;
  ScanType? lastType;
  @override
  Future<AnalysisResult> analyze(ScanType type, Uint8List jpeg) async {
    calls++;
    lastType = type;
    if (gate != null) return gate!.future;
    final next = queue.removeAt(0);
    if (next is AnalysisException) throw next;
    return next as AnalysisResult;
  }
}

class _FakeDisclosure implements DisclosureStore {
  _FakeDisclosure(this.value);
  bool value;
  @override
  Future<bool> accepted() async => value;
  @override
  Future<void> accept() async => value = true;
}

AnalysisResult _res({AnalysisStatus status = AnalysisStatus.ok, int score = 80}) => AnalysisResult(
    status: status, score: score, notes: const ['لون متجانس', 'بلا عيوب ظاهرة', 'لمعان مناسب'], promptVersion: 'v2');

Future<TestRepo> _pump(
  WidgetTester tester, {
  required _FakeAnalysis analysis,
  _FakeImagePort? picker,
  _FakeDisclosure? disclosure,
  Locale locale = const Locale('ar'),
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final t = (await tester.runAsync(() async => TestRepo.create()))!;
  addTearDown(() => tester.runAsync(t.dispose));
  await tester.pumpWidget(ProviderScope(
    overrides: [
      localeProvider.overrideWith(() => _Locale(locale)),
      scanRepositoryProvider.overrideWithValue(t.repo),
      cafeRepositoryProvider.overrideWithValue(t.cafes),
      analysisServiceProvider.overrideWithValue(analysis),
      imagePortProvider.overrideWithValue(picker ?? _FakeImagePort()),
      disclosureStoreProvider.overrideWithValue(disclosure ?? _FakeDisclosure(true)),
    ],
    child: const BunnLensApp(),
  ));
  await tester.pumpAndSettle();
  return t;
}

class _Locale extends LocaleNotifier {
  _Locale(this._l);
  final Locale _l;
  @override
  Locale build() => _l;
}

/// الحفظ في drift يحتاج وقتاً حقيقياً (خارج الزمن الوهمي)؛ نتناوب بينه وبين إطارات الواجهة.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 25));
  }
  await tester.pumpAndSettle();
}

Future<void> _toPreview(WidgetTester tester) async {
  await tester.tap(find.text('التقاط صورة'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('نجاح: التقاط ← معاينة ← استخدام ← نتيجة بالفئة وحفظ الفحص', (tester) async {
    final a = _FakeAnalysis()..queue.add(_res(score: 90));
    final picker = _FakeImagePort();
    final t = await _pump(tester, analysis: a, picker: picker);
    expect(find.text('ماذا تفحص؟'), findsOneWidget);
    await _toPreview(tester);
    expect(picker.last, PickSource.camera);
    expect(find.text('معاينة الصورة'), findsOneWidget);
    await tester.tap(find.text('استخدم الصورة'));
    await _settle(tester);
    expect(a.calls, 1);
    expect(a.lastType, ScanType.bean);
    expect(find.text('ممتاز'), findsWidgets);
    expect(find.text('لون متجانس'), findsOneWidget);
    expect(find.text('التقدير بصري تقريبي وليس حكماً نهائياً'), findsOneWidget);
    final saved = await tester.runAsync(() => t.repo.watchAll().first);
    expect(saved!.length, 1);
    expect(saved.single.score, 90);
    await unmountApp(tester);
  });

  testWidgets('اختيار «قهوة» يرسل النوع قهوة', (tester) async {
    final a = _FakeAnalysis()..queue.add(_res());
    await _pump(tester, analysis: a);
    await tester.tap(find.text('قهوة'));
    await tester.pumpAndSettle();
    await _toPreview(tester);
    await tester.tap(find.text('استخدم الصورة'));
    await _settle(tester);
    expect(a.lastType, ScanType.coffee);
    await unmountApp(tester);
  });

  testWidgets('صورة غير واضحة: رسالة ولا حفظ ولا إعادة محاولة بنفس الصورة', (tester) async {
    final a = _FakeAnalysis()..queue.add(_res(status: AnalysisStatus.unclear, score: 0));
    final t = await _pump(tester, analysis: a);
    await _toPreview(tester);
    await tester.tap(find.text('استخدم الصورة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('لم نتعرف على بن أو قهوة'), findsOneWidget);
    expect(find.text('لم يُحتسب هذا الفحص'), findsOneWidget);
    expect(find.text('أعد المحاولة'), findsNothing);
    expect(find.text('أعد التصوير'), findsOneWidget);
    expect((await tester.runAsync(() => t.repo.watchAll().first))!, isEmpty);
    await tester.tap(find.text('أعد التصوير'));
    await tester.pumpAndSettle();
    expect(find.text('ماذا تفحص؟'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('بلا إنترنت: رسالة ثم إعادة المحاولة تنجح بنفس الصورة', (tester) async {
    final a = _FakeAnalysis()
      ..queue.addAll([const AnalysisException(AnalysisError.offline), _res(score: 75)]);
    final t = await _pump(tester, analysis: a);
    await _toPreview(tester);
    await tester.tap(find.text('استخدم الصورة'));
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
    expect((await tester.runAsync(() => t.repo.watchAll().first))!, isEmpty);
    await tester.tap(find.text('أعد المحاولة'));
    await _settle(tester);
    expect(a.calls, 2);
    expect(find.text('جيد'), findsWidgets);
    expect((await tester.runAsync(() => t.repo.watchAll().first))!.length, 1);
    await unmountApp(tester);
  });

  testWidgets('انتهاء الحصة: لا إعادة محاولة، والخدمة مشغولة: إعادة متاحة', (tester) async {
    final a = _FakeAnalysis()..queue.add(const AnalysisException(AnalysisError.quotaExhausted));
    await _pump(tester, analysis: a);
    await _toPreview(tester);
    await tester.tap(find.text('استخدم الصورة'));
    await tester.pumpAndSettle();
    expect(find.text('انتهت فحوصاتك المتاحة'), findsOneWidget);
    expect(find.text('أعد المحاولة'), findsNothing);
    await unmountApp(tester);

    final b = _FakeAnalysis()..queue.add(const AnalysisException(AnalysisError.busy));
    await _pump(tester, analysis: b);
    await _toPreview(tester);
    await tester.tap(find.text('استخدم الصورة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('الخدمة مشغولة'), findsOneWidget);
    expect(find.text('أعد المحاولة'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('التحميل: نص متبدل، بعد 10 ثوانٍ «أطول من المعتاد»، والإلغاء لا يحفظ', (tester) async {
    final a = _FakeAnalysis()..gate = Completer<AnalysisResult>();
    final t = await _pump(tester, analysis: a);
    await _toPreview(tester);
    await tester.tap(find.text('استخدم الصورة'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('نفحص لون التحميص…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('نقيّم التجانس والعيوب…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('يستغرق أطول من المعتاد'), findsOneWidget);
    await tester.tap(find.text('إلغاء الفحص'));
    await tester.pumpAndSettle();
    expect(find.text('ماذا تفحص؟'), findsOneWidget);
    // وصول النتيجة بعد الإلغاء يُتجاهل
    a.gate!.complete(_res());
    await _settle(tester);
    expect(find.text('ماذا تفحص؟'), findsOneWidget);
    expect((await tester.runAsync(() => t.repo.watchAll().first))!, isEmpty);
    await unmountApp(tester);
  });

  testWidgets('الإفصاح: يظهر أول مرة فقط ولا يُرسل شيء قبل الموافقة', (tester) async {
    final a = _FakeAnalysis()..queue.add(_res());
    final d = _FakeDisclosure(false);
    await _pump(tester, analysis: a, disclosure: d);
    await _toPreview(tester);
    await tester.tap(find.text('استخدم الصورة'));
    await tester.pumpAndSettle();
    expect(find.text('قبل أول فحص'), findsOneWidget);
    expect(a.calls, 0);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(a.calls, 0);
    expect(find.text('معاينة الصورة'), findsOneWidget);
    await tester.tap(find.text('استخدم الصورة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أوافق وأتابع'));
    await _settle(tester);
    expect(d.value, isTrue);
    expect(a.calls, 1);
    await unmountApp(tester);
  });

  testWidgets('رفض إذن الكاميرا: رسالة والمعرض يبقى متاحاً', (tester) async {
    final a = _FakeAnalysis();
    await _pump(tester, analysis: a, picker: _FakeImagePort(fail: true));
    await _toPreview(tester);
    expect(find.textContaining('تعذّر الوصول للكاميرا'), findsOneWidget);
    expect(find.text('من المعرض'), findsOneWidget);
    await unmountApp(tester);
  });

  testWidgets('إنجليزي LTR', (tester) async {
    final a = _FakeAnalysis()..queue.add(_res(score: 60));
    await _pump(tester, analysis: a, locale: const Locale('en'));
    expect(find.text('What are you scanning?'), findsOneWidget);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use photo'));
    await _settle(tester);
    expect(find.text('Average'), findsWidgets);
    await unmountApp(tester);
  });
}
