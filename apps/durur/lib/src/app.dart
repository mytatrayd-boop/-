import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import 'features/common/draft_banner.dart';
import 'notifications/notification_content.dart';
import 'providers.dart';
import 'repository/settings_repository.dart';
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
      onboardingDone: ref.read(settingsProvider).onboardingDone,
      tablesReady: tables != null,
      cityResolved: cityId != null && tables?.city(cityId) != null,
    );
  }

  // العودة للواجهة: إعادة قراءة إذن التنبيهات ومزامنتها (منطقة زمنية أو يوم
  // جديد، ARCHITECTURE §9).
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () {
      ref.read(notificationPermissionProvider.notifier).refresh();
      ref.read(notificationSyncProvider.notifier).sync();
    },
  );

  @override
  void initState() {
    super.initState();
    _lastKey = _redirectKey();
    ref.listenManual(settingsProvider, (_, _) => _maybeRefresh());
    ref.listenManual(tablesProvider, (_, _) => _maybeRefresh());
    // المزامنة تبدأ مع فتح التطبيق وتبقى ما دام مفتوحاً.
    ref.listenManual(notificationSyncProvider, (_, _) {});
    _lifecycle;
    _initNotifications();
  }

  /// تهيئة البلجن والضغط على التنبيه (من الخلفية أو من حالة الإغلاق).
  Future<void> _initNotifications() async {
    final scheduler = ref.read(notificationSchedulerProvider);
    try {
      await scheduler.initialize(onTap: openNotificationPayload);
      final payload = await scheduler.launchPayload();
      if (mounted && payload != null) await openNotificationPayload(payload);
    } on Object {
      // بلا تنبيهات يعمل التطبيق طبيعياً؛ فشل الجدولة يظهر في الإعدادات.
    }
  }

  /// يفتح صفحة العنصر/الدَّرّ من حمولة تنبيه فوق الرئيسية على اليوم، فيرجع
  /// زر الرجوع إلى الرئيسية (DESIGN 8.9). حمولة غير صالحة تُهمل.
  @visibleForTesting
  Future<void> openNotificationPayload(String payload) async {
    if (!mounted || !isNotificationPayload(payload)) return;
    // أثناء الإعداد الأولي تُهمل الحمولة (لا قفز فوق شاشات البداية).
    if (!ref.read(settingsProvider).onboardingDone) return;
    ref.read(todayProvider.notifier).refresh();
    ref.read(selectedDateProvider.notifier).backToToday();
    _router.go(AppRoutes.home);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _router.push(payload);
  }

  // يُعاد تقييم التوجيه فقط عند تغيّر ما يؤثر فيه، لا عند كل تغيير مدينة
  // (إعادة التقييم أثناء رجوع شاشة مدفوعة تُربك مكدّس الصفحات).
  late (bool, bool, bool, bool) _lastKey;

  (bool, bool, bool, bool) _redirectKey() {
    final s = _redirectState();
    return (
      s.savedCityId == null,
      s.onboardingDone,
      s.tablesReady,
      s.cityResolved,
    );
  }

  void _maybeRefresh() {
    final key = _redirectKey();
    if (key == _lastKey) return;
    _lastKey = key;
    _refresh.value++;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
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
      // السمة من الإعدادات (DESIGN 8.7)؛ الافتراضي حسب الجهاز.
      themeMode: switch (ref.watch(settingsProvider.select((s) => s.theme))) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      },
      theme: buildDururTheme(Brightness.light),
      darkTheme: buildDururTheme(Brightness.dark),
      builder: (context, child) => DraftBannerFrame(child: child!),
      routerConfig: _router,
    );
  }
}
