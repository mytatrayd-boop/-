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

  @override
  String get close => 'Close';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get openCamera => 'Open camera';

  @override
  String get seeAll => 'See all';

  @override
  String get recentReviews => 'Recent reviews';

  @override
  String get favoriteShops => 'My favourite cafés';

  @override
  String get coffeeEspresso => 'Espresso';

  @override
  String get coffeeV60 => 'V60';

  @override
  String get coffeeFrenchPress => 'French press';

  @override
  String get visualLimitedNote =>
      'Visual analysis is limited for this type; your taste rating matters more';

  @override
  String get cameraGuide =>
      'Place the cup inside the circle, with light from the front';

  @override
  String get capturePhoto => 'Take photo';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get analyzing => 'The barista is examining your cup…';

  @override
  String get analyzingLong => 'A few more moments…';

  @override
  String get cameraDenied =>
      'We need the camera to photograph your cup and rate its look';

  @override
  String get galleryDenied =>
      'We need photo access to choose your cup\'s picture';

  @override
  String get openSettings => 'Open settings';

  @override
  String get attemptNotCounted => 'This attempt was not counted';

  @override
  String get retakePhoto => 'Take again';

  @override
  String get tryLater => 'Try later';

  @override
  String get resubmit => 'Send again';

  @override
  String get demoSimulateRejection => 'Simulate rejected image';

  @override
  String get resultTitle => 'Result';

  @override
  String get appearanceScore => 'Appearance score';

  @override
  String get scoreOutOf => '/10';

  @override
  String scoreSemantics(String score) {
    return 'Appearance score $score out of 10';
  }

  @override
  String get scoreNeedsCare => 'Needs care';

  @override
  String get scoreGood => 'Good';

  @override
  String get scoreExcellent => 'Excellent';

  @override
  String get scoreExceptional => 'Exceptional';

  @override
  String get baristaReport => 'Barista report';

  @override
  String tipLine(String tip) {
    return 'Tip for next time: $tip';
  }

  @override
  String get tasteRatingPrompt => 'After tasting, how would you rate it?';

  @override
  String ratingSemantics(int rating) {
    return 'Your rating $rating of 5';
  }

  @override
  String starSemantics(int count) {
    return '$count of 5';
  }

  @override
  String get userNotesLabel => 'Your notes (optional)';

  @override
  String get shopPrompt => 'Where did you have it? (optional)';

  @override
  String get addFavorite => 'Add to favourites';

  @override
  String get removeFavorite => 'Remove from favourites';

  @override
  String get addedToFavorites => 'Added to favourites';

  @override
  String get removedFromFavorites => 'Removed from favourites';

  @override
  String get undo => 'Undo';

  @override
  String get saveReview => 'Save review';

  @override
  String get savedDone => 'Saved';

  @override
  String get viewInHistory => 'View in history';

  @override
  String get discardTitle => 'Discard the result?';

  @override
  String get discardBody => 'The attempt stays counted';

  @override
  String get discard => 'Discard';

  @override
  String get stay => 'Stay';

  @override
  String get shopNameLabel => 'Café name';

  @override
  String get previousShops => 'Your previous cafés';

  @override
  String get hasSavedLocation => 'Has a saved location';

  @override
  String get saveMyLocation => 'Save my current location as the café\'s';

  @override
  String get locating => 'Finding your location…';

  @override
  String get locationSaved => 'Location saved';

  @override
  String get remove => 'Remove';

  @override
  String get usingSavedLocation => 'The saved location will be used';

  @override
  String get locationFailed =>
      'We couldn\'t find your location — only the name will be saved';

  @override
  String get enableLocation => 'Enable location';

  @override
  String get done => 'Done';

  @override
  String get noShop => 'No café';

  @override
  String get historyTitle => 'History';

  @override
  String get tabMyReviews => 'My reviews';

  @override
  String get tabFavorites => 'Favourite cafés';

  @override
  String get notRated => 'Not rated';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get favoritesEmpty =>
      'No favourite cafés yet — add one from the result screen';

  @override
  String get noRatingYet => '—';

  @override
  String shopRating(String rating) {
    return '★ $rating';
  }

  @override
  String shopScore(String score) {
    return 'Look $score';
  }

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
      zero: 'No reviews',
    );
    return '$_temp0';
  }

  @override
  String get openInGoogleMaps => 'Open in Google Maps';

  @override
  String get mapsFailed => 'Couldn\'t open maps';

  @override
  String get reviewDetailTitle => 'Review details';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get moreOptions => 'More options';

  @override
  String get deleteReview => 'Delete review';

  @override
  String get deleteReviewConfirm =>
      'Delete this review and its photo permanently?';

  @override
  String get delete => 'Delete';

  @override
  String get reviewDeleted => 'Review deleted';

  @override
  String get paywallRenews => 'Renews at midnight Riyadh time';

  @override
  String get failurePurchaseFailed =>
      'The purchase didn\'t go through. You weren\'t charged.';

  @override
  String get failureNoPurchases =>
      'No previous purchases found for this account';

  @override
  String get failureDeleteFailed => 'Couldn\'t delete. Please try again.';

  @override
  String get failureShareFailed =>
      'Couldn\'t create the card. Please try again.';

  @override
  String get shareCard => 'Share as card';

  @override
  String get shareCardBrand => 'Coffee look score';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get privacyBody =>
      'Short interim version until the full policy is published.\n\n• We collect your email only to create your account, with no display name.\n• Your cup photo is sent to an AI service (Google Gemini) to analyze its appearance, and is stored in your account only.\n• A café location is read once, only when you tap \"Save my location\", and is never attached to your reviews.\n• We use no tracking tools and never sell your data.\n• You can permanently delete your account, data and photos from Settings.';

  @override
  String get termsBody =>
      'Short interim version until the full terms are published.\n\n• The \"appearance score\" is an automated estimate of how the cup looks in the photo, not a professional judgment.\n• Two free analyses per day; subscribers get 20 per day under fair use.\n• Subscriptions renew automatically unless cancelled at least 24 hours before the period ends. Cancel in your store settings.\n• Don\'t upload photos you don\'t have the right to use.';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get subscribedTitle => 'You\'re subscribed';

  @override
  String get startCapturing => 'Start capturing';

  @override
  String priceSar(String amount) {
    return 'SAR $amount';
  }

  @override
  String get paywallTitleSettings => 'Subscribe to BrewLens';

  @override
  String get paywallTitleLimit => 'You\'ve used your free attempts for today';

  @override
  String get paywallBenefitLimit => '20 analyses per day';

  @override
  String get paywallBenefitReport => 'A barista report for every cup';

  @override
  String get paywallBenefitHistory => 'Unlimited history and favorites';

  @override
  String get planAnnual => 'Annual';

  @override
  String get planMonthly => 'Monthly';

  @override
  String perYear(String price) {
    return '$price / year';
  }

  @override
  String perMonth(String price) {
    return '$price / month';
  }

  @override
  String perMonthApprox(String price) {
    return '≈ $price per month';
  }

  @override
  String trialDays(int days) {
    return '$days days free';
  }

  @override
  String savePercent(int percent) {
    return 'Save $percent%';
  }

  @override
  String get startFreeTrial => 'Start free trial';

  @override
  String get subscribeNow => 'Subscribe now';

  @override
  String get subscriptionTerms =>
      'Renews automatically unless cancelled at least 24 hours before the period ends. Cancel in your store settings.';

  @override
  String get termsShort => 'Terms';

  @override
  String get privacyShort => 'Privacy';

  @override
  String get purchaseUnavailableDemo =>
      'Purchases aren\'t available in the demo build';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get navSettings => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get subscription => 'Subscription';

  @override
  String get subscriptionActive => 'Subscribed';

  @override
  String get subscriptionFree => 'Free';

  @override
  String get settingsApp => 'App';

  @override
  String get language => 'Language';

  @override
  String get settingsDemo => 'Demo build only';

  @override
  String get simulateSubscriber => 'Simulate subscriber';

  @override
  String get simulateSubscriberHint =>
      'Raises the limit to 20 analyses per day in the demo build';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get accountDeleted => 'Your account was deleted';

  @override
  String get deleteConfirmWord => 'DELETE';

  @override
  String get deleteAccountWarning =>
      'Your account and all your reviews, photos and favorites will be permanently deleted and can\'t be recovered';

  @override
  String get deleteAccountSubscriptionNote =>
      'Deleting doesn\'t cancel your subscription — cancel it in your store settings';

  @override
  String deleteConfirmLabel(String word) {
    return 'Type \"$word\" to confirm';
  }

  @override
  String get deleteAccountButton => 'Permanently delete my account';

  @override
  String get manageSubscription => 'Manage subscription in the store';
}
