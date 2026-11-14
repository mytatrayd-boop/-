import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rihla/app.dart';
import 'package:rihla/core/locale/locale_provider.dart';
import 'package:rihla/core/router/app_router.dart';
import 'package:rihla/core/theme/app_theme.dart';
import 'package:rihla/l10n/app_localizations_ar.dart';

import 'helpers/fakes.dart';

import 'package:rihla/l10n/app_localizations_en.dart';

Future<void> pump(
  WidgetTester t,
  Locale locale, {
  Size size = const Size(800, 360),
  double scale = 1.0,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ...HomeFakes().overrides,
        localeProvider.overrideWith(() => _Fixed(locale)),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: const RihlaApp(),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  final ar = AppLocalizationsAr();
  final en = AppLocalizationsEn();

  testWidgets('عربي: RTL ونصوص الترجمة، بلا overflow', (t) async {
    await pump(t, const Locale('ar'));
    expect(find.bySemanticsLabel(ar.startTrip), findsOneWidget);
    expect(
      Directionality.of(t.element(find.text(ar.audioOn))),
      TextDirection.rtl,
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('إنجليزي: LTR ونصوص الترجمة، بلا overflow', (t) async {
    await pump(t, const Locale('en'));
    expect(find.bySemanticsLabel(en.startTrip), findsOneWidget);
    expect(
      Directionality.of(t.element(find.text(en.audioOn))),
      TextDirection.ltr,
    );
    expect(t.takeException(), isNull);
  });

  for (final loc in ['ar', 'en']) {
    testWidgets('تنقل للإعدادات ورجوع وتكبير خط 130% صغير ($loc)', (t) async {
      await pump(t, Locale(loc), size: const Size(640, 300), scale: 1.3);
      final s = loc == 'ar' ? ar : en;
      await t.tap(find.byTooltip(s.settingsTitle));
      await t.pumpAndSettle();
      expect(find.text(s.settingsEmpty), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byType(BackButton));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('mute-button')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('مسار غير معروف يعرض صفحة غير موجودة مع رجوع', (t) async {
    await pump(t, const Locale('ar'));
    final ctx = t.element(find.byType(Scaffold).first);
    ProviderScope.containerOf(ctx).read(routerProvider).go('/nope');
    await t.pumpAndSettle();
    expect(find.text(ar.notFoundTitle), findsOneWidget);
    await t.tap(find.text(ar.backToHome));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('mute-button')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('الثيم داكن حسب DESIGN', (t) async {
    await pump(t, const Locale('ar'));
    final theme = AppTheme.dark();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.ink);
    expect(theme.colorScheme.primary, const Color(0xFFF5A524));
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });
}

class _Fixed extends LocaleNotifier {
  _Fixed(this.l);
  final Locale l;
  @override
  Locale? build() => l;
}
