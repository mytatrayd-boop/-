/// الإعدادات وقت البناء عبر --dart-define فقط (ARCHITECTURE §2). لا قيم
/// افتراضية حقيقية في الكود.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const revenueCatGoogleKey =
      String.fromEnvironment('REVENUECAT_GOOGLE_KEY');
  static const revenueCatAppleKey =
      String.fromEnvironment('REVENUECAT_APPLE_KEY');
}

enum BackendMode { demo, supabase }

/// إعدادات التشغيل بعد اختيار التنفيذ.
class AppConfig {
  const AppConfig({required this.mode, required this.purchasesEnabled});

  /// تهيئة وضع العرض (للاختبارات وللبناء بلا مفاتيح).
  const AppConfig.demo()
      : mode = BackendMode.demo,
        purchasesEnabled = false;

  final BackendMode mode;

  /// الشراء الحقيقي متاح فقط مع Supabase ومفتاح RevenueCat للمنصة.
  final bool purchasesEnabled;

  bool get isDemo => mode == BackendMode.demo;
}

/// يختار التنفيذ: Supabase فقط إذا وُجد الرابط والمفتاح معاً، وإلا وضع العرض.
AppConfig resolveAppConfig({
  required String supabaseUrl,
  required String supabaseAnonKey,
  required String revenueCatKey,
}) {
  final hasSupabase =
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
  if (!hasSupabase) return const AppConfig.demo();
  return AppConfig(
    mode: BackendMode.supabase,
    purchasesEnabled: revenueCatKey.trim().isNotEmpty,
  );
}
