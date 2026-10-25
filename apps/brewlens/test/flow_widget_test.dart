import 'dart:convert';
import 'dart:typed_data';

import 'package:brewlens/app/app.dart';
import 'package:brewlens/app/env.dart';
import 'package:brewlens/app/providers.dart';
import 'package:brewlens/backend/demo/demo_analysis_repository.dart';
import 'package:brewlens/backend/demo/demo_auth_repository.dart';
import 'package:brewlens/backend/demo/demo_purchases_repository.dart';
import 'package:brewlens/backend/demo/demo_shops_repository.dart';
import 'package:brewlens/domain/models/review.dart';
import 'package:brewlens/domain/repositories/reviews_repository.dart';
import 'package:brewlens/domain/models/shop.dart';
import 'package:brewlens/features/capture/capture_screen.dart';
import 'package:brewlens/features/history/history_screen.dart';
import 'package:brewlens/features/home/home_screen.dart';
import 'package:brewlens/features/paywall/paywall_screen.dart';
import 'package:brewlens/features/result/result_screen.dart';
import 'package:brewlens/services/image_capture_service.dart';
import 'package:brewlens/services/location_service.dart';
import 'package:brewlens/services/maps_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PNG صالح 1×1.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// تقييمات في الذاكرة (ملفات dart:io لا تعمل داخل FakeAsync في widget tests).
class MemoryReviews implements ReviewsRepository {
  final items = <Review>[];
  final images = <String, Uint8List>{};
  var _n = 0;

  @override
  Future<Review> save(Review draft, Uint8List imageBytes) async {
    final id = 'r${_n++}';
    final r = Review(
      id: id,
      coffeeType: draft.coffeeType,
      imagePath: '$id.jpg',
      aiScore: draft.aiScore,
      aiNotes: draft.aiNotes,
      aiTip: draft.aiTip,
      createdAt: DateTime.now(),
      userRating: draft.userRating,
      userNotes: draft.userNotes,
      shopId: draft.shopId,
    );
    items.insert(0, r);
    images[r.imagePath] = imageBytes;
    return r;
  }

  @override
  Future<List<Review>> list({int offset = 0, int limit = 20}) async =>
      items.skip(offset).take(limit).toList();

  @override
  Future<Review> get(String id) async => items.firstWhere((r) => r.id == id);

  @override
  Future<Review> update(Review review) async {
    items[items.indexWhere((r) => r.id == review.id)] = review;
    return review;
  }

  @override
  Future<void> delete(String id) async {
    final r = items.firstWhere((r) => r.id == id);
    images.remove(r.imagePath);
    items.remove(r);
  }

  @override
  Future<Uint8List> imageBytes(Review review) async => images[review.imagePath]!;
}

class FakeCapture implements ImageCaptureService {
  Object? error;
  var settingsOpened = 0;

  @override
  Future<Uint8List?> pick(CaptureSource source) async {
    if (error != null) throw error!;
    return png;
  }

  @override
  Future<void> openAppSettings() async => settingsOpened++;
}

class FakeLocation implements LocationService {
  GeoPoint? point = const GeoPoint(24.5, 46.5);
  var calls = 0;

  @override
  Future<GeoPoint> currentPosition() async {
    calls++;
    return point ?? (throw const LocationUnavailable('permission_denied'));
  }

  @override
  Future<void> openSettings() async {}
}

class FakeMaps implements MapsLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Shop shop) async {
    opened.add(googleMapsUri(shop));
    return true;
  }
}

late MemoryReviews reviews;
late FakeCapture capture;
late FakeLocation location;
late FakeMaps maps;

Future<void> pumpApp(WidgetTester tester, {String locale = 'ar', int usedToday = 0}) async {
  // مقاس جوال شائع (360×780).
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'locale': locale,
    DemoAuthRepository.sessionKey: '{"user_id":"demo-a@b.co","email":"a@b.co"}',
    if (usedToday > 0) DemoAnalysisRepository.dayKey: riyadhDay(DateTime.now()),
    if (usedToday > 0) DemoAnalysisRepository.countKey: usedToday,
  });
  final prefs = await SharedPreferences.getInstance();
  reviews = MemoryReviews();
  capture = FakeCapture();
  location = FakeLocation();
  maps = FakeMaps();
  final analysis = DemoAnalysisRepository(prefs, latency: Duration.zero);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(const AppConfig.demo()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(DemoAuthRepository(prefs, latency: Duration.zero)),
      analysisRepositoryProvider.overrideWithValue(analysis),
      rejectionSimulatorProvider.overrideWithValue(analysis),
      subscriberSimulatorProvider.overrideWithValue(analysis),
      purchasesRepositoryProvider.overrideWithValue(DemoPurchasesRepository(analysis)),
      reviewsRepositoryProvider.overrideWithValue(reviews),
      shopsRepositoryProvider.overrideWithValue(DemoShopsRepository(prefs, () => reviews.items)),
      imageCaptureServiceProvider.overrideWithValue(capture),
      locationServiceProvider.overrideWithValue(location),
      mapsLauncherProvider.overrideWithValue(maps),
    ],
    child: const BrewLensApp(),
  ));
  await tester.pumpAndSettle();
}

