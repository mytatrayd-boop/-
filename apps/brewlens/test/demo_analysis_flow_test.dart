import 'dart:typed_data';

import 'package:brewlens/backend/demo/demo_analysis_repository.dart';
import 'package:brewlens/backend/demo/demo_samples.dart';
import 'package:brewlens/domain/models/analysis_result.dart';
import 'package:brewlens/domain/models/app_failure.dart';
import 'package:brewlens/domain/models/coffee_type.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final image = Uint8List.fromList(List.filled(1000, 7));
  late DateTime now;

  Future<DemoAnalysisRepository> repo() async {
    SharedPreferences.setMockInitialValues({});
    return DemoAnalysisRepository(
      await SharedPreferences.getInstance(),
      clock: () => now,
      latency: Duration.zero,
    );
  }

  setUp(() => now = DateTime.utc(2026, 10, 25, 12));

  test('successful analysis returns the contract result and counts 1', () async {
    final r = await repo();
    final result = await r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar');
    expect(result.imageValid, isTrue);
    expect(result.score, 7.5);
    expect(result.notes, hasLength(3));
    expect(result.tip, isNotEmpty);
    expect(result.usage?.remaining, 1);
    expect((await r.usage()).remaining, 1);
  });

  test('rejected image is not counted and the flag resets', () async {
    final r = await repo();
    r.rejectNext = true;
    final rejected = await r.analyze(image, type: CoffeeType.v60, languageCode: 'en');
    expect(rejected.imageValid, isFalse);
    expect(rejected.reason, InvalidImageReason.notCoffee);
    expect(rejected.score, isNull);
    expect(rejected.notes, isEmpty);
    expect(rejected.usage?.remaining, 2);
    expect((await r.usage()).remaining, 2);
    expect(r.rejectNext, isFalse);
    // التالي ناجح ويُحتسب.
    final ok = await r.analyze(image, type: CoffeeType.v60, languageCode: 'en');
    expect(ok.imageValid, isTrue);
    expect((await r.usage()).remaining, 1);
  });

  test('third attempt on the same Riyadh day is limit_reached', () async {
    final r = await repo();
    await r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar');
    await r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar');
    expect((await r.usage()).remaining, 0);
    await expectLater(
      r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar'),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', FailureCode.limitReached)),
    );
  });

  test('at zero remaining even a simulated rejection is not sent', () async {
    final r = await repo();
    await r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar');
    await r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar');
    r.rejectNext = true;
    await expectLater(
      r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar'),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', FailureCode.limitReached)),
    );
  });

  test('counter resets at 00:00 Riyadh time', () async {
    now = DateTime.utc(2026, 10, 25, 20, 59); // 23:59 الرياض
    final r = await repo();
    await r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar');
    await r.analyze(image, type: CoffeeType.espresso, languageCode: 'ar');
    expect((await r.usage()).remaining, 0);
    now = DateTime.utc(2026, 10, 25, 21, 0); // 00:00 الرياض
    expect((await r.usage()).remaining, 2);
  });

  test('image above 1.5 MB is rejected without counting', () async {
    final r = await repo();
    await expectLater(
      r.analyze(Uint8List(DemoAnalysisRepository.maxImageBytes + 1),
          type: CoffeeType.espresso, languageCode: 'ar'),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', FailureCode.imageTooLarge)),
    );
    expect((await r.usage()).remaining, 2);
  });

  test('every sample result satisfies the SPEC §3 contract', () {
    for (final type in CoffeeType.values) {
      for (final lang in ['ar', 'en']) {
        final result = AnalysisResult.fromJson(demoResultJson(type, lang));
        expect(result.imageValid, isTrue, reason: '$type/$lang');
      }
    }
    expect(AnalysisResult.fromJson(demoRejectedJson).imageValid, isFalse);
  });

  test('sample notes are in the requested language', () {
    final ar = AnalysisResult.fromJson(demoResultJson(CoffeeType.espresso, 'ar'));
    final en = AnalysisResult.fromJson(demoResultJson(CoffeeType.espresso, 'en'));
    expect(ar.notes.first, contains('كريما'));
    expect(en.notes.first, contains('crema'));
  });
}
