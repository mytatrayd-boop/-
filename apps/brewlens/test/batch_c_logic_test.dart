import 'dart:io';
import 'dart:typed_data';

import 'package:brewlens/app/providers.dart';
import 'package:brewlens/backend/demo/demo_account_repository.dart';
import 'package:brewlens/backend/demo/demo_analysis_repository.dart';
import 'package:brewlens/backend/demo/demo_auth_repository.dart';
import 'package:brewlens/backend/demo/demo_purchases_repository.dart';
import 'package:brewlens/backend/demo/demo_reviews_repository.dart';
import 'package:brewlens/domain/models/app_failure.dart';
import 'package:brewlens/domain/models/coffee_type.dart';
import 'package:brewlens/domain/models/purchase_offer.dart';
import 'package:brewlens/domain/models/review.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('brewlens_c');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test(
    'delete account wipes all demo data and images, keeps language, signs out',
    () async {
      SharedPreferences.setMockInitialValues({'locale': 'en'});
      final prefs = await SharedPreferences.getInstance();
      final dir = Directory('${tmp.path}/demo_reviews');
      Future<Directory> images() async => dir;
      final auth = DemoAuthRepository(prefs, latency: Duration.zero);
      await auth.signIn(email: 'a@b.co', password: '123456');
      final reviews = DemoReviewsRepository(prefs, images);
      await reviews.save(
        Review(
          id: '',
          coffeeType: CoffeeType.espresso,
          imagePath: '',
          aiScore: 7,
          aiNotes: const ['n'],
          aiTip: 't',
          createdAt: DateTime(2026),
        ),
        Uint8List.fromList([1, 2, 3]),
      );
      final analysis = DemoAnalysisRepository(prefs, latency: Duration.zero);
      await analysis.setSimulateSubscriber(true);
      await prefs.setStringList('demo_favorites', ['s1']);
      expect(dir.listSync(), isNotEmpty);

      final sessions = <Object?>[];
      final sub = auth.sessionChanges().listen(sessions.add);
      await DemoAccountRepository(prefs, images, auth).deleteAccount();
      await Future<void>.delayed(Duration.zero);

      expect(await dir.exists(), isFalse);
      expect(prefs.getKeys(), {'locale'});
      expect(reviews.all(), isEmpty);
      expect(auth.currentSession, isNull);
      expect(sessions, [null]);
      await sub.cancel();
    },
  );

  test(
    'simulate subscriber raises the daily limit to 20 and ends with fair use',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final analysis = DemoAnalysisRepository(prefs, latency: Duration.zero);
      final image = Uint8List.fromList(List.filled(100, 1));
      expect((await analysis.usage()).limit, 2);

      await analysis.setSimulateSubscriber(true);
      final usage = await analysis.usage();
      expect(usage.limit, 20);
      expect(usage.remaining, 20);
      expect(usage.isSubscriber, isTrue);
      expect(await DemoPurchasesRepository(analysis).isSubscriber(), isTrue);

      for (var i = 0; i < 20; i++) {
        await analysis.analyze(
          image,
          type: CoffeeType.espresso,
          languageCode: 'ar',
        );
      }
      await expectLater(
        analysis.analyze(image, type: CoffeeType.espresso, languageCode: 'ar'),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.code,
            'code',
            FailureCode.fairUseReached,
          ),
        ),
      );

      await analysis.setSimulateSubscriber(false);
      expect((await analysis.usage()).limit, 2);
      expect((await analysis.usage()).remaining, 0);
    },
  );

  test(
    'demo purchases: D8 prices, trial on annual only, purchase unavailable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = DemoPurchasesRepository(DemoAnalysisRepository(prefs));
      final offers = await repo.offers();
      expect(repo.isAvailable, isFalse);
      final annual = offers.firstWhere((o) => o.period == PlanPeriod.annual);
      final monthly = offers.firstWhere((o) => o.period == PlanPeriod.monthly);
      expect(annual.priceLabel, '99.99');
      expect(annual.trialDays, 7);
      expect(monthly.priceLabel, '14.99');
      expect(monthly.trialDays, 0);
      await expectLater(
        repo.purchase(annual),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.code,
            'code',
            FailureCode.purchaseUnavailable,
          ),
        ),
      );
    },
  );

  test(
    'language choice is saved and survives a restart; device = no saved value',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer make() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      final first = make();
      expect(first.read(localeProvider), isNull);
      await first.read(localeProvider.notifier).set(const Locale('en'));
      expect(first.read(localeProvider), const Locale('en'));
      first.dispose();

      final second = make();
      expect(second.read(localeProvider), const Locale('en'));
      await second.read(localeProvider.notifier).set(null);
      expect(prefs.getString(LocaleNotifier.key), isNull);
      second.dispose();
    },
  );
}
