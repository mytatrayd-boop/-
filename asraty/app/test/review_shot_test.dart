import 'dart:io';
import 'dart:ui' as ui;

import 'package:asraty/backend/access.dart';
import 'package:asraty/l10n/app_localizations.dart';
import 'package:asraty/ui/paywall.dart';
import 'package:asraty/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// The subscription screen with the real products' prices, for the App Review screenshot of the
/// six products (App Store Connect wants one per product). Runs only when REVIEW_SHOT_OUT is set:
///   REVIEW_SHOT_OUT=/tmp/paywall.png flutter test test/review_shot_test.dart
class _FakeAccess extends AccessNotifier {
  late final Store _s = Store(() {}, (_, __) async {})
    ..products = [
      for (final (id, price, raw) in [
        ('asraty.monthly', 'SAR 12.99', 12.99),
        ('asraty.yearly', 'SAR 79.99', 79.99),
        ('asraty.m10', 'SAR 19.99', 19.99),
        ('asraty.y10', 'SAR 129.99', 129.99),
        ('asraty.m20', 'SAR 29.99', 29.99),
        ('asraty.y20', 'SAR 179.99', 179.99),
      ])
        ProductDetails(id: id, title: id, description: id, price: price, rawPrice: raw, currencyCode: 'SAR'),
    ];
  @override
  Store get store => _s;
}

void main() {
  final out = Platform.environment['REVIEW_SHOT_OUT'];
  testWidgets('paywall screenshot', skip: out == null || out.isEmpty, (tester) async {
    final tajawal = FontLoader('Tajawal')
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    await tajawal.load();
    // Material icons (the radio buttons) and colour emoji (the family emoji), from the SDK / the system.
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter';
    final icons = File('$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
    }
    final emoji = [
      '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
      '$sdk/engine/src/flutter/txt/third_party/fonts/NotoColorEmoji.ttf',
    ].map(File.new).where((f) => f.existsSync()).firstOrNull;
    if (emoji != null) {
      await (FontLoader('NotoColorEmoji')..addFont(Future.value(ByteData.sublistView(emoji.readAsBytesSync())))).load();
    }
    await (FontLoader('BalooBhaijaan2')..addFont(rootBundle.load('assets/fonts/BalooBhaijaan2.ttf'))).load();

    tester.view.physicalSize = const Size(414 * 3, 736 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [accessProvider.overrideWith(_FakeAccess.new)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        theme: buildTheme(Brightness.light).copyWith(
          textTheme: buildTheme(Brightness.light).textTheme.apply(fontFamilyFallback: const ['NotoColorEmoji']),
        ),
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 414,
              height: 736,
              child: RepaintBoundary(
                key: const Key('shot'),
                child: ColoredBox(
                  color: buildTheme(Brightness.light).scaffoldBackgroundColor,
                  child: const SafeArea(child: Padding(padding: EdgeInsets.all(16), child: SingleChildScrollView(child: PaywallPage()))),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await File(out!).writeAsBytes(bytes.buffer.asUint8List());
    });
  });
}
