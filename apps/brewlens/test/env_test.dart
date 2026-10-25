import 'package:brewlens/app/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAppConfig', () {
    test('no Supabase values -> demo mode, purchases off', () {
      final c = resolveAppConfig(supabaseUrl: '', supabaseAnonKey: '', revenueCatKey: 'rc');
      expect(c.isDemo, isTrue);
      expect(c.purchasesEnabled, isFalse);
    });

    test('only one Supabase value -> still demo', () {
      expect(
        resolveAppConfig(supabaseUrl: 'https://x.supabase.co', supabaseAnonKey: ' ', revenueCatKey: '').isDemo,
        isTrue,
      );
      expect(
        resolveAppConfig(supabaseUrl: '', supabaseAnonKey: 'anon', revenueCatKey: '').isDemo,
        isTrue,
      );
    });

    test('both Supabase values -> Supabase; purchases need RevenueCat key', () {
      final withRc = resolveAppConfig(
          supabaseUrl: 'https://x.supabase.co', supabaseAnonKey: 'anon', revenueCatKey: 'rc');
      expect(withRc.mode, BackendMode.supabase);
      expect(withRc.purchasesEnabled, isTrue);
      final noRc = resolveAppConfig(
          supabaseUrl: 'https://x.supabase.co', supabaseAnonKey: 'anon', revenueCatKey: '');
      expect(noRc.mode, BackendMode.supabase);
      expect(noRc.purchasesEnabled, isFalse);
    });

    test('this test build has no dart-defines -> demo', () {
      expect(
        resolveAppConfig(
          supabaseUrl: Env.supabaseUrl,
          supabaseAnonKey: Env.supabaseAnonKey,
          revenueCatKey: Env.revenueCatGoogleKey,
        ).isDemo,
        isTrue,
      );
    });
  });
}
