import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'src/app/adhan_bar.dart';
import 'src/app/paywall.dart';
import 'src/app/providers.dart';
import 'src/app/qibla_screen.dart';
import 'src/app/services.dart';
import 'src/app/settings_screen.dart';

void main() {
  // بلا إعادة محاولة تلقائية: الخطأ يظهر للمستخدم بدل دوّامة تحميل لا تنتهي.
  runApp(ProviderScope(retry: (_, _) => null, child: const LamhaApp()));
}

/// العربية فقط في النسخة الأولى (SPEC ٨)، ومن اليمين لليسار.
/// مربع القبلة في الودجت يفتح «اتجاه القبلة»، وبقية الودجت تفتح الإعدادات.
class LamhaApp extends ConsumerStatefulWidget {
  const LamhaApp({super.key});

  @override
  ConsumerState<LamhaApp> createState() => _LamhaAppState();
}

class _LamhaAppState extends ConsumerState<LamhaApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  StreamSubscription<Uri?>? _clicks;
  var _locating = false;

  @override
  void initState() {
    super.initState();
    final launch = ref.read(widgetLaunchProvider);
    launch.initial().then(_open);
    _clicks = launch.clicks.listen(_open);
    // تحديث الموقع تلقائياً عند الفتح وكل عودة للتطبيق (إن كان إذن الموقع ممنوحاً مسبقاً).
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clicks?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshLocation();
  }

  /// تحديث صامت للموقع (SettingsController.refreshMyLocation): لا يطلب إذناً ولا يظهر شيئاً للمستخدم.
  Future<void> _refreshLocation() async {
    if (_locating || !mounted) return;
    final navContext = _navigator.currentContext;
    if (navContext == null) return;
    _locating = true;
    try {
      final l = AppLocalizations.of(navContext);
      await ref.read(settingsControllerProvider.future);
      if (!mounted) return;
      await ref.read(settingsControllerProvider.notifier).refreshMyLocation(nearLabel: l.nearCity);
    } catch (e) {
      debugPrint('auto location: $e');
    } finally {
      _locating = false;
    }
  }

  void _open(Uri? uri) {
    if (uri == null) return;
    final nav = _navigator.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(uri));
      return;
    }
    nav.popUntil((r) => r.isFirst);
    if (isQiblaLaunch(uri)) {
      nav.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: QiblaScreen.routeName),
        builder: (_) => const QiblaScreen(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Tajawal',
        colorSchemeSeed: const Color(0xFFD6AA5C),
      ),
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const AdhanBar(),
        ],
      ),
      home: const AccessGate(child: SettingsScreen()),
    );
  }
}
