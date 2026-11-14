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

  @override
  String get countdownCancelHint => 'Tap to cancel';

  @override
  String countdownLabel(int n) {
    return 'Countdown $n';
  }

  @override
  String get stopConfirmTitle => 'End the trip?';

  @override
  String get stopConfirmBody => 'Recording continues until you confirm.';

  @override
  String get stopConfirmEnd => 'End and save';

  @override
  String get stopConfirmContinue => 'Keep recording';

  @override
  String get savingTrip => 'Saving...';

  @override
  String get savingDoNotClose => 'Do not close the app';

  @override
  String get startFailed => 'Could not start recording. Try again.';

  @override
  String get summarySaved => 'Your trip is saved';

  @override
  String get summaryDuration => 'Duration';

  @override
  String get summaryDistance => 'Distance';

  @override
  String get summaryVideoFailed =>
      'The route is saved but the video could not be saved';

  @override
  String get summaryInterruptedBackground =>
      'The trip stopped because the app left the screen. What was recorded is saved.';

  @override
  String get summaryInterruptedCamera =>
      'The trip stopped because of a camera error. What was recorded is saved.';

  @override
  String get summaryInterruptedWrite =>
      'The trip stopped because of a write error. What was recorded is saved.';

  @override
  String get summaryInterruptedStorage =>
      'The trip stopped because storage is low. What was recorded is saved.';

  @override
  String get summaryInterruptedOther =>
      'The trip stopped unexpectedly. What was recorded is saved.';

  @override
  String get summaryNewTrip => 'New trip';

  @override
  String get summaryViewTrip => 'View trip';

  @override
  String get summaryLoadError => 'Could not open the trip';

  @override
  String get summaryGallerySaving => 'Saving the video to your photo album…';

  @override
  String get summaryGallerySaved => 'The video is saved in your photo album';

  @override
  String get summaryGalleryFailed =>
      'Could not save the video to your photo album';

  @override
  String get summaryGalleryRetry => 'Try again';

  @override
  String get summaryDbError =>
      'The trip ended but some of its details could not be saved';

  @override
  String get tripsTitle => 'My trips';

  @override
  String get tripsNew => 'New trip';

  @override
  String get tripsEmpty => 'No trips yet';

  @override
  String get tripsEmptyHint =>
      'Start your first trip and it will show up here.';

  @override
  String get tripsLoadError => 'Could not load trips';

  @override
  String get retry => 'Try again';

  @override
  String get tripStatusCompleted => 'Completed';

  @override
  String get tripStatusInterrupted => 'Stopped automatically';

  @override
  String get tripStatusRecording => 'Unfinished';

  @override
  String get tripNoVideoChip => 'Video unavailable';

  @override
  String get tripDetailsTitle => 'Trip details';

  @override
  String get tripDate => 'Date';

  @override
  String get tripPlayVideo => 'Play video';

  @override
  String get tripVideoMissing => 'The video is not on this phone';

  @override
  String get tripPlayFailed => 'Could not open the video';

  @override
  String get tripShare => 'Share';

  @override
  String get tripDelete => 'Delete';

  @override
  String get tripDeleteTitle => 'Delete this trip?';

  @override
  String get tripDeleteBody =>
      'The route will be removed from the app. The video stays in your phone\'s gallery.';

  @override
  String get cancel => 'Cancel';

  @override
  String get tripDeleted => 'Trip deleted';

  @override
  String get tripDeleteFailed => 'Could not delete the trip';

  @override
  String get tripNoRoute => 'This trip has no route points';

  @override
  String get shareTitle => 'Share trip';

  @override
  String get shareVideoTitle => 'Send the video';

  @override
  String get shareVideoDesc => 'One video with the picture and the route';

  @override
  String get shareVideoWarning =>
      'WhatsApp may compress large videos and lower their quality.';

  @override
  String get shareVideoMissing => 'The video is not on this phone';

  @override
  String get shareRouteTitle => 'Send my route on the map';

  @override
  String get shareRouteDesc => 'A Google Maps link or a GPX file';

  @override
  String get shareLinkTitle => 'Google Maps link';

  @override
  String get shareLinkNote =>
      'The route is approximate: reduced to a few points. The GPX file has the full route.';

  @override
  String get shareLinkShare => 'Share the link';

  @override
  String get shareLinkOpen => 'Open in Google Maps';

  @override
  String get shareGpxTitle => 'GPX file';

  @override
  String get shareGpxDesc => 'Accurate and complete, opens in route apps';

  @override
  String get shareGpxShare => 'Share the file';

  @override
  String get shareNoRoute => 'There is no route to share';

  @override
  String get shareFailed => 'Sharing failed';

  @override
  String get openMapsFailed => 'Could not open Google Maps';

  @override
  String shareLinkMessage(String url) {
    return 'My route on the map: $url';
  }
}
