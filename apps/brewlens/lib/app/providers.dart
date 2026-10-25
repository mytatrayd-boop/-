import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/demo/demo_analysis_repository.dart';
import '../backend/demo/demo_auth_repository.dart';
import '../domain/models/auth_session.dart';
import '../domain/models/usage.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/analysis_repository.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/purchases_repository.dart';
import '../domain/repositories/reviews_repository.dart';
import '../domain/repositories/shops_repository.dart';
import 'env.dart';

Never _notConfigured(String name) =>
    throw UnimplementedError('$name: يُحقن في main حسب الوضع');

final appConfigProvider = Provider<AppConfig>((ref) => _notConfigured('AppConfig'));
final sharedPreferencesProvider =
    Provider<SharedPreferences>((ref) => _notConfigured('SharedPreferences'));

// الواجهات: الشاشات لا تعرف أي تنفيذ يعمل (ARCHITECTURE §2).
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => _notConfigured('AuthRepository'));
final analysisRepositoryProvider =
    Provider<AnalysisRepository>((ref) => _notConfigured('AnalysisRepository'));
final reviewsRepositoryProvider =
    Provider<ReviewsRepository>((ref) => _notConfigured('ReviewsRepository'));
final shopsRepositoryProvider =
    Provider<ShopsRepository>((ref) => _notConfigured('ShopsRepository'));
final purchasesRepositoryProvider =
    Provider<PurchasesRepository>((ref) => _notConfigured('PurchasesRepository'));
final accountRepositoryProvider =
    Provider<AccountRepository>((ref) => _notConfigured('AccountRepository'));

/// تنفيذات وضع العرض المتوفرة حتى الآن (الدفعة أ).
List<Override> demoOverrides(
  SharedPreferences prefs, {
  Duration latency = const Duration(milliseconds: 600),
}) =>
    [
      appConfigProvider.overrideWithValue(const AppConfig.demo()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(DemoAuthRepository(prefs, latency: latency)),
      analysisRepositoryProvider.overrideWithValue(DemoAnalysisRepository(prefs)),
    ];

/// حالة الجلسة؛ يعتمد عليها redirect في go_router.
class SessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.sessionChanges().listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return repo.currentSession;
  }
}

final sessionProvider =
    NotifierProvider<SessionNotifier, AuthSession?>(SessionNotifier.new);

/// العدّاد كما تعيده الخلفية؛ يُعاد جلبه عند تغيّر الجلسة.
final usageProvider = FutureProvider<Usage>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(analysisRepositoryProvider).usage();
});

const supportedLocales = [Locale('ar'), Locale('en')];

/// يختار لغة الواجهة من لغات الجهاز: أول لغة مدعومة، وإلا العربية (F1 معيار 2).
Locale resolveLocale(List<Locale>? deviceLocales) {
  for (final device in deviceLocales ?? const <Locale>[]) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == device.languageCode) return supported;
    }
  }
  return supportedLocales.first;
}

/// اللغة المختارة يدوياً (null = لغة الجهاز)، محفوظة في shared_preferences.
class LocaleNotifier extends Notifier<Locale?> {
  static const key = 'locale';

  @override
  Locale? build() {
    final code = ref.watch(sharedPreferencesProvider).getString(key);
    return code == null ? null : Locale(code);
  }

  Future<void> set(Locale? locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, locale.languageCode);
    }
    state = locale;
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