Future<void> openCameraAndShoot(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('fab_camera')));
  await tester.pumpAndSettle();
  expect(find.byType(CaptureScreen), findsOneWidget);
  await tester.tap(find.byKey(const Key('shutter')));
  await tester.pumpAndSettle();
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('analyze -> result -> shop with location -> favorite -> save -> history', (tester) async {
    await pumpApp(tester);
    expect(find.text('متبقٍّ لك اليوم: 2 من 2'), findsOneWidget);
    await openCameraAndShoot(tester);

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('تقييم المظهر'), findsOneWidget);
    expect(find.textContaining('الطعم'), findsNothing);
    expect(find.text('ممتاز'), findsOneWidget);
    expect(find.text('تقرير الباريستا'), findsOneWidget);
    expect(find.textContaining('كريما بنية'), findsOneWidget);
    expect(find.textContaining('نصيحة للمرة القادمة: '), findsOneWidget);

    await scrollTo(tester, find.byKey(const Key('shop_row')));
    await tester.tap(find.byKey(const Key('star_4')));
    await tester.pump();
    // القلب معطّل حتى يُختار مقهى.
    expect(tester.widget<IconButton>(find.byKey(const Key('favorite_toggle'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('shop_row')));
    await tester.pumpAndSettle();
    expect(find.text('مقاهيك السابقة'), findsOneWidget);
    expect(find.text('مقهى النخيل'), findsOneWidget);
    expect(find.text('Qahwa Lab'), findsOneWidget);
    expect(location.calls, 0, reason: 'location is read only on tap');
    await tester.enterText(find.byKey(const Key('shop_name')), 'Blue Cup');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_location')));
    await tester.pumpAndSettle();
    expect(find.text('تم حفظ الموقع'), findsOneWidget);
    expect(location.calls, 1);
    await tester.tap(find.byKey(const Key('shop_done')));
    await tester.pumpAndSettle();
    expect(find.text('Blue Cup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('favorite_toggle')));
    await tester.pumpAndSettle();
    expect(find.text('أُضيف للمفضلة'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save_review')));
    await tester.pumpAndSettle();
    expect(find.text('تم الحفظ'), findsWidgets);
    expect(reviews.items, hasLength(1));
    final saved = reviews.items.single;
    expect(saved.userRating, 4);
    expect(saved.aiScore, 7.5);
    expect(saved.shopId, isNotNull);

    // الخروج بعد الحفظ لا يسأل.
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('متبقٍّ لك اليوم: 1 من 2'), findsOneWidget);
    expect(find.text('آخر التقييمات'), findsOneWidget);
    expect(find.text('مقاهيّ المفضلة'), findsOneWidget);

    await tester.tap(find.text('السجل').last);
    await tester.pumpAndSettle();
    expect(find.byType(ReviewTile), findsOneWidget);
    expect(find.text('Blue Cup'), findsOneWidget);
    expect(find.text('اليوم'), findsOneWidget);

    await tester.tap(find.text('المقاهي المفضلة'));
    await tester.pumpAndSettle();
    expect(find.text('★ 4 · مظهر 7.5 · تقييم واحد'), findsOneWidget);
    await tester.tap(find.text('فتح في خرائط جوجل'));
    await tester.pumpAndSettle();
    expect(maps.opened.single.toString(),
        'https://www.google.com/maps/search/?api=1&query=24.5,46.5');
  });

  testWidgets('simulated rejected image is not counted', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('fab_camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo_reject')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shutter')));
    await tester.pumpAndSettle();
    expect(find.text('لا يبدو أن الصورة لكوب قهوة'), findsOneWidget);
    expect(find.text('لم تُحتسب هذه المحاولة'), findsOneWidget);
    await tester.tap(find.text('التقط مجدداً'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.text('متبقٍّ لك اليوم: 2 من 2'), findsOneWidget);
  });

  testWidgets('limit reached opens the paywall without sending', (tester) async {
    await pumpApp(tester, usedToday: 2);
    expect(find.text('متبقٍّ لك اليوم: 0 من 2'), findsOneWidget);
    await openCameraAndShoot(tester);
    expect(find.byType(PaywallScreen), findsOneWidget);
    expect(find.text('انتهت محاولاتك المجانية لليوم'), findsOneWidget);
  });

  testWidgets('V60 shows the limited visual analysis note', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('fab_camera')));
    await tester.pumpAndSettle();
    const note = 'التحليل البصري لهذا النوع محدود؛ تقييمك الذوقي أهم';
    expect(find.text(note), findsNothing);
    await tester.tap(find.text('V60'));
    await tester.pump();
    expect(find.text(note), findsOneWidget);
    await tester.tap(find.byKey(const Key('shutter')));
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text(note), findsWidgets);
  });

  testWidgets('camera permission denied shows settings and gallery', (tester) async {
    await pumpApp(tester);
    capture.error = const CaptureAccessDenied(CaptureSource.camera);
    await openCameraAndShoot(tester);
    expect(find.text('نحتاج الكاميرا لتصوير كوبك وتقييم مظهره'), findsOneWidget);
    await tester.tap(find.text('فتح الإعدادات'));
    expect(capture.settingsOpened, 1);
    capture.error = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'اختيار من المعرض'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
  });

  testWidgets('location failure still allows saving the name only', (tester) async {
    await pumpApp(tester);
    location.point = null;
    await openCameraAndShoot(tester);
    await scrollTo(tester, find.byKey(const Key('shop_row')));
    await tester.tap(find.byKey(const Key('shop_row')));
    await tester.pumpAndSettle();
    // اسم فارغ: «تم» معطّل.
    expect(tester.widget<FilledButton>(find.byKey(const Key('shop_done'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('shop_name')), 'Blue Cup');
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_location')));
    await tester.pumpAndSettle();
    expect(find.text('لم نتمكن من تحديد موقعك — سيُحفظ الاسم فقط'), findsOneWidget);
    expect(find.text('تفعيل الموقع'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop_done')));
    await tester.pumpAndSettle();
    expect(find.text('Blue Cup'), findsOneWidget);
  });

  testWidgets('choosing a previous café links it without creating a new one', (tester) async {
    await pumpApp(tester);
    await openCameraAndShoot(tester);
    await scrollTo(tester, find.byKey(const Key('shop_row')));
    await tester.tap(find.byKey(const Key('shop_row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('shop_name')), 'qa');
    await tester.pump();
    expect(find.text('مقهى النخيل'), findsNothing);
    await tester.tap(find.text('Qahwa Lab'));
    await tester.pump();
    expect(find.text('سيُستخدم الموقع المحفوظ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('shop_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_review')));
    await tester.pumpAndSettle();
    expect(reviews.items.single.shopId, 'demo-shop-2');
  });

  testWidgets('closing an unsaved result asks to discard', (tester) async {
    await pumpApp(tester);
    await openCameraAndShoot(tester);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    expect(find.text('تجاهل النتيجة؟'), findsOneWidget);
    expect(find.text('ستبقى المحاولة محتسبة'), findsOneWidget);
    await tester.tap(find.text('البقاء'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تجاهل'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(reviews.items, isEmpty);
  });

  testWidgets('review details: edit stars, then delete with confirmation', (tester) async {
    await pumpApp(tester);
    await openCameraAndShoot(tester);
    await tester.tap(find.byKey(const Key('save_review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السجل').last);
    await tester.pumpAndSettle();
    expect(find.text('لم تُقيّم'), findsOneWidget);
    await tester.tap(find.byType(ReviewTile));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل التقييم'), findsOneWidget);
    expect(find.byKey(const Key('save_changes')), findsNothing);
    await scrollTo(tester, find.byKey(const Key('star_5')));
    await tester.tap(find.byKey(const Key('star_5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save_changes')));
    await tester.pumpAndSettle();
    expect(reviews.items.single.userRating, 5);
    expect(find.byKey(const Key('save_changes')), findsNothing);

    await tester.tap(find.byTooltip('خيارات أخرى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف التقييم'));
    await tester.pumpAndSettle();
    expect(find.text('حذف هذا التقييم وصورته نهائياً؟'), findsOneWidget);
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(reviews.items, isEmpty);
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('لا تقييمات بعد — صوّر كوبك الأول'), findsOneWidget);
  });

  testWidgets('English result is LTR with "Appearance score"', (tester) async {
    await pumpApp(tester, locale: 'en');
    await openCameraAndShoot(tester);
    expect(find.text('Appearance score'), findsOneWidget);
    expect(find.textContaining('taste', findRichText: true), findsNothing);
    expect(Directionality.of(tester.element(find.byType(ResultScreen))), TextDirection.ltr);
    expect(find.textContaining('crema'), findsWidgets);
  });

  testWidgets('small phone with 1.3x text: camera, result, history do not overflow', (tester) async {
    await pumpApp(tester);
    tester.view.physicalSize = const Size(1080, 1920); // 360×640
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fab_camera')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فرنش بريس'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shutter')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('shop_row')));
    await tester.tap(find.byKey(const Key('shop_row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qahwa Lab'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shop_done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save_review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('إغلاق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السجل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('المقاهي المفضلة'));
    await tester.pumpAndSettle();
    expect(find.text('Qahwa Lab'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
