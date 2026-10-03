import 'dart:io';

import 'package:durur/src/features/item_detail/item_detail_view.dart';
import 'package:durur/src/routing/app_routes.dart';
import 'package:durur/src/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/app_harness.dart';

/// الخطوط (الميزة 17، D37 الخيار ٣، DESIGN §3): Amiri للعناوين (21sp فأكثر)
/// والمثل، وAlmarai للنص بأوزانه المضمّنة فقط.
Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tables = await loadAssetTables();
  final almaraiWeights = {
    FontWeight.w300,
    FontWeight.w400,
    FontWeight.w700,
    FontWeight.w800,
  };

  group('الثيم', () {
    for (final brightness in Brightness.values) {
      test('العناوين Amiri ≥ 21 والباقي Almarai ($brightness)', () {
        final theme = buildDururTheme(brightness);
        final t = theme.textTheme;
        final headings = {
          'displaySmall': t.displaySmall!,
          'headlineMedium': t.headlineMedium!,
          'headlineSmall': t.headlineSmall!,
          'titleLarge': t.titleLarge!,
        };
        for (final MapEntry(:key, :value) in headings.entries) {
          expect(value.fontFamily, 'Amiri', reason: key);
          expect(value.fontSize, greaterThanOrEqualTo(21), reason: key);
          expect(value.fontWeight, FontWeight.w700, reason: key);
        }
        final texts = {
          'titleMedium': t.titleMedium!,
          'titleSmall': t.titleSmall!,
          'bodyLarge': t.bodyLarge!,
          'bodyMedium': t.bodyMedium!,
          'bodySmall': t.bodySmall!,
          'labelLarge': t.labelLarge!,
          'labelMedium': t.labelMedium!,
          'labelSmall': t.labelSmall!,
        };
        for (final MapEntry(:key, :value) in texts.entries) {
          expect(value.fontFamily, 'Almarai', reason: key);
          expect(almaraiWeights, contains(value.fontWeight), reason: key);
        }
        // الخط الافتراضي لأي نص بلا نمط صريح.
        expect(theme.textTheme.bodyMedium!.fontFamily, DururFonts.body);
      });
    }
  });

  test('pubspec يضمّن Almarai وAmiri فقط، وملفاتها ورخصها موجودة', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final families = RegExp(r'^    - family: (\S+)', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m[1])
        .toList();
    expect(families, ['Almarai', 'Amiri']);
    final assets = RegExp(r'^        - asset: (assets/fonts/\S+)', multiLine: true)
        .allMatches(pubspec)
        .map((m) => m[1]!)
        .toList();
    expect(assets, hasLength(6));
    for (final path in assets) {
      expect(File(path).lengthSync(), greaterThan(100000), reason: path);
    }
    for (final weight in [300, 400, 700, 800]) {
      expect(pubspec, contains('weight: $weight'));
    }
    for (final family in ['Almarai', 'Amiri']) {
      final license = 'assets/fonts/$family-OFL.txt';
      expect(pubspec, contains('- $license'));
      expect(File(license).readAsStringSync(), contains('Open Font License'));
    }
  });

  test('لا أثر للخطين المحذوفين في الكود والأصول', () {
    final files = [
      File('pubspec.yaml'),
      ...Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
    ];
    for (final file in files) {
      final text = file.readAsStringSync();
      for (final old in ['ReemKufi', 'Reem Kufi', 'IBMPlex', 'IBM Plex']) {
        expect(text, isNot(contains(old)), reason: '${file.path}: $old');
      }
    }
    final fontFiles = Directory('assets/fonts')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    expect(
      fontFiles.where((f) => f.startsWith('ReemKufi') || f.startsWith('IBM')),
      isEmpty,
    );
  });

  group('النصوص المعروضة: Amiri لا يظهر تحت 21sp', () {
    // المثل (20sp) استثناء معتمد في الخيار ٣ (DESIGN §3)، فيُستثنى وحده.
    void expectNoSmallAmiri(WidgetTester tester) {
      final exempt = {
        ...find
            .descendant(
              of: find.byKey(ItemDetailView.proverbKey),
              matching: find.byType(RichText),
            )
            .evaluate(),
      };
      var checked = 0;
      for (final element in find.byType(RichText).evaluate()) {
        if (exempt.contains(element)) continue;
        final rich = element.widget as RichText;
        void visit(InlineSpan span, TextStyle inherited) {
          final style = inherited.merge(span.style);
          if (span is TextSpan && (span.text ?? '').trim().isNotEmpty) {
            checked++;
            if (style.fontFamily == DururFonts.display) {
              expect(
                style.fontSize,
                greaterThanOrEqualTo(DururFonts.displayMinSize),
                reason: span.text,
              );
            }
          }
          if (span is TextSpan) {
            for (final child in span.children ?? const <InlineSpan>[]) {
              visit(child, style);
            }
          }
        }

        visit(rich.text, const TextStyle());
      }
      expect(checked, greaterThan(0));
    }

    Future<void> goTo(WidgetTester tester, String route) async {
      GoRouter.of(tester.element(find.byType(Navigator).first)).go(route);
      await tester.pumpAndSettle();
    }

    testWidgets('الرئيسية والإعدادات والمصادر والأصل وصفحة نجم', (
      tester,
    ) async {
      await pumpDururApp(
        tester,
        prefs: await fakePrefs(savedCity('riyadh')),
        tables: tables,
      );
      expectNoSmallAmiri(tester);
      for (final route in [
        AppRoutes.settings,
        AppRoutes.sources,
        AppRoutes.origin,
        AppRoutes.item('suhail'),
      ]) {
        await goTo(tester, AppRoutes.home);
        await goTo(tester, route);
        expectNoSmallAmiri(tester);
      }
    });

    testWidgets('شاشة الترحيب', (tester) async {
      await pumpDururApp(tester, prefs: await fakePrefs(), tables: tables);
      expect(find.text('أهلاً بك في دليل المواسم'), findsOneWidget);
      expectNoSmallAmiri(tester);
    });
  });
}
