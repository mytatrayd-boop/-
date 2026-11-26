// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'BGTube';

  @override
  String get emptyTitle => 'الصق رابط يوتيوب لتشغيله';

  @override
  String get linkHint => 'رابط يوتيوب';

  @override
  String get pasteAndPlay => 'لصق وتشغيل';

  @override
  String get play => 'تشغيل';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get stop => 'إيقاف';

  @override
  String get speed => 'سرعة التشغيل';

  @override
  String get sleepTimer => 'مؤقت النوم';

  @override
  String sleepMinutes(String minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get sleepCancel => 'إلغاء المؤقت';

  @override
  String speedValue(String value) {
    return '$value×';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get resolving => 'جارٍ التحضير…';

  @override
  String get clipboardEmpty => 'لا يوجد رابط يوتيوب في الحافظة';

  @override
  String get errorInvalidLink =>
      'الرابط غير صالح. تأكد أنه رابط فيديو من يوتيوب.';

  @override
  String get errorExtraction =>
      'تعذّر استخراج الصوت من هذا الفيديو. جرّب مرة أخرى.';

  @override
  String get errorNetwork =>
      'تعذّر الاتصال بالإنترنت. تحقق من الشبكة وأعد المحاولة.';

  @override
  String get errorRateLimited =>
      'يوتيوب يقيّد الطلبات من شبكتك الآن. انتظر قليلاً ثم أعد المحاولة.';

  @override
  String get errorPlayback => 'تعذّر تشغيل الصوت. أعد المحاولة.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLanguageHint => 'تُطبَّق فوراً وتبقى محفوظة.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsAbout => 'حول';

  @override
  String settingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsPersonalUse => 'تطبيق للاستخدام الشخصي فقط، وليس للنشر.';

  @override
  String get accountTitle => 'الحساب';

  @override
  String get accountSignedOut => 'غير مسجّل الدخول';

  @override
  String get accountSignedIn => 'متصل بحساب جوجل';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirmTitle => 'تسجيل الخروج؟';

  @override
  String get signOutConfirmBody => 'ستُمسح بيانات الدخول من هذا الجهاز.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get loginExplain => 'سجّل الدخول لعرض قوائمك واشتراكاتك وإعجاباتك';

  @override
  String get loginContinue => 'المتابعة بحساب جوجل';

  @override
  String get loginNotNow => 'ليس الآن';

  @override
  String get loginNoPassword => 'التطبيق لا يرى كلمة مرورك';

  @override
  String get sessionExpired => 'انتهت جلستك، سجّل الدخول من جديد';

  @override
  String get errorNotSignedIn => 'سجّل الدخول لعرض حسابك';

  @override
  String get errorSignIn =>
      'تعذّر تسجيل الدخول. تحقق من الاتصال وحاول مرة أخرى';

  @override
  String get errorSignInUnavailable => 'الدخول غير مفعّل بعد في هذه النسخة';

  @override
  String get errorSignOut => 'تعذّر تسجيل الخروج. حاول مرة أخرى';

  @override
  String get riskTitle => 'قبل أول دخول';

  @override
  String get riskBody =>
      'هذا التطبيق يستخرج صوت يوتيوب بطريقة غير رسمية تخالف شروط يوتيوب. قد يؤدي ذلك إلى حجب شبكتك أو تقييد حسابك أو مشروع Google Cloud. الاستخراج منفصل عن حسابك ولا يتلقى أي رمز دخول، لكن الخطر يبقى قائماً.\n\nاستخدمه شخصياً فقط، ويُنصح بحساب لا تعتمد عليه في عمل حرج.\n\nستعرض جوجل تحذير «تطبيق غير موثّق»: اختر «متقدم» ثم «المتابعة».';

  @override
  String get riskAccept => 'أقرّ وأتابع';

  @override
  String get errorQueueStopped => 'تعذّر تشغيل باقي الطابور. أعد المحاولة.';

  @override
  String get next => 'التالي';

  @override
  String get previous => 'السابق';

  @override
  String get queueTitle => 'الطابور';

  @override
  String queueNextUp(String title) {
    return 'التالي: $title';
  }

  @override
  String queueRemaining(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString متبقٍ',
      many: '$countString متبقياً',
      few: '$countString متبقية',
      two: 'اثنان متبقيان',
      one: 'واحد متبقٍ',
      zero: 'لا شيء متبقٍ',
    );
    return '$_temp0';
  }

  @override
  String itemsSummary(int count, String duration) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString مقطع',
      many: '$countString مقطعاً',
      few: '$countString مقاطع',
      two: 'مقطعان',
      one: 'مقطع واحد',
      zero: 'لا مقاطع',
    );
    return '$_temp0 · $duration';
  }

  @override
  String itemsCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString مقطع',
      many: '$countString مقطعاً',
      few: '$countString مقاطع',
      two: 'مقطعان',
      one: 'مقطع واحد',
      zero: 'لا مقاطع',
    );
    return '$_temp0';
  }

  @override
  String get queueNowPlaying => 'يعمل الآن';

  @override
  String get queueEmpty => 'الطابور فارغ';

  @override
  String get queueNothingAfter =>
      'لا شيء بعده. اضغط ⋮ على أي مقطع واختر «أضف للنهاية»';

  @override
  String get queueFailedItem => 'تعذّر تشغيله، تم تخطّيه';

  @override
  String queueSkippedSnack(String title) {
    return 'تعذّر تشغيل «$title»، تم الانتقال للتالي';
  }

  @override
  String get queueRemoved => 'حُذف من الطابور';

  @override
  String get queueClear => 'مسح الطابور';

  @override
  String get queueClearConfirmTitle => 'مسح الطابور؟';

  @override
  String get queueClearConfirmBody => 'سيبقى المقطع الحالي يعمل.';

  @override
  String get queueClearAction => 'مسح';

  @override
  String get queueCleared => 'مُسح الطابور';

  @override
  String get undo => 'تراجع';

  @override
  String get delete => 'حذف';

  @override
  String get queueSaveAsPlaylist => 'حفظ كقائمة';

  @override
  String get queueSaveAsLocalPlaylist => 'حفظ كقائمة محلية';

  @override
  String queueDefaultPlaylistName(String date) {
    return 'طابور $date';
  }

  @override
  String get playlistNameLabel => 'اسم القائمة';

  @override
  String get save => 'حفظ';

  @override
  String playlistSaved(String name) {
    return 'حُفظت قائمة «$name»';
  }

  @override
  String get open => 'فتح';

  @override
  String get queueRemove => 'إزالة من الطابور';

  @override
  String get queueMoveNext => 'نقل ليكون التالي';

  @override
  String get moveUp => 'نقل للأعلى';

  @override
  String get moveDown => 'نقل للأسفل';

  @override
  String get dragToReorder => 'اسحب لإعادة الترتيب';

  @override
  String get actionPlayNow => 'شغّل الآن';

  @override
  String get actionPlayNext => 'شغّل التالي';

  @override
  String get actionAddToEnd => 'أضف للنهاية';

  @override
  String get actionAddToLocalPlaylist => 'أضف إلى قائمة محلية…';

  @override
  String snackPlayNext(String title) {
    return 'سيُشغَّل التالي: $title';
  }

  @override
  String get snackAddedToEnd => 'أُضيف إلى نهاية الطابور';

  @override
  String snackAddedCount(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $countString مقطع إلى الطابور',
      many: 'أُضيف $countString مقطعاً إلى الطابور',
      few: 'أُضيف $countString مقاطع إلى الطابور',
      two: 'أُضيف مقطعان إلى الطابور',
      one: 'أُضيف مقطع واحد إلى الطابور',
    );
    return '$_temp0';
  }

  @override
  String queueTruncated(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'الطابور ممتلئ ($countString مقطع)؛ لم يُضف الباقي',
      many: 'الطابور ممتلئ ($countString مقطعاً)؛ لم يُضف الباقي',
      few: 'الطابور ممتلئ ($countString مقاطع)؛ لم يُضف الباقي',
    );
    return '$_temp0';
  }

  @override
  String get untitledVideo => 'مقطع من يوتيوب';

  @override
  String get localPlaylists => 'قوائمي المحلية';

  @override
  String get newPlaylist => 'قائمة جديدة';

  @override
  String get onDevice => 'على الجهاز';

  @override
  String get playlistsEmpty => 'لم تنشئ قوائم بعد. احفظ الطابور أو أنشئ قائمة';

  @override
  String get playlistEmpty => 'القائمة فارغة. أضف مقاطع من ⋮ على أي مقطع';

  @override
  String get playlistsLoadError => 'تعذّر فتح القوائم المحلية';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String deletePlaylistTitle(String name) {
    return 'حذف قائمة «$name»؟';
  }

  @override
  String get deletePlaylistBody => 'لن تُحذف المقاطع من يوتيوب.';

  @override
  String get playAll => 'تشغيل الكل';

  @override
  String get addWholeList => 'أضف القائمة كلها';

  @override
  String addedToPlaylist(String name) {
    return 'أُضيف إلى «$name»';
  }

  @override
  String alreadyInPlaylist(String name) {
    return 'موجود في «$name» بالفعل';
  }

  @override
  String get removedFromPlaylist => 'حُذف من القائمة';

  @override
  String get moreActions => 'مزيد من الخيارات';

  @override
  String get saveFailed => 'تعذّر الحفظ. حاول مرة أخرى';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navLibrary => 'المكتبة';

  @override
  String get searchHint => 'ابحث أو الصق رابطاً';

  @override
  String get searchAction => 'بحث';

  @override
  String get homeStartHint => 'ابدأ بالبحث أو الصق رابطاً';

  @override
  String get guestSignInPrompt =>
      'سجّل الدخول لترى أحدث فيديوهات اشتراكاتك وتبحث في يوتيوب';

  @override
  String get searchNeedsSignIn =>
      'سجّل الدخول للبحث في يوتيوب. يمكنك لصق رابط دون دخول.';

  @override
  String get feedTitle => 'أحدث فيديوهات اشتراكاتك';

  @override
  String get feedEmpty =>
      'لا شيء هنا بعد. فيديوهات القنوات التي تشترك فيها تظهر هنا.';

  @override
  String searchResultsFor(String query) {
    return 'نتائج «$query»';
  }

  @override
  String searchNoResults(String query) {
    return 'لا نتائج لـ «$query». جرّب كلمات أخرى';
  }

  @override
  String get closeSearch => 'إغلاق البحث';

  @override
  String get staleBanner => 'هذه نسخة محفوظة';

  @override
  String get errorQuotaExceeded =>
      'انتهت حصة البحث اليوم. تتجدد غداً. يمكنك لصق رابط أو تشغيل المكتبة.';

  @override
  String get errorApi => 'تعذّر تحميل البيانات من يوتيوب. حاول مرة أخرى.';

  @override
  String get pasteLinkAction => 'الصق رابطاً';

  @override
  String get channelKind => 'قناة';

  @override
  String get channelEmpty => 'لا شيء هنا بعد';

  @override
  String get miniPlaybackFailed => 'تعذّر التشغيل';

  @override
  String get openPlayer => 'فتح المشغّل';

  @override
  String accountSignedInAs(String name) {
    return 'متصل: $name';
  }

  @override
  String get settingsQuota => 'حصة البحث';

  @override
  String quotaSearchesLeft(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString عملية بحث متبقية اليوم',
      many: '$countString عملية بحث متبقية اليوم',
      few: '$countString عمليات بحث متبقية اليوم',
      two: 'بحثان متبقيان اليوم',
      one: 'بحث واحد متبقٍ اليوم',
      zero: 'لا بحث متبقٍ اليوم',
    );
    return '$_temp0';
  }

  @override
  String get quotaUnavailable => 'غير متاح';

  @override
  String get errorGeneralQuotaExceeded =>
      'انتهت حصة يوتيوب اليومية للقوائم والقنوات. تتجدد غداً. يمكنك لصق رابط أو تشغيل المكتبة.';

  @override
  String get errorInsufficientPermissions =>
      'لم يمنح حسابك التطبيق صلاحية قراءة يوتيوب. امنحها للمتابعة.';

  @override
  String get grantPermission => 'امنح الصلاحية';

  @override
  String get loadMore => 'المزيد';

  @override
  String quotaSearchUsage(int used, int limit) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return '$usedString من $limitString عملية بحث اليوم';
  }

  @override
  String quotaGeneralUsage(int used, int limit) {
    final intl.NumberFormat usedNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String usedString = usedNumberFormat.format(used);
    final intl.NumberFormat limitNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String limitString = limitNumberFormat.format(limit);

    return 'القوائم والقنوات: $usedString من $limitString وحدة';
  }

  @override
  String get quotaResetNote => 'تتجدد الحصتان عند منتصف ليل المحيط الهادئ';

  @override
  String get errorPlaylistNeedsSignIn =>
      'سجّل الدخول لإضافة قوائم يوتيوب. روابط الفيديو تعمل دون دخول.';

  @override
  String get libraryYouTubePlaylists => 'قوائم يوتيوب';

  @override
  String get libraryLikes => 'الإعجابات';

  @override
  String get librarySubscriptions => 'الاشتراكات';

  @override
  String get libraryFavorites => 'المفضلة';

  @override
  String get libraryHistory => 'السجل';

  @override
  String get libraryEmpty => 'لا شيء هنا بعد';

  @override
  String get libraryLocalLoadError => 'تعذّر فتح هذا القسم من التخزين';

  @override
  String get favoritesEmpty => 'لم تضف شيئاً بعد. اضغط ⋮ على أي فيديو';

  @override
  String get historyEmpty => 'لم تشغّل شيئاً بعد';

  @override
  String get addToFavorites => 'أضف إلى المفضلة';

  @override
  String get removeFromFavorites => 'أزل من المفضلة';

  @override
  String get addedToFavorites => 'أُضيف إلى المفضلة';

  @override
  String get removedFromFavorites => 'أُزيل من المفضلة';

  @override
  String get removeFromHistory => 'حذف من السجل';

  @override
  String get removedFromHistory => 'حُذف من السجل';

  @override
  String get clearHistory => 'مسح السجل';

  @override
  String get clearHistoryConfirmTitle => 'مسح السجل؟';

  @override
  String get clearHistoryConfirmBody =>
      'سيُحذف سجل التشغيل من هذا الجهاز. لا يؤثر على يوتيوب.';

  @override
  String get clearHistoryAction => 'مسح';

  @override
  String get historyCleared => 'مُسح السجل';

  @override
  String get playlistAdding => 'جارٍ إضافة القائمة…';

  @override
  String playlistAddingProgress(int fetched, int total) {
    final intl.NumberFormat fetchedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String fetchedString = fetchedNumberFormat.format(fetched);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'جارٍ إضافة القائمة… $fetchedString من $totalString';
  }

  @override
  String playlistAddedPartial(int added, int total) {
    final intl.NumberFormat addedNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String addedString = addedNumberFormat.format(added);
    final intl.NumberFormat totalNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String totalString = totalNumberFormat.format(total);

    return 'أُضيف $addedString من $totalString. تعذّر جلب الباقي';
  }

  @override
  String playlistAddedPartialUnknown(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أُضيف $countString مقطع',
      many: 'أُضيف $countString مقطعاً',
      few: 'أُضيف $countString مقاطع',
      two: 'أُضيف مقطعان',
      one: 'أُضيف مقطع واحد',
    );
    return '$_temp0. تعذّر جلب الباقي';
  }
}
