// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'لمحة';

  @override
  String get loadError => 'تعذّر تحميل الإعدادات';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get opacityLabel => 'الشفافية';

  @override
  String percent(String value) {
    return '$value٪';
  }

  @override
  String get backgroundButton => 'لقطة الخلفية';

  @override
  String get backgroundSaved => 'حُفظت لقطة الخلفية';

  @override
  String get backgroundError =>
      'تعذّر حفظ لقطة الخلفية. تأكد من إذن الصور وحاول مرة أخرى.';

  @override
  String get cityLabel => 'المدينة';

  @override
  String get myLocation => 'موقعي';

  @override
  String get locationDenied =>
      'لم يُسمح بالوصول إلى الموقع، أو خدمة الموقع مغلقة. ابحث عن مدينتك أو اخترها من القائمة.';

  @override
  String get locationFailed =>
      'تعذّر تحديد الموقع. ابحث عن مدينتك أو اخترها من القائمة.';

  @override
  String get prayerMethodLabel => 'طريقة حساب الصلاة';

  @override
  String prayerMethodName(String method) {
    String _temp0 = intl.Intl.selectLogic(method, {
      'ummAlQura': 'أم القرى',
      'muslimWorldLeague': 'رابطة العالم الإسلامي',
      'egyptian': 'الهيئة المصرية العامة للمساحة',
      'karachi': 'جامعة العلوم الإسلامية بكراتشي',
      'dubai': 'دبي',
      'kuwait': 'الكويت',
      'qatar': 'قطر',
      'gulfRegion': 'منطقة الخليج',
      'northAmerica': 'أمريكا الشمالية',
      'turkiye': 'تركيا',
      'other': '$method',
    });
    return '$_temp0';
  }

  @override
  String elementName(String element) {
    String _temp0 = intl.Intl.selectLogic(element, {
      'clock': 'الساعة واليوم',
      'dates': 'التاريخ الهجري والميلادي',
      'weather': 'المدينة والطقس',
      'prayer': 'الصلاة القادمة',
      'qibla': 'القبلة',
      'deposit': 'الإيداعات',
      'season': 'الفصل',
      'tradSeason': 'الموسم',
      'dayWeather': 'اليوم والطقس',
      'hijri': 'التاريخ الهجري',
      'gregorian': 'التاريخ الميلادي',
      'prayerTimes': 'مواقيت الصلاة',
      'tradPoints': 'وصف الموسم',
      'other': '$element',
    });
    return '$_temp0';
  }

  @override
  String get lastDepositMessage =>
      'يلزم إيداع واحد على الأقل. لإخفاء المربع استخدم «تخصيص الودجت».';

  @override
  String get tilePrayer => 'الصلاة القادمة';

  @override
  String get tileQibla => 'القبلة';

  @override
  String get tileDeposit => 'الإيداع القادم';

  @override
  String get tileDepositShort => 'الإيداع';

  @override
  String get tileSeason => 'الفصل';

  @override
  String get tileTradSeason => 'الموسم';

  @override
  String hijriDateText(String date) {
    return '$date هـ';
  }

  @override
  String gregorianDateText(String date) {
    return '$date م';
  }

  @override
  String cityWeather(String city, String weather) {
    return '📍 $city · $weather';
  }

  @override
  String remainingToNext(String remaining, String next) {
    return '$remaining $next';
  }

  @override
  String degrees(String value) {
    return '$value°';
  }

  @override
  String get dataLicense =>
      'إحداثيات المدن من GeoNames (geonames.org) برخصة CC BY 4.0، وبعضها من OpenStreetMap (© مساهمو OpenStreetMap، ODbL). الخط Tajawal برخصة SIL OFL 1.1.';

  @override
  String nearCity(String city) {
    return 'قرب $city';
  }

  @override
  String get locationNearest =>
      'تعذّر جلب اسم المكان، فظهر اسم أقرب مدينة. الحساب بموقعك الفعلي.';

  @override
  String get searchHint => 'ابحث عن مدينة أو محافظة';

  @override
  String get searchNoResults => 'لا توجد نتائج. جرّب اسماً آخر.';

  @override
  String get searchFailed =>
      'تعذّر البحث. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.';

  @override
  String get quickPick => 'اختيار سريع';

  @override
  String get qiblaTitle => 'اتجاه القبلة';

  @override
  String qiblaFromNorth(String degrees) {
    return '$degrees من الشمال';
  }

  @override
  String get compassHint => 'أدر الجوال حتى تصل الكعبة للسهم بالأعلى';

  @override
  String get qiblaAligned => 'أنت باتجاه القبلة';

  @override
  String qiblaTileSub(String direction) {
    return 'من الشمال · $direction';
  }

  @override
  String get qiblaDistance => 'المسافة إلى مكة';

  @override
  String qiblaDistanceKm(String km) {
    return '$km كم';
  }

  @override
  String get compassAccuracyTitle => 'دقة البوصلة';

  @override
  String compassAccuracy(String level) {
    String _temp0 = intl.Intl.selectLogic(level, {
      'excellent': 'ممتازة',
      'good': 'جيدة',
      'other': 'ضعيفة',
    });
    return '$_temp0';
  }

  @override
  String get compassWaiting => 'جارٍ قراءة البوصلة…';

  @override
  String get compassCalibrate => 'حرّك الجوال على شكل رقم ٨ لمعايرة البوصلة';

  @override
  String get compassUnavailable =>
      'لا يتوفر حساس بوصلة في هذا الجهاز، فلا يمكن عرض السهم. استعن بالزاوية أعلاه وبوصلة أخرى.';

  @override
  String get weatherUnknown => '--°';

  @override
  String get themeLabel => 'لون الودجت';

  @override
  String themeName(String theme) {
    String _temp0 = intl.Intl.selectLogic(theme, {
      'black': 'أسود',
      'gold': 'ذهبي',
      'green': 'أخضر',
      'blue': 'أزرق',
      'purple': 'بنفسجي',
      'pink': 'وردي',
      'gray': 'رمادي',
      'system': 'ألوان النظام',
      'other': '$theme',
    });
    return '$_temp0';
  }

  @override
  String get lockNotificationLabel => 'إظهار في شاشة القفل (إشعار)';

  @override
  String get lockNotificationHint =>
      'أغلب جوالات أندرويد لا تسمح بودجت على شاشة القفل، فيظهر إشعار هادئ بالصلاة القادمة والقبلة.';

  @override
  String get notificationPermissionTitle => 'إذن الإشعارات';

  @override
  String get notificationPermissionBody =>
      'لعرض الصلاة القادمة والعد التنازلي والقبلة في شاشة القفل، تحتاج لمحة إذن الإشعارات. الإشعار ثابت وهادئ: بلا صوت ولا اهتزاز، ويمكنك إطفاؤه من هنا في أي وقت.';

  @override
  String get continueAction => 'متابعة';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get notificationDenied =>
      'لم يُسمح بالإشعارات، فلن يظهر شيء في شاشة القفل. يمكنك السماح بها من إعدادات الجوال.';

  @override
  String get fontScaleLabel => 'حجم الخط';

  @override
  String fontScaleName(String scale) {
    String _temp0 = intl.Intl.selectLogic(scale, {
      'small': 'صغير',
      'medium': 'متوسط',
      'large': 'كبير',
      'xlarge': 'كبير جداً',
      'other': '$scale',
    });
    return '$_temp0';
  }

  @override
  String countdownText(String time) {
    return 'باقي $time';
  }

  @override
  String get depositsSection => 'الإيداعات الظاهرة';

  @override
  String get customizeTitle => 'الودجت';

  @override
  String get resetLayout => 'استعادة الافتراضي';

  @override
  String get tileVisible => 'إظهار';

  @override
  String get tileSpanLabel => 'العرض';

  @override
  String get tileFontLabel => 'حجم الخط';

  @override
  String get primaryColorLabel => 'لون الخط الرئيسي';

  @override
  String get secondaryColorLabel => 'لون الخط الفرعي';

  @override
  String get tileOverflow => 'لا يتسع في الودجت (أكثر من ٥ صفوف)';

  @override
  String get dragHandle => 'اضغط مطولاً واسحب لإعادة الترتيب';

  @override
  String get tileHint =>
      'اسحب أي مربع في المعاينة لتحريكه. اضغطه لفتح لوحة خطه وألوانه ومحتواه، وتظهر في زواياه الأربع مقابض لتكبيره أو تصغيره من أي جهة. زر «ملء الشاشة» للتعديل بدقة. العناصر تصعد تلقائياً لتملأ الفراغ.';

  @override
  String tileSpanName(String span) {
    String _temp0 = intl.Intl.selectLogic(span, {
      'small': 'صغير',
      'medium': 'متوسط',
      'wide': 'عريض',
      'other': '$span',
    });
    return '$_temp0';
  }

  @override
  String tileColorName(String color) {
    String _temp0 = intl.Intl.selectLogic(color, {
      'auto': 'تلقائي',
      'white': 'أبيض',
      'black': 'أسود',
      'gold': 'ذهبي',
      'green': 'أخضر',
      'blue': 'أزرق',
      'purple': 'بنفسجي',
      'pink': 'وردي',
      'lightGray': 'رمادي فاتح',
      'cream': 'كريمي',
      'yellow': 'أصفر',
      'orange': 'برتقالي',
      'red': 'أحمر',
      'lime': 'أخضر فاتح',
      'teal': 'تركوازي',
      'cyan': 'سماوي',
      'brown': 'بني',
      'gray': 'رمادي',
      'other': '$color',
    });
    return '$_temp0';
  }

  @override
  String get tileShowTitle => 'إظهار العنوان';

  @override
  String get tileShowSub => 'إظهار السطر الفرعي';

  @override
  String get digitsLabel => 'الأرقام';

  @override
  String digitsName(String style) {
    String _temp0 = intl.Intl.selectLogic(style, {
      'arabic': 'عربية (١٢٣)',
      'latin': 'إنجليزية (123)',
      'other': '$style',
    });
    return '$_temp0';
  }

  @override
  String get depositsTitle => 'متبقي على:';

  @override
  String tradPointsTitle(String season) {
    return 'في $season:';
  }

  @override
  String pointText(String point) {
    return '- $point';
  }

  @override
  String nextAfter(String next, String after) {
    return '$next $after';
  }

  @override
  String cityIcon(String city, String icon) {
    return '📍 $city $icon';
  }

  @override
  String get qiblaTabCompass => 'البوصلة';

  @override
  String get qiblaTabMap => 'الخريطة';

  @override
  String get qiblaHoldFlat => 'ضع هاتفك أفقياً للحصول على أفضل نتيجة';

  @override
  String get qiblaMyLocation => 'موقعك الحالي';

  @override
  String get qiblaLocating => 'جارٍ تحديد موقعك…';

  @override
  String qiblaSavedLocation(String city) {
    return 'تعذّر تحديد موقعك الآن، فالحساب من المدينة المحفوظة: $city';
  }

  @override
  String get qiblaMapDirection => 'الاتجاه من الشمال';

  @override
  String get qiblaMapDistance => 'تبعد عن الكعبة';

  @override
  String get qiblaMapOffline => 'تحتاج الخريطة اتصالاً بالإنترنت';

  @override
  String get prayerCountdownLabel => 'العدّاد التنازلي للصلاة القادمة';

  @override
  String get prayerCountdownHint =>
      'يظهر تحت الساعة في الودجت. مطفأ افتراضياً.';

  @override
  String get tileFloatLabel => 'عائم فوق المربعات (تحريك وتكبير حرّ)';

  @override
  String get tileFloatHint =>
      'اسحبه في المعاينة وغيّر مقاسه من زواياه؛ لا يزاحم المربعات ولا تزاحمه.';

  @override
  String get qiblaIconSizeLabel => 'حجم أيقونة البوصلة';

  @override
  String get tilesLastOne => 'يجب أن تبقى نافذة واحدة على الأقل';

  @override
  String get tilesDragHandle => 'اسحب لإعادة الترتيب';

  @override
  String get paywallTitle => 'اشترك في لمحة';

  @override
  String get paywallSub =>
      'ودجت عربية للشاشة الرئيسية وشاشة القفل: الإيداعات والصلوات والهجري والقبلة. جرّب ٧ أيام مجانًا، ثم يتجدد الاشتراك تلقائيًا ويمكنك إلغاؤه في أي وقت من إعدادات حسابك على آبل.';

  @override
  String get paywallMonthly => 'شهري';

  @override
  String get paywallYearly => 'سنوي';

  @override
  String get paywallStartTrial => 'ابدأ التجربة المجانية';

  @override
  String get paywallRestore => 'استعادة المشتريات';

  @override
  String get paywallPrivacy => 'سياسة الخصوصية';

  @override
  String get paywallChecking => 'جارٍ التحقق من اشتراكك…';

  @override
  String get paywallUnavailable => 'المتجر غير متاح الآن. حاول لاحقًا.';

  @override
  String get paywallVerifyFailed =>
      'تعذّر التحقق من الاشتراك الآن. حاول لاحقًا، فلن يضيع اشتراكك.';

  @override
  String get paywallNotActive => 'لا يوجد اشتراك فعّال على حساب آبل هذا.';

  @override
  String get tabSize => 'الحجم';

  @override
  String get tabColors => 'الألوان';

  @override
  String get tabContent => 'المحتوى';

  @override
  String get tileNoContent => 'لا خيارات محتوى لهذا العنصر';

  @override
  String get colorPresetsLabel => 'ألوان جاهزة';

  @override
  String colorPresetName(String name) {
    String _temp0 = intl.Intl.selectLogic(name, {
      'auto': 'تلقائي',
      'gold': 'ذهبي',
      'white': 'أبيض',
      'green': 'أخضر',
      'blue': 'أزرق',
      'rose': 'وردي',
      'dark': 'داكن',
      'other': '$name',
    });
    return '$_temp0';
  }

  @override
  String get opacityNeedsBackground =>
      'آيفون لا يسمح بودجت شفافة فعلاً، فيظهر اللون الأبيض خلفها. لمحاكاة الشفافية: خذ لقطة لشاشتك الرئيسية فارغة، ثم اختر «لقطة الخلفية» بالأسفل.';

  @override
  String get backgroundRemove => 'حذف لقطة الخلفية';

  @override
  String get backgroundRemoved => 'حُذفت لقطة الخلفية، وعادت الودجت للون السمة';

  @override
  String get cropTitle => 'ضبط لقطة الخلفية';

  @override
  String get cropSave => 'حفظ';

  @override
  String get cropHint =>
      'اختر مقاس الودجت وموضعه في شاشتك، ثم اسحب الإطار حتى يطابق مكان الودجت تماماً.';

  @override
  String cropSizeName(String size) {
    String _temp0 = intl.Intl.selectLogic(size, {
      'large': 'كبير',
      'medium': 'متوسط',
      'other': '$size',
    });
    return '$_temp0';
  }

  @override
  String cropSlotName(String slot) {
    String _temp0 = intl.Intl.selectLogic(slot, {
      'top': 'أعلى',
      'middle': 'وسط',
      'bottom': 'أسفل',
      'other': '$slot',
    });
    return '$_temp0';
  }

  @override
  String get freeLayoutRejected =>
      'لا يمكن هذا الترتيب في الودجت. جرّب موضعاً أو مقاساً آخر.';

  @override
  String get previewFullscreen => 'ملء الشاشة';

  @override
  String get adhanSection => 'الأذان';

  @override
  String get adhanEnable => 'الأذان عند كل صلاة';

  @override
  String get adhanEnableHint => 'تنبيه صوتي عند دخول وقت الصلاة بحسب مدينتك';

  @override
  String get adhanSoundLabel => 'الصوت';

  @override
  String get adhanSoundFull => 'أذان كامل';

  @override
  String get adhanSoundTakbeer => 'تكبيرتان';

  @override
  String get adhanSoundSilent => 'بلا صوت';

  @override
  String get adhanTest => 'تجربة الصوت';

  @override
  String get adhanNoteIos =>
      'في آيفون يكون الصوت تكبيرتين، لأن آبل تحدد صوت الإشعار بـ٣٠ ثانية. يُجدول ١٢ يوماً قادماً ويتجدد كلما فتحت لمحة.';

  @override
  String get adhanNoteAndroid =>
      'زر «إيقاف» في الإشعار يوقف الصوت. يُجدول ١٢ يوماً قادماً ويتجدد كلما فتحت لمحة.';

  @override
  String get adhanDenied => 'لم يُمنح إذن الإشعارات، فبقي الأذان مطفأً.';

  @override
  String get adhanExactMissing =>
      'لم يُمنح إذن «المنبهات والتذكيرات»، فقد يتأخر التنبيه دقائق عن وقته.';
}
