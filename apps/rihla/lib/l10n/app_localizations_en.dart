// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Rihla';

  @override
  String get homeTitle => 'Home';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsEmpty => 'Settings are under construction.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get backToHome => 'Back to home';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody =>
      'We could not find this page. Go back to the home screen and try again.';

  @override
  String get permTitle => 'Permissions';

  @override
  String permStepOf(int n, int total) {
    return 'Step $n of $total';
  }

  @override
  String get permCameraTitle => 'Camera';

  @override
  String get permCameraReason => 'To film your road.';

  @override
  String get permLocationTitle => 'Location';

  @override
  String get permLocationReason => 'To draw and measure your route on the map.';

  @override
  String get permMicTitle => 'Microphone';

  @override
  String get permMicReason =>
      'To record the trip\'s sound (optional, and you can mute it).';

  @override
  String get permPrivacy =>
      'Everything stays on your phone. No accounts, no uploads.';

  @override
  String get permAllow => 'Allow';

  @override
  String get permNotNow => 'Not now';

  @override
  String get permGranted => 'Allowed';

  @override
  String get permCameraDenied => 'The trip will not work without the camera.';

  @override
  String get permLocationDenied =>
      'The route cannot be drawn without location, so the trip will not work.';

  @override
  String get permMicDenied => 'The video will be recorded without sound.';

  @override
  String get permPermanentHint =>
      'The app can no longer ask for this permission. Enable it in your phone settings.';

  @override
  String get permLocationApproximate =>
      'Approximate location is not enough. The route needs precise location; turn it on in your phone settings.';

  @override
  String get permOpenPhoneSettings => 'Open phone settings';

  @override
  String get permRetry => 'Try again';

  @override
  String get permContinueNoAudio => 'Continue without sound';

  @override
  String get permAudioUnavailable => 'Audio unavailable';

  @override
  String get permStartBlocked => 'Allow camera and location to start a trip.';

  @override
  String permIllustration(String name) {
    return 'Illustration for the $name permission';
  }

  @override
  String get mapLocating => 'Finding your location...';

  @override
  String get mapRecenter => 'Recenter';

  @override
  String get startTrip => 'Start trip';

  @override
  String get stopTrip => 'Stop trip';

  @override
  String get mute => 'Mute audio';

  @override
  String get unmute => 'Unmute';

  @override
  String get audioOn => 'Audio on';

  @override
  String get audioMuted => 'Audio muted';

  @override
  String get audioMutedChip => 'Muted';

  @override
  String get qualityTitle => 'Video quality';

  @override
  String get gpsGood => 'GPS good';

  @override
  String get gpsWeak => 'Weak GPS signal';

  @override
  String get gpsSearching => 'Finding location';

  @override
  String get offlineBanner => 'No internet: the map will not update';

  @override
  String get cameraOpening => 'Getting the camera ready...';

  @override
  String get cameraError =>
      'Could not open the camera. Close other apps that use it.';

  @override
  String get homeOpenPermissions => 'Open permissions';

  @override
  String hudDistanceKm(String km) {
    return '$km km';
  }
}
