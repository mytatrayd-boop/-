import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'features/common/draft_banner.dart';
import 'providers.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

/// جذر التطبيق: العربية فقط في النسخة الأولى، واتجاه من اليمين لليسار.
class DururApp extends ConsumerStatefulWidget {
  const DururApp({super.key});

  static const Locale arabic = Locale('ar');

  @override
  ConsumerState<DururApp> createState() => _DururAppState();
}

class _DururAppState extends ConsumerState<DururApp> {
  // يُعيد تقييم التوجيه التلقائي عند تغيّر المدينة أو اكتمال تحميل الجداول.
  final _refresh = ValueNotifier<int>(0);

  // موجّه لكل نسخة من التطبيق (لا حالة مشتركة بين الاختبارات).
  late final GoRouter _router = createAppRouter(
    refreshListenable: _refresh,
    readState: _redirectState,
  );

  // يُقرأ من المصدرين مباشرة (لا من currentCityProvider) لأن المستمعين
  // يُنادَون أثناء تغيّر المصدر قبل إعادة حساب المزوّدات المشتقة.
  RedirectState _redirectState() {
    final cityId = ref.read(settingsProvider).cityId;
    final tables = ref.read(tablesProvider).value;
    return (
      savedCityId: cityId,
      tablesReady: tables != null,
      cityResolved: cityId != null && tables?.city(cityId) != null,
    );
  }

  @override
  void initState() {
    super.initState();
    _lastKey = _redirectKey();
    ref.listenManual(settingsProvider, (_, _) => _maybeRefresh());
    ref.listenManual(tablesProvider, (_, _) => _maybeRefresh());
  }

  // يُعاد تقييم التوجيه فقط عند تغيّر ما يؤثر فيه، لا عند كل تغيير مدينة
  // (إعادة التقييم أثناء رجوع شاشة مدفوعة تُربك مكدّس الصفحات).
  late (bool, bool, bool) _lastKey;

  (bool, bool, bool) _redirectKey() {
    final s = _redirectState();
    return (s.savedCityId == null, s.tablesReady, s.cityResolved);
  }

  void _maybeRefresh() {
    final key = _redirectKey();
    if (key == _lastKey) return;
    _lastKey = key;
    _refresh.value++;
  }

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: DururApp.arabic,
      supportedLocales: const [DururApp.arabic],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // الوضعان حسب الجهاز؛ اختيار السمة في الإعدادات يُضاف مع ميزتها.
      theme: buildDururTheme(Brightness.light),
      darkTheme: buildDururTheme(Brightness.dark),
      builder: (context, child) => DraftBannerFrame(child: child!),
      routerConfig: _router,
    );
  }
}
