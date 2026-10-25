// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BrewLens';

  @override
  String get appTagline => 'Rate your coffee\'s look and save your cafés';

  @override
  String get demoBanner => 'Demo build — sample data';

  @override
  String get demoDialogTitle => 'Demo build';

  @override
  String get demoDialogBody =>
      'This is a review build. It doesn\'t connect to the server or the store.';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Try again';

  @override
  String get back => 'Back';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get signInButton => 'Sign in';

  @override
  String get noAccountPrompt => 'Don\'t have an account?';

  @override
  String get createAccountLink => 'Create one';

  @override
  String get signUpTitle => 'Create account';

  @override
  String get signUpReason =>
      'We need an account to save your history and cafés and protect your daily attempts';

  @override
  String passwordHint(int count) {
    return 'At least $count characters';
  }

  @override
  String get termsNotice =>
      'By signing up you agree to the Terms and Privacy Policy';

  @override
  String get signUpButton => 'Create account';

  @override
  String get haveAccountPrompt => 'Already have an account?';

  @override
  String get signInLink => 'Sign in';

  @override
  String get forgotTitle => 'Reset password';

  @override
  String get forgotBody => 'We\'ll send a link to your email';

  @override
  String get sendLinkButton => 'Send link';

  @override
  String resetSentBody(String email) {
    return 'We sent the link to $email. Check your spam folder too.';
  }

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get resendButton => 'Resend';

  @override
  String resendIn(int seconds) {
    return 'Resend ($seconds)';
  }

  @override
  String get errorInvalidEmail => 'Enter a valid email address';

  @override
  String errorPasswordShort(int count) {
    return 'Password must be at least $count characters';
  }

  @override
  String get errorPasswordMismatch => 'Passwords don\'t match';

  @override
  String get errorUnknown => 'Something went wrong, please try again';

  @override
  String get failureUnauthorized => 'Your session ended, please sign in again';

  @override
  String get failureInvalidCredentials => 'Incorrect email or password';

  @override
  String get failureEmailTaken =>
      'This email is already registered, sign in instead';

  @override
  String get failureLimitReached => 'You\'ve used your free attempts for today';

  @override
  String get failureFairUseReached => 'You\'ve reached the fair-use limit';

  @override
  String get failureServiceUnavailable =>
      'The service is unavailable right now. This attempt wasn\'t counted';

  @override
  String get failureImageTooLarge => 'The image is too large, try another one';

  @override
  String get failureOffline => 'No internet connection';

  @override
  String get failureSaveFailed => 'Couldn\'t save, please try again';

  @override
  String get failurePurchaseUnavailable =>
      'Purchases aren\'t available right now';

  @override
  String get invalidImageNotCoffee => 'This doesn\'t look like a cup of coffee';

  @override
  String get invalidImageTooDark =>
      'The photo is too dark, try better lighting';

  @override
  String get invalidImageBlurry =>
      'The photo is blurry, hold the phone steady and retake it';

  @override
  String get invalidImageNoCup =>
      'Make the whole cup visible from the top or side';

  @override
  String get invalidImageOther =>
      'Couldn\'t analyze the photo, try another one';

  @override
  String get homeWelcome => 'Welcome';

  @override
  String get homeHeroTitle => 'Snap your cup';

  @override
  String get homeHeroBody => 'Get an appearance score and a barista tip';

  @override
  String get homeEmpty => 'No reviews yet — snap your first cup';

  @override
  String usageRemainingDay(int remaining, int limit) {
    return 'Left today: $remaining of $limit';
  }

  @override
  String usageRemainingMonth(int remaining, int limit) {
    return 'Left this month: $remaining of $limit';
  }

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Sign out of your account?';
}
