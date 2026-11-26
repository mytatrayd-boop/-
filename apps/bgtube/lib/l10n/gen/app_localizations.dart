import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'BGTube'**
  String get appTitle;

  /// No description provided for @emptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابط يوتيوب لتشغيله'**
  String get emptyTitle;

  /// No description provided for @linkHint.
  ///
  /// In ar, this message translates to:
  /// **'رابط يوتيوب'**
  String get linkHint;

  /// No description provided for @pasteAndPlay.
  ///
  /// In ar, this message translates to:
  /// **'لصق وتشغيل'**
  String get pasteAndPlay;

  /// No description provided for @play.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف'**
  String get stop;

  /// No description provided for @speed.
  ///
  /// In ar, this message translates to:
  /// **'سرعة التشغيل'**
  String get speed;

  /// No description provided for @sleepTimer.
  ///
  /// In ar, this message translates to:
  /// **'مؤقت النوم'**
  String get sleepTimer;

  /// No description provided for @sleepMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{minutes} دقيقة'**
  String sleepMinutes(String minutes);

  /// No description provided for @sleepCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء المؤقت'**
  String get sleepCancel;

  /// No description provided for @speedValue.
  ///
  /// In ar, this message translates to:
  /// **'{value}×'**
  String speedValue(String value);

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @resolving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحضير…'**
  String get resolving;

  /// No description provided for @clipboardEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد رابط يوتيوب في الحافظة'**
  String get clipboardEmpty;

  /// No description provided for @errorInvalidLink.
  ///
  /// In ar, this message translates to:
  /// **'الرابط غير صالح. تأكد أنه رابط فيديو من يوتيوب.'**
  String get errorInvalidLink;

  /// No description provided for @errorExtraction.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر استخراج الصوت من هذا الفيديو. جرّب مرة أخرى.'**
  String get errorExtraction;

  /// No description provided for @errorNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال بالإنترنت. تحقق من الشبكة وأعد المحاولة.'**
  String get errorNetwork;

  /// No description provided for @errorRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'يوتيوب يقيّد الطلبات من شبكتك الآن. انتظر قليلاً ثم أعد المحاولة.'**
  String get errorRateLimited;

  /// No description provided for @errorPlayback.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل الصوت. أعد المحاولة.'**
  String get errorPlayback;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In ar, this message translates to:
  /// **'تُطبَّق فوراً وتبقى محفوظة.'**
  String get settingsLanguageHint;

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'حول'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsPersonalUse.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق للاستخدام الشخصي فقط، وليس للنشر.'**
  String get settingsPersonalUse;

  /// No description provided for @accountTitle.
  ///
  /// In ar, this message translates to:
  /// **'الحساب'**
  String get accountTitle;

  /// No description provided for @accountSignedOut.
  ///
  /// In ar, this message translates to:
  /// **'غير مسجّل الدخول'**
  String get accountSignedOut;

  /// No description provided for @accountSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'متصل بحساب جوجل'**
  String get accountSignedIn;

  /// No description provided for @signIn.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج؟'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'ستُمسح بيانات الدخول من هذا الجهاز.'**
  String get signOutConfirmBody;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @loginExplain.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لعرض قوائمك واشتراكاتك وإعجاباتك'**
  String get loginExplain;

  /// No description provided for @loginContinue.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة بحساب جوجل'**
  String get loginContinue;

  /// No description provided for @loginNotNow.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get loginNotNow;

  /// No description provided for @loginNoPassword.
  ///
  /// In ar, this message translates to:
  /// **'التطبيق لا يرى كلمة مرورك'**
  String get loginNoPassword;

  /// No description provided for @sessionExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت جلستك، سجّل الدخول من جديد'**
  String get sessionExpired;

  /// No description provided for @errorNotSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لعرض حسابك'**
  String get errorNotSignedIn;

  /// No description provided for @errorSignIn.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الدخول. تحقق من الاتصال وحاول مرة أخرى'**
  String get errorSignIn;

  /// No description provided for @errorSignInUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'الدخول غير مفعّل بعد في هذه النسخة'**
  String get errorSignInUnavailable;

  /// No description provided for @errorSignOut.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تسجيل الخروج. حاول مرة أخرى'**
  String get errorSignOut;

  /// No description provided for @riskTitle.
  ///
  /// In ar, this message translates to:
  /// **'قبل أول دخول'**
  String get riskTitle;

  /// No description provided for @riskBody.
  ///
  /// In ar, this message translates to:
  /// **'هذا التطبيق يستخرج صوت يوتيوب بطريقة غير رسمية تخالف شروط يوتيوب. قد يؤدي ذلك إلى حجب شبكتك أو تقييد حسابك أو مشروع Google Cloud. الاستخراج منفصل عن حسابك ولا يتلقى أي رمز دخول، لكن الخطر يبقى قائماً.\n\nاستخدمه شخصياً فقط، ويُنصح بحساب لا تعتمد عليه في عمل حرج.\n\nستعرض جوجل تحذير «تطبيق غير موثّق»: اختر «متقدم» ثم «المتابعة».'**
  String get riskBody;

  /// No description provided for @riskAccept.
  ///
  /// In ar, this message translates to:
  /// **'أقرّ وأتابع'**
  String get riskAccept;

  /// No description provided for @errorQueueStopped.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل باقي الطابور. أعد المحاولة.'**
  String get errorQueueStopped;

  /// No description provided for @next.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get previous;

  /// No description provided for @queueTitle.
  ///
  /// In ar, this message translates to:
  /// **'الطابور'**
  String get queueTitle;

  /// No description provided for @queueNextUp.
  ///
  /// In ar, this message translates to:
  /// **'التالي: {title}'**
  String queueNextUp(String title);

  /// No description provided for @queueRemaining.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا شيء متبقٍ} =1{واحد متبقٍ} =2{اثنان متبقيان} few{{count} متبقية} many{{count} متبقياً} other{{count} متبقٍ}}'**
  String queueRemaining(int count);

  /// No description provided for @itemsSummary.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مقاطع} =1{مقطع واحد} =2{مقطعان} few{{count} مقاطع} many{{count} مقطعاً} other{{count} مقطع}} · {duration}'**
  String itemsSummary(int count, String duration);

  /// No description provided for @itemsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا مقاطع} =1{مقطع واحد} =2{مقطعان} few{{count} مقاطع} many{{count} مقطعاً} other{{count} مقطع}}'**
  String itemsCount(int count);

  /// No description provided for @queueNowPlaying.
  ///
  /// In ar, this message translates to:
  /// **'يعمل الآن'**
  String get queueNowPlaying;

  /// No description provided for @queueEmpty.
  ///
  /// In ar, this message translates to:
  /// **'الطابور فارغ'**
  String get queueEmpty;

  /// No description provided for @queueNothingAfter.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء بعده. اضغط ⋮ على أي مقطع واختر «أضف للنهاية»'**
  String get queueNothingAfter;

  /// No description provided for @queueFailedItem.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيله، تم تخطّيه'**
  String get queueFailedItem;

  /// No description provided for @queueSkippedSnack.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل «{title}»، تم الانتقال للتالي'**
  String queueSkippedSnack(String title);

  /// No description provided for @queueRemoved.
  ///
  /// In ar, this message translates to:
  /// **'حُذف من الطابور'**
  String get queueRemoved;

  /// No description provided for @queueClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح الطابور'**
  String get queueClear;

  /// No description provided for @queueClearConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسح الطابور؟'**
  String get queueClearConfirmTitle;

  /// No description provided for @queueClearConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيبقى المقطع الحالي يعمل.'**
  String get queueClearConfirmBody;

  /// No description provided for @queueClearAction.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get queueClearAction;

  /// No description provided for @queueCleared.
  ///
  /// In ar, this message translates to:
  /// **'مُسح الطابور'**
  String get queueCleared;

  /// No description provided for @undo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get undo;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @queueSaveAsPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'حفظ كقائمة'**
  String get queueSaveAsPlaylist;

  /// No description provided for @queueSaveAsLocalPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'حفظ كقائمة محلية'**
  String get queueSaveAsLocalPlaylist;

  /// No description provided for @queueDefaultPlaylistName.
  ///
  /// In ar, this message translates to:
  /// **'طابور {date}'**
  String queueDefaultPlaylistName(String date);

  /// No description provided for @playlistNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم القائمة'**
  String get playlistNameLabel;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @playlistSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت قائمة «{name}»'**
  String playlistSaved(String name);

  /// No description provided for @open.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get open;

  /// No description provided for @queueRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة من الطابور'**
  String get queueRemove;

  /// No description provided for @queueMoveNext.
  ///
  /// In ar, this message translates to:
  /// **'نقل ليكون التالي'**
  String get queueMoveNext;

  /// No description provided for @moveUp.
  ///
  /// In ar, this message translates to:
  /// **'نقل للأعلى'**
  String get moveUp;

  /// No description provided for @moveDown.
  ///
  /// In ar, this message translates to:
  /// **'نقل للأسفل'**
  String get moveDown;

  /// No description provided for @dragToReorder.
  ///
  /// In ar, this message translates to:
  /// **'اسحب لإعادة الترتيب'**
  String get dragToReorder;

  /// No description provided for @actionPlayNow.
  ///
  /// In ar, this message translates to:
  /// **'شغّل الآن'**
  String get actionPlayNow;

  /// No description provided for @actionPlayNext.
  ///
  /// In ar, this message translates to:
  /// **'شغّل التالي'**
  String get actionPlayNext;

  /// No description provided for @actionAddToEnd.
  ///
  /// In ar, this message translates to:
  /// **'أضف للنهاية'**
  String get actionAddToEnd;

  /// No description provided for @actionAddToLocalPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى قائمة محلية…'**
  String get actionAddToLocalPlaylist;

  /// No description provided for @snackPlayNext.
  ///
  /// In ar, this message translates to:
  /// **'سيُشغَّل التالي: {title}'**
  String snackPlayNext(String title);

  /// No description provided for @snackAddedToEnd.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى نهاية الطابور'**
  String get snackAddedToEnd;

  /// No description provided for @snackAddedCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أُضيف مقطع واحد إلى الطابور} =2{أُضيف مقطعان إلى الطابور} few{أُضيف {count} مقاطع إلى الطابور} many{أُضيف {count} مقطعاً إلى الطابور} other{أُضيف {count} مقطع إلى الطابور}}'**
  String snackAddedCount(int count);

  /// No description provided for @queueTruncated.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, few{الطابور ممتلئ ({count} مقاطع)؛ لم يُضف الباقي} many{الطابور ممتلئ ({count} مقطعاً)؛ لم يُضف الباقي} other{الطابور ممتلئ ({count} مقطع)؛ لم يُضف الباقي}}'**
  String queueTruncated(int count);

  /// No description provided for @untitledVideo.
  ///
  /// In ar, this message translates to:
  /// **'مقطع من يوتيوب'**
  String get untitledVideo;

  /// No description provided for @localPlaylists.
  ///
  /// In ar, this message translates to:
  /// **'قوائمي المحلية'**
  String get localPlaylists;

  /// No description provided for @newPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'قائمة جديدة'**
  String get newPlaylist;

  /// No description provided for @onDevice.
  ///
  /// In ar, this message translates to:
  /// **'على الجهاز'**
  String get onDevice;

  /// No description provided for @playlistsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تنشئ قوائم بعد. احفظ الطابور أو أنشئ قائمة'**
  String get playlistsEmpty;

  /// No description provided for @playlistEmpty.
  ///
  /// In ar, this message translates to:
  /// **'القائمة فارغة. أضف مقاطع من ⋮ على أي مقطع'**
  String get playlistEmpty;

  /// No description provided for @playlistsLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح القوائم المحلية'**
  String get playlistsLoadError;

  /// No description provided for @rename.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تسمية'**
  String get rename;

  /// No description provided for @deletePlaylistTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف قائمة «{name}»؟'**
  String deletePlaylistTitle(String name);

  /// No description provided for @deletePlaylistBody.
  ///
  /// In ar, this message translates to:
  /// **'لن تُحذف المقاطع من يوتيوب.'**
  String get deletePlaylistBody;

  /// No description provided for @playAll.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل الكل'**
  String get playAll;

  /// No description provided for @addWholeList.
  ///
  /// In ar, this message translates to:
  /// **'أضف القائمة كلها'**
  String get addWholeList;

  /// No description provided for @addedToPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى «{name}»'**
  String addedToPlaylist(String name);

  /// No description provided for @alreadyInPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'موجود في «{name}» بالفعل'**
  String alreadyInPlaylist(String name);

  /// No description provided for @removedFromPlaylist.
  ///
  /// In ar, this message translates to:
  /// **'حُذف من القائمة'**
  String get removedFromPlaylist;

  /// No description provided for @moreActions.
  ///
  /// In ar, this message translates to:
  /// **'مزيد من الخيارات'**
  String get moreActions;

  /// No description provided for @saveFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ. حاول مرة أخرى'**
  String get saveFailed;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In ar, this message translates to:
  /// **'المكتبة'**
  String get navLibrary;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث أو الصق رابطاً'**
  String get searchHint;

  /// No description provided for @searchAction.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get searchAction;

  /// No description provided for @homeStartHint.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بالبحث أو الصق رابطاً'**
  String get homeStartHint;

  /// No description provided for @guestSignInPrompt.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لترى أحدث فيديوهات اشتراكاتك وتبحث في يوتيوب'**
  String get guestSignInPrompt;

  /// No description provided for @searchNeedsSignIn.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول للبحث في يوتيوب. يمكنك لصق رابط دون دخول.'**
  String get searchNeedsSignIn;

  /// No description provided for @feedTitle.
  ///
  /// In ar, this message translates to:
  /// **'أحدث فيديوهات اشتراكاتك'**
  String get feedTitle;

  /// No description provided for @feedEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء هنا بعد. فيديوهات القنوات التي تشترك فيها تظهر هنا.'**
  String get feedEmpty;

  /// No description provided for @searchResultsFor.
  ///
  /// In ar, this message translates to:
  /// **'نتائج «{query}»'**
  String searchResultsFor(String query);

  /// No description provided for @searchNoResults.
  ///
  /// In ar, this message translates to:
  /// **'لا نتائج لـ «{query}». جرّب كلمات أخرى'**
  String searchNoResults(String query);

  /// No description provided for @closeSearch.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق البحث'**
  String get closeSearch;

  /// No description provided for @staleBanner.
  ///
  /// In ar, this message translates to:
  /// **'هذه نسخة محفوظة'**
  String get staleBanner;

  /// No description provided for @errorQuotaExceeded.
  ///
  /// In ar, this message translates to:
  /// **'انتهت حصة البحث اليوم. تتجدد غداً. يمكنك لصق رابط أو تشغيل المكتبة.'**
  String get errorQuotaExceeded;

  /// No description provided for @errorApi.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تحميل البيانات من يوتيوب. حاول مرة أخرى.'**
  String get errorApi;

  /// No description provided for @pasteLinkAction.
  ///
  /// In ar, this message translates to:
  /// **'الصق رابطاً'**
  String get pasteLinkAction;

  /// No description provided for @channelKind.
  ///
  /// In ar, this message translates to:
  /// **'قناة'**
  String get channelKind;

  /// No description provided for @channelEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء هنا بعد'**
  String get channelEmpty;

  /// No description provided for @miniPlaybackFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التشغيل'**
  String get miniPlaybackFailed;

  /// No description provided for @openPlayer.
  ///
  /// In ar, this message translates to:
  /// **'فتح المشغّل'**
  String get openPlayer;

  /// No description provided for @accountSignedInAs.
  ///
  /// In ar, this message translates to:
  /// **'متصل: {name}'**
  String accountSignedInAs(String name);

  /// No description provided for @settingsQuota.
  ///
  /// In ar, this message translates to:
  /// **'حصة البحث'**
  String get settingsQuota;

  /// No description provided for @quotaSearchesLeft.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا بحث متبقٍ اليوم} =1{بحث واحد متبقٍ اليوم} =2{بحثان متبقيان اليوم} few{{count} عمليات بحث متبقية اليوم} many{{count} عملية بحث متبقية اليوم} other{{count} عملية بحث متبقية اليوم}}'**
  String quotaSearchesLeft(int count);

  /// No description provided for @quotaUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'غير متاح'**
  String get quotaUnavailable;

  /// No description provided for @errorGeneralQuotaExceeded.
  ///
  /// In ar, this message translates to:
  /// **'انتهت حصة يوتيوب اليومية للقوائم والقنوات. تتجدد غداً. يمكنك لصق رابط أو تشغيل المكتبة.'**
  String get errorGeneralQuotaExceeded;

  /// No description provided for @errorInsufficientPermissions.
  ///
  /// In ar, this message translates to:
  /// **'لم يمنح حسابك التطبيق صلاحية قراءة يوتيوب. امنحها للمتابعة.'**
  String get errorInsufficientPermissions;

  /// No description provided for @grantPermission.
  ///
  /// In ar, this message translates to:
  /// **'امنح الصلاحية'**
  String get grantPermission;

  /// No description provided for @loadMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get loadMore;

  /// No description provided for @quotaSearchUsage.
  ///
  /// In ar, this message translates to:
  /// **'{used} من {limit} عملية بحث اليوم'**
  String quotaSearchUsage(int used, int limit);

  /// No description provided for @quotaGeneralUsage.
  ///
  /// In ar, this message translates to:
  /// **'القوائم والقنوات: {used} من {limit} وحدة'**
  String quotaGeneralUsage(int used, int limit);

  /// No description provided for @quotaResetNote.
  ///
  /// In ar, this message translates to:
  /// **'تتجدد الحصتان عند منتصف ليل المحيط الهادئ'**
  String get quotaResetNote;

  /// No description provided for @errorPlaylistNeedsSignIn.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الدخول لإضافة قوائم يوتيوب. روابط الفيديو تعمل دون دخول.'**
  String get errorPlaylistNeedsSignIn;

  /// No description provided for @libraryYouTubePlaylists.
  ///
  /// In ar, this message translates to:
  /// **'قوائم يوتيوب'**
  String get libraryYouTubePlaylists;

  /// No description provided for @libraryLikes.
  ///
  /// In ar, this message translates to:
  /// **'الإعجابات'**
  String get libraryLikes;

  /// No description provided for @librarySubscriptions.
  ///
  /// In ar, this message translates to:
  /// **'الاشتراكات'**
  String get librarySubscriptions;

  /// No description provided for @libraryFavorites.
  ///
  /// In ar, this message translates to:
  /// **'المفضلة'**
  String get libraryFavorites;

  /// No description provided for @libraryHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get libraryHistory;

  /// No description provided for @libraryEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء هنا بعد'**
  String get libraryEmpty;

  /// No description provided for @libraryLocalLoadError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح هذا القسم من التخزين'**
  String get libraryLocalLoadError;

  /// No description provided for @favoritesEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تضف شيئاً بعد. اضغط ⋮ على أي فيديو'**
  String get favoritesEmpty;

  /// No description provided for @historyEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لم تشغّل شيئاً بعد'**
  String get historyEmpty;

  /// No description provided for @addToFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أضف إلى المفضلة'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أزل من المفضلة'**
  String get removeFromFavorites;

  /// No description provided for @addedToFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف إلى المفضلة'**
  String get addedToFavorites;

  /// No description provided for @removedFromFavorites.
  ///
  /// In ar, this message translates to:
  /// **'أُزيل من المفضلة'**
  String get removedFromFavorites;

  /// No description provided for @removeFromHistory.
  ///
  /// In ar, this message translates to:
  /// **'حذف من السجل'**
  String get removeFromHistory;

  /// No description provided for @removedFromHistory.
  ///
  /// In ar, this message translates to:
  /// **'حُذف من السجل'**
  String get removedFromHistory;

  /// No description provided for @clearHistory.
  ///
  /// In ar, this message translates to:
  /// **'مسح السجل'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'مسح السجل؟'**
  String get clearHistoryConfirmTitle;

  /// No description provided for @clearHistoryConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف سجل التشغيل من هذا الجهاز. لا يؤثر على يوتيوب.'**
  String get clearHistoryConfirmBody;

  /// No description provided for @clearHistoryAction.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get clearHistoryAction;

  /// No description provided for @historyCleared.
  ///
  /// In ar, this message translates to:
  /// **'مُسح السجل'**
  String get historyCleared;

  /// No description provided for @playlistAdding.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إضافة القائمة…'**
  String get playlistAdding;

  /// No description provided for @playlistAddingProgress.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ إضافة القائمة… {fetched} من {total}'**
  String playlistAddingProgress(int fetched, int total);

  /// No description provided for @playlistAddedPartial.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف {added} من {total}. تعذّر جلب الباقي'**
  String playlistAddedPartial(int added, int total);

  /// No description provided for @playlistAddedPartialUnknown.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أُضيف مقطع واحد} =2{أُضيف مقطعان} few{أُضيف {count} مقاطع} many{أُضيف {count} مقطعاً} other{أُضيف {count} مقطع}}. تعذّر جلب الباقي'**
  String playlistAddedPartialUnknown(int count);

  /// No description provided for @errorPlaylistWatchLater.
  ///
  /// In ar, this message translates to:
  /// **'قائمة «المشاهدة لاحقاً» وسجل يوتيوب لا تتيحهما واجهة يوتيوب الرسمية. الصق رابط فيديو أو قائمة عادية.'**
  String get errorPlaylistWatchLater;

  /// No description provided for @errorPlaylistMix.
  ///
  /// In ar, this message translates to:
  /// **'قوائم المزيج (Mix) يولّدها يوتيوب ولا تتيحها واجهته الرسمية. الصق رابط فيديو منها.'**
  String get errorPlaylistMix;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
