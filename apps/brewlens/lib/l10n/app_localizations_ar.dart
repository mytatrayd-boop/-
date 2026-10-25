// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'عدسة البُن';

  @override
  String get appTagline => 'قيّم مظهر قهوتك واحفظ مقاهيك';

  @override
  String get demoBanner => 'نسخة عرض — البيانات تجريبية';

  @override
  String get demoDialogTitle => 'نسخة عرض';

  @override
  String get demoDialogBody =>
      'هذه نسخة للمراجعة، لا تتصل بالخادم ولا بالمتجر.';

  @override
  String get ok => 'حسناً';

  @override
  String get cancel => 'إلغاء';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get back => 'رجوع';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get confirmPasswordLabel => 'تأكيد كلمة المرور';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get forgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get signInButton => 'دخول';

  @override
  String get noAccountPrompt => 'ليس لديك حساب؟';

  @override
  String get createAccountLink => 'أنشئ حساباً';

  @override
  String get signUpTitle => 'إنشاء حساب';

  @override
  String get signUpReason =>
      'نحتاج حساباً لحفظ سجلك ومقاهيك وحماية محاولاتك اليومية';

  @override
  String passwordHint(int count) {
    return '$count أحرف على الأقل';
  }

  @override
  String get termsNotice => 'بالتسجيل توافق على الشروط وسياسة الخصوصية';

  @override
  String get signUpButton => 'إنشاء الحساب';

  @override
  String get haveAccountPrompt => 'لديك حساب؟';

  @override
  String get signInLink => 'سجّل الدخول';

  @override
  String get forgotTitle => 'استعادة كلمة المرور';

  @override
  String get forgotBody => 'سنرسل رابطاً لبريدك';

  @override
  String get sendLinkButton => 'إرسال الرابط';

  @override
  String resetSentBody(String email) {
    return 'أرسلنا الرابط إلى $email، تحقق من البريد المزعج أيضاً';
  }

  @override
  String get backToSignIn => 'العودة للدخول';

  @override
  String get resendButton => 'إعادة الإرسال';

  @override
  String resendIn(int seconds) {
    return 'إعادة الإرسال ($seconds)';
  }

  @override
  String get errorInvalidEmail => 'أدخل بريداً إلكترونياً صحيحاً';

  @override
  String errorPasswordShort(int count) {
    return 'كلمة المرور $count أحرف على الأقل';
  }

  @override
  String get errorPasswordMismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get errorUnknown => 'حدث خطأ، حاول مجدداً';

  @override
  String get failureUnauthorized => 'انتهت الجلسة، سجّل الدخول مجدداً';

  @override
  String get failureInvalidCredentials => 'البريد أو كلمة المرور غير صحيحة';

  @override
  String get failureEmailTaken => 'هذا البريد مسجّل، سجّل الدخول';

  @override
  String get failureLimitReached => 'انتهت محاولاتك المجانية لليوم';

  @override
  String get failureFairUseReached => 'وصلت لحد الاستخدام العادل';

  @override
  String get failureServiceUnavailable =>
      'الخدمة غير متاحة الآن، لم تُحتسب المحاولة';

  @override
  String get failureImageTooLarge => 'الصورة كبيرة جداً، جرّب صورة أخرى';

  @override
  String get failureOffline => 'لا يوجد اتصال بالإنترنت';

  @override
  String get failureSaveFailed => 'تعذّر الحفظ، حاول مجدداً';

  @override
  String get failurePurchaseUnavailable => 'الشراء غير متاح حالياً';

  @override
  String get invalidImageNotCoffee => 'لا يبدو أن الصورة لكوب قهوة';

  @override
  String get invalidImageTooDark => 'الصورة مظلمة، جرّب إضاءة أفضل';

  @override
  String get invalidImageBlurry => 'الصورة غير واضحة، ثبّت الجوال وأعد التصوير';

  @override
  String get invalidImageNoCup =>
      'اجعل الكوب ظاهراً بالكامل من الأعلى أو الجانب';

  @override
  String get invalidImageOther => 'تعذّر تحليل الصورة، جرّب صورة أخرى';

  @override
  String get homeWelcome => 'أهلاً بك';

  @override
  String get homeHeroTitle => 'صوّر كوبك';

  @override
  String get homeHeroBody => 'احصل على تقييم المظهر ونصيحة باريستا';

  @override
  String get homeEmpty => 'لا تقييمات بعد — صوّر كوبك الأول';

  @override
  String usageRemainingDay(int remaining, int limit) {
    return 'متبقٍّ لك اليوم: $remaining من $limit';
  }

  @override
  String usageRemainingMonth(int remaining, int limit) {
    return 'متبقٍّ لك هذا الشهر: $remaining من $limit';
  }

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get signOutConfirm => 'تسجيل الخروج من حسابك؟';

  @override
  String get close => 'إغلاق';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navHistory => 'السجل';

  @override
  String get openCamera => 'افتح الكاميرا';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get recentReviews => 'آخر التقييمات';

  @override
  String get favoriteShops => 'مقاهيّ المفضلة';

  @override
  String get coffeeEspresso => 'إسبريسو';

  @override
  String get coffeeV60 => 'V60';

  @override
  String get coffeeFrenchPress => 'فرنش بريس';

  @override
  String get visualLimitedNote =>
      'التحليل البصري لهذا النوع محدود؛ تقييمك الذوقي أهم';

  @override
  String get cameraGuide => 'ضع الكوب داخل الدائرة، والإضاءة من الأمام';

  @override
  String get capturePhoto => 'التقاط صورة';

  @override
  String get pickFromGallery => 'اختيار من المعرض';

  @override
  String get analyzing => 'الباريستا يتفحص كوبك…';

  @override
  String get analyzingLong => 'لحظات إضافية…';

  @override
  String get cameraDenied => 'نحتاج الكاميرا لتصوير كوبك وتقييم مظهره';

  @override
  String get galleryDenied => 'نحتاج الوصول للصور لاختيار صورة كوبك';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get attemptNotCounted => 'لم تُحتسب هذه المحاولة';

  @override
  String get retakePhoto => 'التقط مجدداً';

  @override
  String get tryLater => 'حاول لاحقاً';

  @override
  String get resubmit => 'إعادة الإرسال';

  @override
  String get demoSimulateRejection => 'محاكاة صورة مرفوضة';

  @override
  String get resultTitle => 'النتيجة';

  @override
  String get appearanceScore => 'تقييم المظهر';

  @override
  String get scoreOutOf => '/10';

  @override
  String scoreSemantics(String score) {
    return 'تقييم المظهر $score من 10';
  }

  @override
  String get scoreNeedsCare => 'يحتاج عناية';

  @override
  String get scoreGood => 'جيد';

  @override
  String get scoreExcellent => 'ممتاز';

  @override
  String get scoreExceptional => 'استثنائي';

  @override
  String get baristaReport => 'تقرير الباريستا';

  @override
  String tipLine(String tip) {
    return 'نصيحة للمرة القادمة: $tip';
  }

  @override
  String get tasteRatingPrompt => 'بعد التذوق، كم تعطيه؟';

  @override
  String ratingSemantics(int rating) {
    return 'تقييمك $rating من 5';
  }

  @override
  String starSemantics(int count) {
    return '$count من 5';
  }

  @override
  String get userNotesLabel => 'ملاحظاتك (اختياري)';

  @override
  String get shopPrompt => 'أين شربته؟ (اختياري)';

  @override
  String get addFavorite => 'إضافة للمفضلة';

  @override
  String get removeFavorite => 'إزالة من المفضلة';

  @override
  String get addedToFavorites => 'أُضيف للمفضلة';

  @override
  String get removedFromFavorites => 'أُزيل من المفضلة';

  @override
  String get undo => 'تراجع';

  @override
  String get saveReview => 'حفظ التقييم';

  @override
  String get savedDone => 'تم الحفظ';

  @override
  String get viewInHistory => 'عرض في السجل';

  @override
  String get discardTitle => 'تجاهل النتيجة؟';

  @override
  String get discardBody => 'ستبقى المحاولة محتسبة';

  @override
  String get discard => 'تجاهل';

  @override
  String get stay => 'البقاء';

  @override
  String get shopNameLabel => 'اسم المقهى';

  @override
  String get previousShops => 'مقاهيك السابقة';

  @override
  String get hasSavedLocation => 'له موقع محفوظ';

  @override
  String get saveMyLocation => 'حفظ موقعي الحالي كموقع المقهى';

  @override
  String get locating => 'جارٍ تحديد الموقع…';

  @override
  String get locationSaved => 'تم حفظ الموقع';

  @override
  String get remove => 'إزالة';

  @override
  String get usingSavedLocation => 'سيُستخدم الموقع المحفوظ';

  @override
  String get locationFailed => 'لم نتمكن من تحديد موقعك — سيُحفظ الاسم فقط';

  @override
  String get enableLocation => 'تفعيل الموقع';

  @override
  String get done => 'تم';

  @override
  String get noShop => 'بدون مقهى';

  @override
  String get historyTitle => 'السجل';

  @override
  String get tabMyReviews => 'تقييماتي';

  @override
  String get tabFavorites => 'المقاهي المفضلة';

  @override
  String get notRated => 'لم تُقيّم';

  @override
  String get today => 'اليوم';

  @override
  String get yesterday => 'أمس';

  @override
  String daysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يوم',
      many: 'قبل $count يوماً',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
    );
    return '$_temp0';
  }

  @override
  String get favoritesEmpty => 'لا مقاهٍ مفضلة بعد — أضف مقهى من شاشة النتيجة';

  @override
  String get noRatingYet => '—';

  @override
  String shopRating(String rating) {
    return '★ $rating';
  }

  @override
  String shopScore(String score) {
    return 'مظهر $score';
  }

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تقييم',
      many: '$count تقييماً',
      few: '$count تقييمات',
      two: 'تقييمان',
      one: 'تقييم واحد',
      zero: 'لا تقييمات',
    );
    return '$_temp0';
  }

  @override
  String get openInGoogleMaps => 'فتح في خرائط جوجل';

  @override
  String get mapsFailed => 'تعذّر فتح الخرائط';

  @override
  String get reviewDetailTitle => 'تفاصيل التقييم';

  @override
  String get saveChanges => 'حفظ التعديلات';

  @override
  String get moreOptions => 'خيارات أخرى';

  @override
  String get deleteReview => 'حذف التقييم';

  @override
  String get deleteReviewConfirm => 'حذف هذا التقييم وصورته نهائياً؟';

  @override
  String get delete => 'حذف';

  @override
  String get reviewDeleted => 'حُذف التقييم';

  @override
  String get paywallRenews => 'تتجدد منتصف الليل بتوقيت الرياض';

  @override
  String get failurePurchaseFailed => 'لم تكتمل العملية، لم يُخصم منك شيء';

  @override
  String get failureNoPurchases => 'لا توجد مشتريات سابقة لهذا الحساب';

  @override
  String get failureDeleteFailed => 'تعذّر الحذف، حاول مجدداً';

  @override
  String get failureShareFailed => 'تعذّر إنشاء البطاقة، حاول مجدداً';

  @override
  String get shareCard => 'مشاركة كبطاقة';

  @override
  String get shareCardBrand => 'BrewLens';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get termsOfUse => 'شروط الاستخدام';

  @override
  String get privacyBody =>
      'نسخة مؤقتة مختصرة حتى نشر السياسة الكاملة.\n\n• نجمع بريدك الإلكتروني لإنشاء حسابك فقط، بلا اسم عرض.\n• صورة الكوب تُرسل لخدمة ذكاء اصطناعي (Google Gemini) لتحليل مظهرها، وتُحفظ في حسابك فقط.\n• موقع المقهى يُقرأ مرة واحدة عند ضغطك «حفظ موقعي»، ولا يُربط بتقييماتك.\n• لا نستخدم أدوات تتبع ولا نبيع بياناتك.\n• يمكنك حذف حسابك وكل بياناتك وصورك نهائياً من الإعدادات.';

  @override
  String get termsBody =>
      'نسخة مؤقتة مختصرة حتى نشر الشروط الكاملة.\n\n• «تقييم المظهر» تقدير آلي لشكل الكوب في الصورة فقط، وليس حكماً مهنياً.\n• تحليلان مجاناً يومياً، و20 يومياً للمشتركين ضمن الاستخدام العادل.\n• الاشتراك يتجدد تلقائياً ما لم تُلغِه قبل 24 ساعة من نهاية الفترة، والإلغاء من إعدادات المتجر.\n• لا ترفع صوراً لا تملك حق استخدامها.';

  @override
  String get restorePurchases => 'استعادة المشتريات';

  @override
  String get subscribedTitle => 'أصبحت مشتركاً';

  @override
  String get startCapturing => 'ابدأ التصوير';

  @override
  String priceSar(String amount) {
    return '$amount ر.س';
  }

  @override
  String get paywallTitleSettings => 'اشترك في عدسة البُن';

  @override
  String get paywallTitleLimit => 'انتهت محاولاتك المجانية لليوم';

  @override
  String get paywallBenefitLimit => '20 تحليلاً يومياً';

  @override
  String get paywallBenefitReport => 'تقرير باريستا لكل كوب';

  @override
  String get paywallBenefitHistory => 'سجل ومفضلة بلا حدود';

  @override
  String get planAnnual => 'سنوي';

  @override
  String get planMonthly => 'شهري';

  @override
  String perYear(String price) {
    return '$price / سنة';
  }

  @override
  String perMonth(String price) {
    return '$price / شهر';
  }

  @override
  String perMonthApprox(String price) {
    return '≈ $price شهرياً';
  }

  @override
  String trialDays(int days) {
    return '$days أيام مجاناً';
  }

  @override
  String savePercent(int percent) {
    return 'وفّر $percent%';
  }

  @override
  String get startFreeTrial => 'ابدأ التجربة المجانية';

  @override
  String get subscribeNow => 'اشترك الآن';

  @override
  String get subscriptionTerms =>
      'يتجدد تلقائياً ما لم تُلغِه قبل 24 ساعة من نهاية الفترة. الإلغاء من إعدادات المتجر.';

  @override
  String get termsShort => 'الشروط';

  @override
  String get privacyShort => 'الخصوصية';

  @override
  String get purchaseUnavailableDemo => 'الشراء غير متاح في نسخة العرض';

  @override
  String get languageSystem => 'حسب الجهاز';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get settingsAccount => 'الحساب';

  @override
  String get subscription => 'الاشتراك';

  @override
  String get subscriptionActive => 'مشترك';

  @override
  String get subscriptionFree => 'مجاني';

  @override
  String get settingsApp => 'التطبيق';

  @override
  String get language => 'اللغة';

  @override
  String get settingsDemo => 'وضع العرض فقط';

  @override
  String get simulateSubscriber => 'محاكاة مشترك';

  @override
  String get simulateSubscriberHint =>
      'يرفع الحد إلى 20 تحليلاً يومياً في نسخة العرض';

  @override
  String get deleteAccount => 'حذف الحساب';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get accountDeleted => 'تم حذف حسابك';

  @override
  String get deleteConfirmWord => 'حذف';

  @override
  String get deleteAccountWarning =>
      'سيُحذف حسابك وكل تقييماتك وصورك ومفضلتك نهائياً ولا يمكن استرجاعها';

  @override
  String get deleteAccountSubscriptionNote =>
      'الاشتراك لا يُلغى بالحذف — ألغِه من إعدادات المتجر';

  @override
  String deleteConfirmLabel(String word) {
    return 'اكتب «$word» للتأكيد';
  }

  @override
  String get deleteAccountButton => 'حذف حسابي نهائياً';

  @override
  String get manageSubscription => 'إدارة الاشتراك في المتجر';
}
