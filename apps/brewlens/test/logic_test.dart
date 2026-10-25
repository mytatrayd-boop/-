import 'package:brewlens/app/failure_text.dart';
import 'package:brewlens/app/providers.dart';
import 'package:brewlens/app/router.dart';
import 'package:brewlens/domain/models/analysis_result.dart';
import 'package:brewlens/domain/models/app_failure.dart';
import 'package:brewlens/domain/models/coffee_type.dart';
import 'package:brewlens/domain/validators.dart';
import 'package:brewlens/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLocale', () {
    test('Arabic device -> ar', () {
      expect(resolveLocale(const [Locale('ar', 'SA')]), const Locale('ar'));
    });
    test('English device -> en', () {
      expect(resolveLocale(const [Locale('en', 'US')]), const Locale('en'));
    });
    test('unsupported or missing -> ar', () {
      expect(resolveLocale(const [Locale('fr')]), const Locale('ar'));
      expect(resolveLocale(null), const Locale('ar'));
    });
  });

  group('authRedirect', () {
    test('signed out: protected routes go to login, auth routes stay', () {
      expect(authRedirect(signedIn: false, path: Routes.home), Routes.login);
      expect(authRedirect(signedIn: false, path: '/history'), Routes.login);
      expect(authRedirect(signedIn: false, path: Routes.signup), isNull);
      expect(authRedirect(signedIn: false, path: Routes.forgot), isNull);
    });
    test('signed in: auth routes go home', () {
      expect(authRedirect(signedIn: true, path: Routes.login), Routes.home);
      expect(authRedirect(signedIn: true, path: Routes.home), isNull);
    });
  });

  group('validators', () {
    test('email', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('a@b'), isFalse);
      expect(isValidEmail('a b@c.com'), isFalse);
    });
    test('password minimum: 6 in demo, 8 real', () {
      expect(minPasswordLength(isDemo: true), 6);
      expect(minPasswordLength(isDemo: false), 8);
    });
  });

  group('failureText', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final en = lookupAppLocalizations(const Locale('en'));

    test('maps codes to translated text', () {
      expect(failureText(ar, const AppFailure(FailureCode.invalidCredentials)),
          'البريد أو كلمة المرور غير صحيحة');
      expect(failureText(en, const AppFailure(FailureCode.offline)), 'No internet connection');
      for (final code in [FailureCode.analysisFailed, FailureCode.timeout, FailureCode.servicePaused]) {
        expect(failureText(ar, AppFailure(code)), 'الخدمة غير متاحة الآن، لم تُحتسب المحاولة');
      }
    });

    test('invalid image uses the reason text', () {
      expect(failureText(ar, const AppFailure.invalidImage(InvalidImageReason.tooDark)),
          'الصورة مظلمة، جرّب إضاءة أفضل');
    });

    test('unknown errors use a generic message, not the raw error', () {
      expect(failureText(en, Exception('server says boom')), en.errorUnknown);
    });
  });

  group('AnalysisResult.fromJson', () {
    test('valid result', () {
      final r = AnalysisResult.fromJson({
        'image_valid': true,
        'reason': null,
        'score': 7.5,
        'notes': ['a', 'b', 'c'],
        'tip': 't',
      });
      expect(r.score, 7.5);
      expect(r.notes, hasLength(3));
    });
    test('rejected image', () {
      final r = AnalysisResult.fromJson({
        'image_valid': false,
        'reason': 'blurry',
        'score': null,
        'notes': [],
        'tip': null,
      });
      expect(r.imageValid, isFalse);
      expect(r.reason, InvalidImageReason.blurry);
    });
    test('contract violations throw', () {
      Map<String, dynamic> valid() => {
            'image_valid': true,
            'score': 7.5,
            'notes': ['a', 'b', 'c'],
            'tip': 't',
          };
      expect(() => AnalysisResult.fromJson(valid()..['score'] = 7.3), throwsFormatException);
      expect(() => AnalysisResult.fromJson(valid()..['score'] = 11), throwsFormatException);
      expect(() => AnalysisResult.fromJson(valid()..['notes'] = ['a']), throwsFormatException);
      expect(() => AnalysisResult.fromJson({'image_valid': false, 'reason': 'x'}),
          throwsFormatException);
    });
  });

  test('V60 and French press are visually limited', () {
    expect(CoffeeType.espresso.isVisualLimited, isFalse);
    expect(CoffeeType.v60.isVisualLimited, isTrue);
    expect(CoffeeType.frenchPress.isVisualLimited, isTrue);
    expect(CoffeeType.fromWire('french_press'), CoffeeType.frenchPress);
  });
}
