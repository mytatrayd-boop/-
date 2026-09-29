// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'أسرتي';

  @override
  String get tagline => 'مهام البيت… بروح التحدي';

  @override
  String get feedback => 'اقتراحات وشكاوى';

  @override
  String get demoMailbox => 'البريد التجريبي';

  @override
  String get signOut => 'خروج';

  @override
  String get settings => 'الإعدادات';

  @override
  String get familyMembers => 'أفراد الأسرة';

  @override
  String get pendingVerification => 'بانتظار التحقق';

  @override
  String get roleOwner => 'مسؤول الأسرة';

  @override
  String get roleAdmin => 'مسؤول مفوَّض';

  @override
  String get roleMember => 'عضو';

  @override
  String get changeMyAvatar => 'تغيير رمزي';

  @override
  String changeAvatarOf(String name) {
    return 'تغيير رمز $name';
  }

  @override
  String get welcome => 'أهلاً بك في أسرتي';

  @override
  String get howUse => 'كيف ستستخدم التطبيق؟';

  @override
  String get chooseAdmin => 'مسؤول الأسرة';

  @override
  String get chooseAdminSub =>
      'أنشئ أسرتك، وزّع المهام، وأدر المكافآت والمسابقات';

  @override
  String get chooseMember => 'أحد أفراد الأسرة';

  @override
  String get chooseMemberSub => 'انضم لأسرتك بالبريد الذي أضافه المسؤول';

  @override
  String get tryDemo => 'تجربة سريعة بأسرة جاهزة';

  @override
  String get demoNote =>
      'التجربة السريعة تعمل على جهازك فقط، ولا تُرسل أي بيانات.';

  @override
  String get back => '‹ رجوع';

  @override
  String get loginAdmin => 'دخول مسؤول الأسرة';

  @override
  String get loginMember => 'دخول فرد من الأسرة';

  @override
  String get hintSetup =>
      'أنشئ أسرتك الآن، وسنرسل كود تحقق إلى بريدك. إذا كنت مسؤولاً مضافاً في أسرة، اترك الاسمين فارغين.';

  @override
  String get hintAdmin => 'أدخل بريدك المسجّل كمسؤول وسنرسل لك كود تحقق.';

  @override
  String get hintMember =>
      'أدخل البريد الذي أضافه مسؤول الأسرة وسنرسل لك كود تحقق.';

  @override
  String get familyNameHint => 'اسم الأسرة، مثل: أسرة آل محمد';

  @override
  String get yourNameHint => 'اسمك، مثل: أبو أصيل';

  @override
  String get emailHint => 'name@example.com';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get sendCode => 'إرسال كود التحقق';

  @override
  String get enterCode => 'أدخل كود التحقق';

  @override
  String get codeSentTo => 'أرسلنا كوداً من 6 أرقام إلى';

  @override
  String get verify => 'تحقق واربط الحساب';

  @override
  String get resendCode => 'إعادة إرسال الكود';

  @override
  String get demoCodeNote =>
      'في الوضع التجريبي لا يُرسل بريد حقيقي. اضغط 📧 في الأعلى لرؤية الرسالة والكود.';

  @override
  String codeSent(String email) {
    return '📧 أُرسل كود التحقق إلى $email';
  }

  @override
  String get codeAlreadySent => 'الكود مُرسل مسبقاً إلى بريدك';

  @override
  String linkedTo(String family) {
    return 'تم ربطك بـ$family ✓';
  }

  @override
  String hello(String name) {
    return 'أهلاً $name';
  }

  @override
  String get demoWelcome => 'دخلت كمسؤول الأسرة في أسرة تجريبية';

  @override
  String get codeFromEmail => 'كود التحقق';

  @override
  String get errBadEmail => 'اكتب بريداً إلكترونياً صحيحاً.';

  @override
  String get errSetupNeeded => 'اكتب اسم الأسرة واسمك.';

  @override
  String get errRegisteredAsMember =>
      'هذا البريد مضاف كعضو. ارجع واختر «أحد أفراد الأسرة».';

  @override
  String get errRegisteredAsAdmin =>
      'هذا البريد مسجّل كمسؤول. ارجع واختر «مسؤول الأسرة».';

  @override
  String get errNotInvited =>
      'هذا البريد غير مضاف لأي أسرة. اطلب من مسؤول أسرتك إضافة بريدك من لوحته.';

  @override
  String errNotAdminOf(String family) {
    return 'هذا البريد غير مضاف كمسؤول في $family. اطلب من مسؤول الأسرة إضافتك.';
  }

  @override
  String get errBadCode => 'الكود غير صحيح. تأكد منه أو اطلب كوداً جديداً.';

  @override
  String get errCodeExpired => 'انتهت صلاحية الكود. اطلب كوداً جديداً.';

  @override
  String get errTooManyAttempts => 'تجاوزت عدد المحاولات. اطلب كوداً جديداً.';

  @override
  String get errRateLimited => 'طلبت أكواداً كثيرة. حاول بعد ساعة.';

  @override
  String errTooSoon(String seconds) {
    return 'انتظر $seconds ثانية قبل طلب كود جديد.';
  }

  @override
  String get errAlreadyRegistered => 'هذا البريد مسجّل مسبقاً. سجّل الدخول به.';

  @override
  String get errEmailTaken => 'هذا البريد مضاف مسبقاً';

  @override
  String get errNoPermission => 'لا تملك صلاحية هذا الإجراء.';

  @override
  String get errAlreadyDone => 'أرسلت هذه المهمة مسبقاً';

  @override
  String get errAlreadyDecided => 'تم البت في هذا الطلب مسبقاً';

  @override
  String get errCompOver => 'انتهى وقت المسابقة';

  @override
  String get errAlreadyEntered => 'شاركت في هذه المسابقة مسبقاً';

  @override
  String get errNetwork => 'تعذّر الاتصال. تحقق من الإنترنت وحاول مجدداً.';

  @override
  String get errUpload => 'تعذّر رفع الصورة، جرّب مرة أخرى.';

  @override
  String get errOwnerMustDeleteFamily =>
      'أنت المسؤول الرئيسي: احذف الأسرة كاملة بدلاً من حسابك.';

  @override
  String get errRemoved => 'لم تعد ضمن هذه الأسرة.';

  @override
  String get errGeneric => 'حدث خطأ غير متوقع. حاول مجدداً.';

  @override
  String get errNameEmail => 'اكتب الاسم وبريداً صحيحاً';

  @override
  String get errTaskInput => 'اكتب اسم المهمة ونقاطاً أكبر من صفر';

  @override
  String get errCompTitle => 'اكتب اسم المسابقة';

  @override
  String get errAlertBody => 'اكتب نص التنبيه';

  @override
  String get errTierInput => 'اكتب اسم المكافأة وحدّاً أدنى من النقاط';

  @override
  String get errFbShort => 'اكتب رسالتك أولاً';

  @override
  String get errFbEmail => 'البريد غير صحيح، صحّحه أو اتركه فارغاً';

  @override
  String get errImage => 'تعذّر قراءة الصورة، جرّب صورة أخرى';

  @override
  String get adminDashboard => 'لوحة المسؤول';

  @override
  String get statMembers => 'أعضاء';

  @override
  String get statTodayPoints => 'نقاط اليوم';

  @override
  String get statActiveComps => 'مسابقات جارية';

  @override
  String get yourPerms => 'صلاحياتك المفوَّضة:';

  @override
  String get viewTasksOnly => 'عرض المهام فقط';

  @override
  String get backToDashboard => '‹ لوحة المسؤول';

  @override
  String get tileApprovals => 'الموافقات';

  @override
  String get tileAddAdmin => 'إضافة مسؤول أسرة';

  @override
  String get tileAddMember => 'إضافة عضو أسرة';

  @override
  String get tileReports => 'تقارير الإنجاز';

  @override
  String get tileSendReport => 'إرسال ترتيب اليوم';

  @override
  String get tileTasks => 'مهام أفراد الأسرة';

  @override
  String get tileAlerts => 'إرسال تنبيه';

  @override
  String get tileComps => 'المسابقات';

  @override
  String get tileRewards => 'الجوائز والمكافآت';

  @override
  String get permAddMembers => 'إضافة أعضاء للأسرة';

  @override
  String get permApprove => 'الموافقة على إنجاز المهام';

  @override
  String get permTasks => 'إضافة وتعديل وحذف المهام';

  @override
  String get permReport => 'إرسال تقرير الترتيب اليومي';

  @override
  String get permComps => 'إنشاء مسابقات';

  @override
  String get permViewReports => 'الاطلاع على التقارير';

  @override
  String get approvalsEmpty =>
      'لا شيء بانتظارك. عندما ينجز أحد الأعضاء مهمة ستظهر هنا.';

  @override
  String get tasksAwaiting => 'مهام تنتظر موافقتك';

  @override
  String get compAchievements => 'إنجازات المسابقات';

  @override
  String pointsPlus(String points) {
    return '+$points نقطة';
  }

  @override
  String get photoAttached => '📷 مرفقة';

  @override
  String get approve => 'موافقة';

  @override
  String get reject => 'رفض';

  @override
  String get approveBtn => '✓ موافقة';

  @override
  String get rejectBtn => '✕ رفض';

  @override
  String get viewPhoto => 'عرض صورة الإنجاز';

  @override
  String place(String rank) {
    return 'المركز $rank';
  }

  @override
  String approvedToast(String points, String name) {
    return 'تمت الموافقة! +$points نقاط لـ$name 🎉';
  }

  @override
  String get rejectedToast => 'أُعيدت المهمة ليحاول مرة أخرى';

  @override
  String entryApprovedToast(String points, String name) {
    return '+$points نقطة لـ$name 🏆';
  }

  @override
  String get addAdminSub =>
      'يصله كود على بريده، ويدخل به من خيار «مسؤول الأسرة».';

  @override
  String get nameHint => 'الاسم';

  @override
  String get adminNameHint => 'الاسم، مثل: أم أصيل';

  @override
  String get avatarLabel => 'الرمز';

  @override
  String get emailHint2 => 'email@example.com';

  @override
  String get delegatedPerms => 'الصلاحيات المفوَّضة';

  @override
  String get viewOnlyNote =>
      'اختيار «الاطلاع على التقارير» وحده يجعله مسؤولاً للاطلاع فقط.';

  @override
  String get addAndSend => 'إضافة وإرسال الكود';

  @override
  String get admins => 'المسؤولون';

  @override
  String get mainOwner => 'المسؤول الرئيسي · كل الصلاحيات';

  @override
  String get remove => 'إزالة';

  @override
  String get linked => 'مرتبط ✓';

  @override
  String get addMemberSub =>
      'يصله كود على بريده، ويدخل به من خيار «أحد أفراد الأسرة». اضغط على رمز أي عضو لتغييره.';

  @override
  String get familyMembersTitle => 'أعضاء الأسرة';

  @override
  String get noMembers => 'لم تُضف أي عضو بعد.';

  @override
  String confirmRemove(String name) {
    return 'إزالة $name من الأسرة؟';
  }

  @override
  String get cancel => 'إلغاء';

  @override
  String permsUpdated(String name) {
    return 'حُدّثت صلاحيات $name';
  }

  @override
  String inviteSent(String email) {
    return '📧 أُرسل كود التحقق إلى $email';
  }

  @override
  String get today => 'اليوم';

  @override
  String get thisWeek => 'هذا الأسبوع';

  @override
  String get familyTotal => 'مجموع نقاط الأسرة';

  @override
  String get achievements => 'إنجاز';

  @override
  String get familyEarned => 'الأسرة استحقت:';

  @override
  String get ranking => 'الترتيب';

  @override
  String get reportsEmpty => 'أضف أعضاء للأسرة لتظهر التقارير.';

  @override
  String countAchievements(String n) {
    return '$n إنجاز';
  }

  @override
  String earnedTier(String tier) {
    return 'استحق $tier';
  }

  @override
  String get sendReportSub => 'يصل هذا التقرير كتنبيه لكل أعضاء الأسرة.';

  @override
  String get sendToAll => 'إرسال لكل الأعضاء';

  @override
  String get reportSent => 'أُرسل التقرير لكل الأعضاء';

  @override
  String reportTitleLine(String date) {
    return 'ترتيب إنجاز اليوم — $date';
  }

  @override
  String reportLine(String medal, String name, String points, String n) {
    return '$medal $name: $points نقطة ($n إنجاز)';
  }

  @override
  String reportTotal(String points) {
    return 'مجموع الأسرة: $points نقطة';
  }

  @override
  String get reportNoMembers => 'لا يوجد أعضاء بعد.';

  @override
  String get tasksEditSub => 'أضف أو عدّل أو احذف مهام أي عضو.';

  @override
  String get tasksViewOnly => 'عرض فقط — لا تملك صلاحية تعديل المهام.';

  @override
  String get addMembersFirst => 'أضف أعضاء للأسرة أولاً.';

  @override
  String get taskTitleHint => 'اسم المهمة، مثل: ترتيب الغرفة';

  @override
  String get allMembers => 'كل الأعضاء';

  @override
  String get dailyF => 'يومية';

  @override
  String get weeklyF => 'أسبوعية';

  @override
  String get points => 'النقاط';

  @override
  String get addTask => 'إضافة المهمة';

  @override
  String get noTasks => 'لا توجد مهام.';

  @override
  String get save => 'حفظ';

  @override
  String get notDone => 'لم تُنجز';

  @override
  String get waiting => '⏳ بانتظار';

  @override
  String get doneCheck => 'منجزة ✓';

  @override
  String taskMeta(String repeat, String points) {
    return '$repeat · $points نقطة';
  }

  @override
  String get taskAdded => 'أُضيفت المهمة ✓';

  @override
  String get taskSaved => 'حُفظت التعديلات ✓';

  @override
  String get edit => 'تعديل';

  @override
  String get delete => 'حذف';

  @override
  String get forWhom => 'لمن';

  @override
  String get repeat => 'التكرار';

  @override
  String get alertBodyHint =>
      'نص التنبيه، مثل: لا تنسون ترتيب المجلس قبل وصول الضيوف';

  @override
  String get sendAlert => 'إرسال التنبيه';

  @override
  String get lastSent => 'آخر ما أُرسل';

  @override
  String get toAll => 'للجميع';

  @override
  String toName(String name) {
    return 'إلى $name';
  }

  @override
  String get noAlerts => 'لم تُرسل أي تنبيهات بعد.';

  @override
  String get alertSentAll => 'أُرسل التنبيه لكل الأعضاء';

  @override
  String alertSentTo(String name) {
    return 'أُرسل التنبيه إلى $name';
  }

  @override
  String get to => 'إلى';

  @override
  String get compsSub =>
      'أول من ينجز يأخذ نقاط البداية، والتالي أقل بنقطة، وهكذا.';

  @override
  String get compTitleHint => 'المسابقة، مثل: أسرع من يرتّب غرفته';

  @override
  String get firstPlacePoints => 'نقاط المركز الأول';

  @override
  String get timerMinutes => 'المؤقت بالدقائق (اختياري)';

  @override
  String get noTimer => 'بدون مؤقت';

  @override
  String get launchComp => 'إطلاق المسابقة';

  @override
  String get noComps => 'لا توجد مسابقات بعد.';

  @override
  String get running => 'جارية';

  @override
  String get ended => 'انتهت';

  @override
  String nextPlaceGets(String points) {
    return 'المركز القادم يحصل على $points نقطة';
  }

  @override
  String yourPlace(String rank, String points) {
    return 'مركزك $rank · $points نقطة';
  }

  @override
  String get iDidIt => 'أنجزت!';

  @override
  String get nobodyYet => 'لم ينجز أحد بعد.';

  @override
  String get rejectedTag => 'مرفوض';

  @override
  String get endComp => 'إنهاء المسابقة';

  @override
  String get compLaunched => 'انطلقت المسابقة وأُبلغ الجميع 🏁';

  @override
  String get compEnded => 'انتهت المسابقة';

  @override
  String yourRankToast(String rank, String points) {
    return 'مركزك $rank — $points نقطة بانتظار الموافقة';
  }

  @override
  String get timeUp => 'انتهى الوقت';

  @override
  String get noCompsMember => 'لا توجد مسابقات الآن. ترقّب التنبيهات!';

  @override
  String get pastComps => 'مسابقات سابقة';

  @override
  String get rewardsSub =>
      'حدّد مستويات بالنقاط. من يصل لمستوى أعلى يستحق مكافأته، ومن يقل عنه يأخذ المستوى الذي تحته.';

  @override
  String get rewardNameHint => 'المكافأة، مثل: نزهة';

  @override
  String get icon => 'الأيقونة';

  @override
  String get minPoints => 'الحد الأدنى من النقاط';

  @override
  String get period => 'الفترة';

  @override
  String get countedFor => 'تُحسب النقاط';

  @override
  String get scopeEach => 'لكل فرد على حدة';

  @override
  String get scopeFamily => 'لمجموع نقاط الأسرة';

  @override
  String get addTier => 'إضافة المستوى';

  @override
  String get noTiers => 'لا توجد مستويات مكافآت بعد.';

  @override
  String get groupEach => 'لكل فرد';

  @override
  String get groupFamily => 'لمجموع الأسرة';

  @override
  String tierPoints(String points) {
    return '$points+ نقطة';
  }

  @override
  String get dueNow => 'المستحقون الآن';

  @override
  String get wholeFamily => '👨‍👩‍👧 الأسرة كاملة';

  @override
  String get delivered => 'سُلّمت ✓';

  @override
  String get markDelivered => 'تم التسليم';

  @override
  String get noDue => 'لم يصل أحد لأي مستوى بعد.';

  @override
  String get tierAdded => 'أُضيف المستوى ✓';

  @override
  String get deliveredToast => 'سُجّل التسليم ✓';

  @override
  String get daily => 'يومي';

  @override
  String get weekly => 'أسبوعي';

  @override
  String get weekPoints => 'نقاط الأسبوع';

  @override
  String helloMember(String name) {
    return 'أهلاً $name';
  }

  @override
  String todaySummary(String points, String done, String total) {
    return 'اليوم: $points نقطة · أنجزت $done من $total';
  }

  @override
  String get tabMyTasks => 'مهامي';

  @override
  String get tabComps => 'المسابقات';

  @override
  String get tabRewards => 'المكافآت';

  @override
  String get tabNotices => 'التنبيهات';

  @override
  String get noTasksNow => 'لا توجد مهام لك الآن.';

  @override
  String get doneIt => 'أنجزتها';

  @override
  String get doneWithPhoto => 'أنجزتها مع صورة';

  @override
  String get awaitingApproval => 'بانتظار الموافقة ⏳';

  @override
  String get todayLabel => 'اليوم';

  @override
  String get weekLabel => 'هذا الأسبوع';

  @override
  String get photoOptional => '📷 تقدر ترفق صورة للمهمة كإثبات، وهذا اختياري.';

  @override
  String get sentForApproval => 'أُرسلت للمسؤول بانتظار الموافقة ⏳';

  @override
  String get sentWithPhoto => 'أُرسلت مع الصورة للمسؤول ⏳';

  @override
  String get rewardToday => 'مكافأة اليوم';

  @override
  String get rewardWeek => 'مكافأة الأسبوع';

  @override
  String get forWholeFamily => ' · للأسرة كاملة';

  @override
  String get yourPoints => 'نقاطك';

  @override
  String get familyPoints => 'نقاط الأسرة';

  @override
  String youEarned(String tier) {
    return 'استحققت: $tier';
  }

  @override
  String get notYet => 'لم تصل لأي مستوى بعد';

  @override
  String remainingFor(String n, String tier) {
    return ' · باقي $n نقطة لـ$tier';
  }

  @override
  String get noRewardsYet => 'لم يحدد المسؤول مكافآت بعد.';

  @override
  String get noNotices => 'لا توجد تنبيهات.';

  @override
  String get camera => 'الكاميرا';

  @override
  String get gallery => 'المعرض';

  @override
  String get attachProof => 'إرفاق صورة إثبات';

  @override
  String get now => 'الآن';

  @override
  String minutesAgo(String n) {
    return 'قبل $n دقيقة';
  }

  @override
  String hoursAgo(String n) {
    return 'قبل $n ساعة';
  }

  @override
  String chooseAvatarFor(String name) {
    return 'اختر رمزاً لـ$name';
  }

  @override
  String get avatarChangedMine => 'تغيّر رمزك ✓';

  @override
  String avatarChanged(String name) {
    return 'تغيّر رمز $name ✓';
  }

  @override
  String get close => 'إغلاق';

  @override
  String get fbIntro => 'رسالتك تصل مباشرة لفريق أسرتي، ونقرأ كل رسالة.';

  @override
  String get fbSuggestion => 'اقتراح';

  @override
  String get fbComplaint => 'شكوى';

  @override
  String get fbBug => 'مشكلة تقنية';

  @override
  String get fbTextHint =>
      'اكتب رسالتك هنا… مثلاً: أتمنى إضافة مهام خاصة برمضان';

  @override
  String get fbEmailHint => 'بريدك للرد عليك (اختياري)';

  @override
  String get send => 'إرسال';

  @override
  String get fbPrevious => 'رسائلك السابقة';

  @override
  String fbSentAgo(String ago) {
    return 'أُرسلت · $ago';
  }

  @override
  String get fbThanks => 'وصلت رسالتك ✓ شكراً لمساعدتنا في تحسين أسرتي';

  @override
  String get mailboxNote =>
      'يحاكي الرسائل التي سيرسلها التطبيق الحقيقي إلى بريد كل شخص.';

  @override
  String get noMail => 'لا توجد رسائل بعد.';

  @override
  String get mailTo => 'إلى:';

  @override
  String get appearance => 'المظهر';

  @override
  String get themeSystem => 'حسب الجهاز';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'ليلي';

  @override
  String get privacyPolicy => 'سياسة الخصوصية';

  @override
  String get deleteMyAccount => 'حذف حسابي';

  @override
  String get deleteAccountConfirm =>
      'سيُحذف حسابك وبياناتك من الأسرة نهائياً. هل أنت متأكد؟';

  @override
  String get deleteFamily => 'حذف الأسرة كاملة';

  @override
  String get deleteFamilyConfirm =>
      'ستُحذف الأسرة وكل أفرادها ومهامها ونقاطها نهائياً ولا يمكن التراجع. هل أنت متأكد؟';

  @override
  String get deleteConfirmBtn => 'حذف نهائي';

  @override
  String get deleted => 'تم الحذف';

  @override
  String get dangerZone => 'الحذف';

  @override
  String version(String v) {
    return 'الإصدار $v';
  }

  @override
  String get demoMode => 'الوضع التجريبي';

  @override
  String get demoBanner => 'أنت في التجربة السريعة — البيانات على جهازك فقط';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get taskPresets =>
      'ترتيب السرير|قراءة صفحة قرآن|صلاة الفجر في وقتها|مراجعة الواجبات|ترتيب المجلس|المساعدة في المطبخ|قراءة كتاب 15 دقيقة|ترتيب الألعاب';

  @override
  String memberTaskMeta(String when, String points) {
    return '$when · $points نقطة';
  }
}
