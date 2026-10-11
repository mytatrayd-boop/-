import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
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
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('ar')];

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'أسرتي'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In ar, this message translates to:
  /// **'مهام البيت… بروح التحدي'**
  String get tagline;

  /// No description provided for @feedback.
  ///
  /// In ar, this message translates to:
  /// **'اقتراحات وشكاوى'**
  String get feedback;

  /// No description provided for @demoMailbox.
  ///
  /// In ar, this message translates to:
  /// **'البريد التجريبي'**
  String get demoMailbox;

  /// No description provided for @signOut.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get signOut;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @familyMembers.
  ///
  /// In ar, this message translates to:
  /// **'أفراد الأسرة'**
  String get familyMembers;

  /// No description provided for @pendingVerification.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار التحقق'**
  String get pendingVerification;

  /// No description provided for @roleOwner.
  ///
  /// In ar, this message translates to:
  /// **'مسؤول الأسرة'**
  String get roleOwner;

  /// No description provided for @roleAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مسؤول مفوَّض'**
  String get roleAdmin;

  /// No description provided for @roleMember.
  ///
  /// In ar, this message translates to:
  /// **'عضو'**
  String get roleMember;

  /// No description provided for @changeMyAvatar.
  ///
  /// In ar, this message translates to:
  /// **'تغيير رمزي'**
  String get changeMyAvatar;

  /// No description provided for @changeAvatarOf.
  ///
  /// In ar, this message translates to:
  /// **'تغيير رمز {name}'**
  String changeAvatarOf(String name);

  /// No description provided for @welcome.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً بك في أسرتي'**
  String get welcome;

  /// No description provided for @howUse.
  ///
  /// In ar, this message translates to:
  /// **'كيف ستستخدم التطبيق؟'**
  String get howUse;

  /// No description provided for @chooseAdmin.
  ///
  /// In ar, this message translates to:
  /// **'مسؤول الأسرة'**
  String get chooseAdmin;

  /// No description provided for @chooseAdminSub.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ أسرتك، وزّع المهام، وأدر المكافآت والمسابقات'**
  String get chooseAdminSub;

  /// No description provided for @chooseMember.
  ///
  /// In ar, this message translates to:
  /// **'أحد أفراد الأسرة'**
  String get chooseMember;

  /// No description provided for @chooseMemberSub.
  ///
  /// In ar, this message translates to:
  /// **'انضم لأسرتك بالبريد الذي أضافه المسؤول'**
  String get chooseMemberSub;

  /// No description provided for @tryDemo.
  ///
  /// In ar, this message translates to:
  /// **'تجربة سريعة بأسرة جاهزة'**
  String get tryDemo;

  /// No description provided for @demoNote.
  ///
  /// In ar, this message translates to:
  /// **'التجربة السريعة تعمل على جهازك فقط، ولا تُرسل أي بيانات.'**
  String get demoNote;

  /// No description provided for @back.
  ///
  /// In ar, this message translates to:
  /// **'‹ رجوع'**
  String get back;

  /// No description provided for @loginAdmin.
  ///
  /// In ar, this message translates to:
  /// **'دخول مسؤول الأسرة'**
  String get loginAdmin;

  /// No description provided for @loginMember.
  ///
  /// In ar, this message translates to:
  /// **'دخول فرد من الأسرة'**
  String get loginMember;

  /// No description provided for @hintSetup.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ أسرتك الآن، وسنرسل كود تحقق إلى بريدك. إذا كنت مسؤولاً مضافاً في أسرة، اترك الاسمين فارغين.'**
  String get hintSetup;

  /// No description provided for @hintAdmin.
  ///
  /// In ar, this message translates to:
  /// **'أدخل بريدك المسجّل كمسؤول وسنرسل لك كود تحقق.'**
  String get hintAdmin;

  /// No description provided for @hintMember.
  ///
  /// In ar, this message translates to:
  /// **'أدخل البريد الذي أضافه مسؤول الأسرة وسنرسل لك كود تحقق.'**
  String get hintMember;

  /// No description provided for @familyNameHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم الأسرة، مثل: أسرة آل محمد'**
  String get familyNameHint;

  /// No description provided for @yourNameHint.
  ///
  /// In ar, this message translates to:
  /// **'اسمك، مثل: أبو أصيل'**
  String get yourNameHint;

  /// No description provided for @emailHint.
  ///
  /// In ar, this message translates to:
  /// **'name@example.com'**
  String get emailHint;

  /// No description provided for @email.
  ///
  /// In ar, this message translates to:
  /// **'البريد الإلكتروني'**
  String get email;

  /// No description provided for @sendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال كود التحقق'**
  String get sendCode;

  /// No description provided for @enterCode.
  ///
  /// In ar, this message translates to:
  /// **'أدخل كود التحقق'**
  String get enterCode;

  /// No description provided for @codeSentTo.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا كوداً من 6 أرقام إلى'**
  String get codeSentTo;

  /// No description provided for @verify.
  ///
  /// In ar, this message translates to:
  /// **'تحقق واربط الحساب'**
  String get verify;

  /// No description provided for @resendCode.
  ///
  /// In ar, this message translates to:
  /// **'إعادة إرسال الكود'**
  String get resendCode;

  /// No description provided for @demoCodeNote.
  ///
  /// In ar, this message translates to:
  /// **'في الوضع التجريبي لا يُرسل بريد حقيقي. اضغط 📧 في الأعلى لرؤية الرسالة والكود.'**
  String get demoCodeNote;

  /// No description provided for @codeSent.
  ///
  /// In ar, this message translates to:
  /// **'📧 أُرسل كود التحقق إلى {email}'**
  String codeSent(String email);

  /// No description provided for @codeAlreadySent.
  ///
  /// In ar, this message translates to:
  /// **'الكود مُرسل مسبقاً إلى بريدك'**
  String get codeAlreadySent;

  /// No description provided for @linkedTo.
  ///
  /// In ar, this message translates to:
  /// **'تم ربطك بـ{family} ✓'**
  String linkedTo(String family);

  /// No description provided for @hello.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً {name}'**
  String hello(String name);

  /// No description provided for @demoWelcome.
  ///
  /// In ar, this message translates to:
  /// **'دخلت كمسؤول الأسرة في أسرة تجريبية'**
  String get demoWelcome;

  /// No description provided for @codeFromEmail.
  ///
  /// In ar, this message translates to:
  /// **'كود التحقق'**
  String get codeFromEmail;

  /// No description provided for @errBadEmail.
  ///
  /// In ar, this message translates to:
  /// **'اكتب بريداً إلكترونياً صحيحاً.'**
  String get errBadEmail;

  /// No description provided for @errSetupNeeded.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم الأسرة واسمك.'**
  String get errSetupNeeded;

  /// No description provided for @errRegisteredAsMember.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد مضاف كعضو. ارجع واختر «أحد أفراد الأسرة».'**
  String get errRegisteredAsMember;

  /// No description provided for @errRegisteredAsAdmin.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد مسجّل كمسؤول. ارجع واختر «مسؤول الأسرة».'**
  String get errRegisteredAsAdmin;

  /// No description provided for @errNotInvited.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد غير مضاف لأي أسرة. اطلب من مسؤول أسرتك إضافة بريدك من لوحته.'**
  String get errNotInvited;

  /// No description provided for @errNotAdminOf.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد غير مضاف كمسؤول في {family}. اطلب من مسؤول الأسرة إضافتك.'**
  String errNotAdminOf(String family);

  /// No description provided for @errBadCode.
  ///
  /// In ar, this message translates to:
  /// **'الكود غير صحيح. تأكد منه أو اطلب كوداً جديداً.'**
  String get errBadCode;

  /// No description provided for @errCodeExpired.
  ///
  /// In ar, this message translates to:
  /// **'انتهت صلاحية الكود. اطلب كوداً جديداً.'**
  String get errCodeExpired;

  /// No description provided for @errTooManyAttempts.
  ///
  /// In ar, this message translates to:
  /// **'تجاوزت عدد المحاولات. اطلب كوداً جديداً.'**
  String get errTooManyAttempts;

  /// No description provided for @errRateLimited.
  ///
  /// In ar, this message translates to:
  /// **'طلبت أكواداً كثيرة. حاول بعد ساعة.'**
  String get errRateLimited;

  /// No description provided for @errTooSoon.
  ///
  /// In ar, this message translates to:
  /// **'انتظر {seconds} ثانية قبل طلب كود جديد.'**
  String errTooSoon(String seconds);

  /// No description provided for @errAlreadyRegistered.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد مسجّل مسبقاً. سجّل الدخول به.'**
  String get errAlreadyRegistered;

  /// No description provided for @errEmailTaken.
  ///
  /// In ar, this message translates to:
  /// **'هذا البريد مضاف مسبقاً'**
  String get errEmailTaken;

  /// No description provided for @errNoPermission.
  ///
  /// In ar, this message translates to:
  /// **'لا تملك صلاحية هذا الإجراء.'**
  String get errNoPermission;

  /// No description provided for @errAlreadyDone.
  ///
  /// In ar, this message translates to:
  /// **'أرسلت هذه المهمة مسبقاً'**
  String get errAlreadyDone;

  /// No description provided for @errAlreadyDecided.
  ///
  /// In ar, this message translates to:
  /// **'تم البت في هذا الطلب مسبقاً'**
  String get errAlreadyDecided;

  /// No description provided for @errCompOver.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقت المسابقة'**
  String get errCompOver;

  /// No description provided for @errAlreadyEntered.
  ///
  /// In ar, this message translates to:
  /// **'شاركت في هذه المسابقة مسبقاً'**
  String get errAlreadyEntered;

  /// No description provided for @errNetwork.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال. تحقق من الإنترنت وحاول مجدداً.'**
  String get errNetwork;

  /// No description provided for @errUpload.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر رفع الصورة، جرّب مرة أخرى.'**
  String get errUpload;

  /// No description provided for @errOwnerMustDeleteFamily.
  ///
  /// In ar, this message translates to:
  /// **'أنت المسؤول الرئيسي: احذف الأسرة كاملة بدلاً من حسابك.'**
  String get errOwnerMustDeleteFamily;

  /// No description provided for @errRemoved.
  ///
  /// In ar, this message translates to:
  /// **'لم تعد ضمن هذه الأسرة.'**
  String get errRemoved;

  /// No description provided for @errGeneric.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع. حاول مجدداً.'**
  String get errGeneric;

  /// No description provided for @errGenericCode.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع ({code}). حاول مجدداً، وإن تكرر أرسل صورة هذه الرسالة.'**
  String errGenericCode(String code);

  /// No description provided for @errNameEmail.
  ///
  /// In ar, this message translates to:
  /// **'اكتب الاسم وبريداً صحيحاً'**
  String get errNameEmail;

  /// No description provided for @errTaskInput.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم المهمة ونقاطاً أكبر من صفر'**
  String get errTaskInput;

  /// No description provided for @errCompTitle.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم المسابقة'**
  String get errCompTitle;

  /// No description provided for @errAlertBody.
  ///
  /// In ar, this message translates to:
  /// **'اكتب نص التنبيه'**
  String get errAlertBody;

  /// No description provided for @errTierInput.
  ///
  /// In ar, this message translates to:
  /// **'اكتب اسم المكافأة وحدّاً أدنى من النقاط'**
  String get errTierInput;

  /// No description provided for @errFbShort.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك أولاً'**
  String get errFbShort;

  /// No description provided for @errFbEmail.
  ///
  /// In ar, this message translates to:
  /// **'البريد غير صحيح، صحّحه أو اتركه فارغاً'**
  String get errFbEmail;

  /// No description provided for @errImage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر قراءة الصورة، جرّب صورة أخرى'**
  String get errImage;

  /// No description provided for @adminDashboard.
  ///
  /// In ar, this message translates to:
  /// **'لوحة المسؤول'**
  String get adminDashboard;

  /// No description provided for @statMembers.
  ///
  /// In ar, this message translates to:
  /// **'أعضاء'**
  String get statMembers;

  /// No description provided for @statTodayPoints.
  ///
  /// In ar, this message translates to:
  /// **'نقاط اليوم'**
  String get statTodayPoints;

  /// No description provided for @statActiveComps.
  ///
  /// In ar, this message translates to:
  /// **'مسابقات جارية'**
  String get statActiveComps;

  /// No description provided for @yourPerms.
  ///
  /// In ar, this message translates to:
  /// **'صلاحياتك المفوَّضة:'**
  String get yourPerms;

  /// No description provided for @viewTasksOnly.
  ///
  /// In ar, this message translates to:
  /// **'عرض المهام فقط'**
  String get viewTasksOnly;

  /// No description provided for @backToDashboard.
  ///
  /// In ar, this message translates to:
  /// **'‹ لوحة المسؤول'**
  String get backToDashboard;

  /// No description provided for @tileApprovals.
  ///
  /// In ar, this message translates to:
  /// **'الموافقات'**
  String get tileApprovals;

  /// No description provided for @tileAddAdmin.
  ///
  /// In ar, this message translates to:
  /// **'إضافة مسؤول أسرة'**
  String get tileAddAdmin;

  /// No description provided for @tileAddMember.
  ///
  /// In ar, this message translates to:
  /// **'إضافة عضو أسرة'**
  String get tileAddMember;

  /// No description provided for @tileReports.
  ///
  /// In ar, this message translates to:
  /// **'تقارير الإنجاز'**
  String get tileReports;

  /// No description provided for @tileSendReport.
  ///
  /// In ar, this message translates to:
  /// **'إرسال ترتيب اليوم'**
  String get tileSendReport;

  /// No description provided for @tileTasks.
  ///
  /// In ar, this message translates to:
  /// **'مهام أفراد الأسرة'**
  String get tileTasks;

  /// No description provided for @tileAlerts.
  ///
  /// In ar, this message translates to:
  /// **'إرسال تنبيه'**
  String get tileAlerts;

  /// No description provided for @tileComps.
  ///
  /// In ar, this message translates to:
  /// **'المسابقات'**
  String get tileComps;

  /// No description provided for @tileRewards.
  ///
  /// In ar, this message translates to:
  /// **'الجوائز والمكافآت'**
  String get tileRewards;

  /// No description provided for @permAddMembers.
  ///
  /// In ar, this message translates to:
  /// **'إضافة أعضاء للأسرة'**
  String get permAddMembers;

  /// No description provided for @permApprove.
  ///
  /// In ar, this message translates to:
  /// **'الموافقة على إنجاز المهام'**
  String get permApprove;

  /// No description provided for @permTasks.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وتعديل وحذف المهام'**
  String get permTasks;

  /// No description provided for @permReport.
  ///
  /// In ar, this message translates to:
  /// **'إرسال تقرير الترتيب اليومي'**
  String get permReport;

  /// No description provided for @permComps.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء مسابقات'**
  String get permComps;

  /// No description provided for @permViewReports.
  ///
  /// In ar, this message translates to:
  /// **'الاطلاع على التقارير'**
  String get permViewReports;

  /// No description provided for @approvalsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء بانتظارك. عندما ينجز أحد الأعضاء مهمة ستظهر هنا.'**
  String get approvalsEmpty;

  /// No description provided for @tasksAwaiting.
  ///
  /// In ar, this message translates to:
  /// **'مهام تنتظر موافقتك'**
  String get tasksAwaiting;

  /// No description provided for @compAchievements.
  ///
  /// In ar, this message translates to:
  /// **'إنجازات المسابقات'**
  String get compAchievements;

  /// No description provided for @pointsPlus.
  ///
  /// In ar, this message translates to:
  /// **'+{points} نقطة'**
  String pointsPlus(String points);

  /// No description provided for @photoAttached.
  ///
  /// In ar, this message translates to:
  /// **'📷 مرفقة'**
  String get photoAttached;

  /// No description provided for @approve.
  ///
  /// In ar, this message translates to:
  /// **'موافقة'**
  String get approve;

  /// No description provided for @reject.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get reject;

  /// No description provided for @approveBtn.
  ///
  /// In ar, this message translates to:
  /// **'✓ موافقة'**
  String get approveBtn;

  /// No description provided for @rejectBtn.
  ///
  /// In ar, this message translates to:
  /// **'✕ رفض'**
  String get rejectBtn;

  /// No description provided for @viewPhoto.
  ///
  /// In ar, this message translates to:
  /// **'عرض صورة الإنجاز'**
  String get viewPhoto;

  /// No description provided for @place.
  ///
  /// In ar, this message translates to:
  /// **'المركز {rank}'**
  String place(String rank);

  /// No description provided for @approvedToast.
  ///
  /// In ar, this message translates to:
  /// **'تمت الموافقة! +{points} نقاط لـ{name} 🎉'**
  String approvedToast(String points, String name);

  /// No description provided for @rejectedToast.
  ///
  /// In ar, this message translates to:
  /// **'أُعيدت المهمة ليحاول مرة أخرى'**
  String get rejectedToast;

  /// No description provided for @entryApprovedToast.
  ///
  /// In ar, this message translates to:
  /// **'+{points} نقطة لـ{name} 🏆'**
  String entryApprovedToast(String points, String name);

  /// No description provided for @addAdminSub.
  ///
  /// In ar, this message translates to:
  /// **'يصله كود على بريده، ويدخل به من خيار «مسؤول الأسرة».'**
  String get addAdminSub;

  /// No description provided for @nameHint.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get nameHint;

  /// No description provided for @adminNameHint.
  ///
  /// In ar, this message translates to:
  /// **'الاسم، مثل: أم أصيل'**
  String get adminNameHint;

  /// No description provided for @avatarLabel.
  ///
  /// In ar, this message translates to:
  /// **'الرمز'**
  String get avatarLabel;

  /// No description provided for @emailHint2.
  ///
  /// In ar, this message translates to:
  /// **'email@example.com'**
  String get emailHint2;

  /// No description provided for @delegatedPerms.
  ///
  /// In ar, this message translates to:
  /// **'الصلاحيات المفوَّضة'**
  String get delegatedPerms;

  /// No description provided for @viewOnlyNote.
  ///
  /// In ar, this message translates to:
  /// **'اختيار «الاطلاع على التقارير» وحده يجعله مسؤولاً للاطلاع فقط.'**
  String get viewOnlyNote;

  /// No description provided for @addAndSend.
  ///
  /// In ar, this message translates to:
  /// **'إضافة وإرسال الكود'**
  String get addAndSend;

  /// No description provided for @admins.
  ///
  /// In ar, this message translates to:
  /// **'المسؤولون'**
  String get admins;

  /// No description provided for @mainOwner.
  ///
  /// In ar, this message translates to:
  /// **'المسؤول الرئيسي · كل الصلاحيات'**
  String get mainOwner;

  /// No description provided for @remove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get remove;

  /// No description provided for @linked.
  ///
  /// In ar, this message translates to:
  /// **'مرتبط ✓'**
  String get linked;

  /// No description provided for @addMemberSub.
  ///
  /// In ar, this message translates to:
  /// **'يصله كود على بريده، ويدخل به من خيار «أحد أفراد الأسرة». اضغط على رمز أي عضو لتغييره.'**
  String get addMemberSub;

  /// No description provided for @familyMembersTitle.
  ///
  /// In ar, this message translates to:
  /// **'أعضاء الأسرة'**
  String get familyMembersTitle;

  /// No description provided for @noMembers.
  ///
  /// In ar, this message translates to:
  /// **'لم تُضف أي عضو بعد.'**
  String get noMembers;

  /// No description provided for @confirmRemove.
  ///
  /// In ar, this message translates to:
  /// **'إزالة {name} من الأسرة؟'**
  String confirmRemove(String name);

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @permsUpdated.
  ///
  /// In ar, this message translates to:
  /// **'حُدّثت صلاحيات {name}'**
  String permsUpdated(String name);

  /// No description provided for @inviteSent.
  ///
  /// In ar, this message translates to:
  /// **'📧 أُرسل كود التحقق إلى {email}'**
  String inviteSent(String email);

  /// No description provided for @today.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get thisWeek;

  /// No description provided for @familyTotal.
  ///
  /// In ar, this message translates to:
  /// **'مجموع نقاط الأسرة'**
  String get familyTotal;

  /// No description provided for @achievements.
  ///
  /// In ar, this message translates to:
  /// **'إنجاز'**
  String get achievements;

  /// No description provided for @familyEarned.
  ///
  /// In ar, this message translates to:
  /// **'الأسرة استحقت:'**
  String get familyEarned;

  /// No description provided for @ranking.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get ranking;

  /// No description provided for @reportsEmpty.
  ///
  /// In ar, this message translates to:
  /// **'أضف أعضاء للأسرة لتظهر التقارير.'**
  String get reportsEmpty;

  /// No description provided for @countAchievements.
  ///
  /// In ar, this message translates to:
  /// **'{n} إنجاز'**
  String countAchievements(String n);

  /// No description provided for @earnedTier.
  ///
  /// In ar, this message translates to:
  /// **'استحق {tier}'**
  String earnedTier(String tier);

  /// No description provided for @sendReportSub.
  ///
  /// In ar, this message translates to:
  /// **'يصل هذا التقرير كتنبيه لكل أعضاء الأسرة.'**
  String get sendReportSub;

  /// No description provided for @sendToAll.
  ///
  /// In ar, this message translates to:
  /// **'إرسال لكل الأعضاء'**
  String get sendToAll;

  /// No description provided for @reportSent.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل التقرير لكل الأعضاء'**
  String get reportSent;

  /// No description provided for @reportTitleLine.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب إنجاز اليوم — {date}'**
  String reportTitleLine(String date);

  /// No description provided for @reportLine.
  ///
  /// In ar, this message translates to:
  /// **'{medal} {name}: {points} نقطة ({n} إنجاز)'**
  String reportLine(String medal, String name, String points, String n);

  /// No description provided for @reportTotal.
  ///
  /// In ar, this message translates to:
  /// **'مجموع الأسرة: {points} نقطة'**
  String reportTotal(String points);

  /// No description provided for @reportNoMembers.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أعضاء بعد.'**
  String get reportNoMembers;

  /// No description provided for @tasksEditSub.
  ///
  /// In ar, this message translates to:
  /// **'أضف أو عدّل أو احذف مهام أي عضو.'**
  String get tasksEditSub;

  /// No description provided for @tasksViewOnly.
  ///
  /// In ar, this message translates to:
  /// **'عرض فقط — لا تملك صلاحية تعديل المهام.'**
  String get tasksViewOnly;

  /// No description provided for @addMembersFirst.
  ///
  /// In ar, this message translates to:
  /// **'أضف أعضاء للأسرة أولاً.'**
  String get addMembersFirst;

  /// No description provided for @taskTitleHint.
  ///
  /// In ar, this message translates to:
  /// **'اسم المهمة، مثل: ترتيب الغرفة'**
  String get taskTitleHint;

  /// No description provided for @allMembers.
  ///
  /// In ar, this message translates to:
  /// **'كل الأعضاء'**
  String get allMembers;

  /// No description provided for @dailyF.
  ///
  /// In ar, this message translates to:
  /// **'يومية'**
  String get dailyF;

  /// No description provided for @weeklyF.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعية'**
  String get weeklyF;

  /// No description provided for @points.
  ///
  /// In ar, this message translates to:
  /// **'النقاط'**
  String get points;

  /// No description provided for @addTask.
  ///
  /// In ar, this message translates to:
  /// **'إضافة المهمة'**
  String get addTask;

  /// No description provided for @noTasks.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مهام.'**
  String get noTasks;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @notDone.
  ///
  /// In ar, this message translates to:
  /// **'لم تُنجز'**
  String get notDone;

  /// No description provided for @waiting.
  ///
  /// In ar, this message translates to:
  /// **'⏳ بانتظار'**
  String get waiting;

  /// No description provided for @doneCheck.
  ///
  /// In ar, this message translates to:
  /// **'منجزة ✓'**
  String get doneCheck;

  /// No description provided for @taskMeta.
  ///
  /// In ar, this message translates to:
  /// **'{repeat} · {points} نقطة'**
  String taskMeta(String repeat, String points);

  /// No description provided for @taskAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيفت المهمة ✓'**
  String get taskAdded;

  /// No description provided for @taskSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت التعديلات ✓'**
  String get taskSaved;

  /// No description provided for @edit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @forWhom.
  ///
  /// In ar, this message translates to:
  /// **'لمن'**
  String get forWhom;

  /// No description provided for @repeat.
  ///
  /// In ar, this message translates to:
  /// **'التكرار'**
  String get repeat;

  /// No description provided for @alertBodyHint.
  ///
  /// In ar, this message translates to:
  /// **'نص التنبيه، مثل: لا تنسون ترتيب المجلس قبل وصول الضيوف'**
  String get alertBodyHint;

  /// No description provided for @sendAlert.
  ///
  /// In ar, this message translates to:
  /// **'إرسال التنبيه'**
  String get sendAlert;

  /// No description provided for @lastSent.
  ///
  /// In ar, this message translates to:
  /// **'آخر ما أُرسل'**
  String get lastSent;

  /// No description provided for @toAll.
  ///
  /// In ar, this message translates to:
  /// **'للجميع'**
  String get toAll;

  /// No description provided for @toName.
  ///
  /// In ar, this message translates to:
  /// **'إلى {name}'**
  String toName(String name);

  /// No description provided for @noAlerts.
  ///
  /// In ar, this message translates to:
  /// **'لم تُرسل أي تنبيهات بعد.'**
  String get noAlerts;

  /// No description provided for @alertSentAll.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل التنبيه لكل الأعضاء'**
  String get alertSentAll;

  /// No description provided for @alertSentTo.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل التنبيه إلى {name}'**
  String alertSentTo(String name);

  /// No description provided for @to.
  ///
  /// In ar, this message translates to:
  /// **'إلى'**
  String get to;

  /// No description provided for @compsSub.
  ///
  /// In ar, this message translates to:
  /// **'أول من ينجز يأخذ نقاط البداية، والتالي أقل بنقطة، وهكذا.'**
  String get compsSub;

  /// No description provided for @compTitleHint.
  ///
  /// In ar, this message translates to:
  /// **'المسابقة، مثل: أسرع من يرتّب غرفته'**
  String get compTitleHint;

  /// No description provided for @firstPlacePoints.
  ///
  /// In ar, this message translates to:
  /// **'نقاط المركز الأول'**
  String get firstPlacePoints;

  /// No description provided for @timerMinutes.
  ///
  /// In ar, this message translates to:
  /// **'المؤقت بالدقائق (اختياري)'**
  String get timerMinutes;

  /// No description provided for @noTimer.
  ///
  /// In ar, this message translates to:
  /// **'بدون مؤقت'**
  String get noTimer;

  /// No description provided for @launchComp.
  ///
  /// In ar, this message translates to:
  /// **'إطلاق المسابقة'**
  String get launchComp;

  /// No description provided for @noComps.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مسابقات بعد.'**
  String get noComps;

  /// No description provided for @running.
  ///
  /// In ar, this message translates to:
  /// **'جارية'**
  String get running;

  /// No description provided for @ended.
  ///
  /// In ar, this message translates to:
  /// **'انتهت'**
  String get ended;

  /// No description provided for @nextPlaceGets.
  ///
  /// In ar, this message translates to:
  /// **'المركز القادم يحصل على {points} نقطة'**
  String nextPlaceGets(String points);

  /// No description provided for @yourPlace.
  ///
  /// In ar, this message translates to:
  /// **'مركزك {rank} · {points} نقطة'**
  String yourPlace(String rank, String points);

  /// No description provided for @iDidIt.
  ///
  /// In ar, this message translates to:
  /// **'أنجزت!'**
  String get iDidIt;

  /// No description provided for @nobodyYet.
  ///
  /// In ar, this message translates to:
  /// **'لم ينجز أحد بعد.'**
  String get nobodyYet;

  /// No description provided for @rejectedTag.
  ///
  /// In ar, this message translates to:
  /// **'مرفوض'**
  String get rejectedTag;

  /// No description provided for @endComp.
  ///
  /// In ar, this message translates to:
  /// **'إنهاء المسابقة'**
  String get endComp;

  /// No description provided for @compLaunched.
  ///
  /// In ar, this message translates to:
  /// **'انطلقت المسابقة وأُبلغ الجميع 🏁'**
  String get compLaunched;

  /// No description provided for @compEnded.
  ///
  /// In ar, this message translates to:
  /// **'انتهت المسابقة'**
  String get compEnded;

  /// No description provided for @yourRankToast.
  ///
  /// In ar, this message translates to:
  /// **'مركزك {rank} — {points} نقطة بانتظار الموافقة'**
  String yourRankToast(String rank, String points);

  /// No description provided for @timeUp.
  ///
  /// In ar, this message translates to:
  /// **'انتهى الوقت'**
  String get timeUp;

  /// No description provided for @noCompsMember.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مسابقات الآن. ترقّب التنبيهات!'**
  String get noCompsMember;

  /// No description provided for @pastComps.
  ///
  /// In ar, this message translates to:
  /// **'مسابقات سابقة'**
  String get pastComps;

  /// No description provided for @rewardsSub.
  ///
  /// In ar, this message translates to:
  /// **'حدّد مستويات بالنقاط. من يصل لمستوى أعلى يستحق مكافأته، ومن يقل عنه يأخذ المستوى الذي تحته.'**
  String get rewardsSub;

  /// No description provided for @rewardNameHint.
  ///
  /// In ar, this message translates to:
  /// **'المكافأة، مثل: نزهة'**
  String get rewardNameHint;

  /// No description provided for @icon.
  ///
  /// In ar, this message translates to:
  /// **'الأيقونة'**
  String get icon;

  /// No description provided for @minPoints.
  ///
  /// In ar, this message translates to:
  /// **'الحد الأدنى من النقاط'**
  String get minPoints;

  /// No description provided for @period.
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get period;

  /// No description provided for @countedFor.
  ///
  /// In ar, this message translates to:
  /// **'تُحسب النقاط'**
  String get countedFor;

  /// No description provided for @scopeEach.
  ///
  /// In ar, this message translates to:
  /// **'لكل فرد على حدة'**
  String get scopeEach;

  /// No description provided for @scopeFamily.
  ///
  /// In ar, this message translates to:
  /// **'لمجموع نقاط الأسرة'**
  String get scopeFamily;

  /// No description provided for @addTier.
  ///
  /// In ar, this message translates to:
  /// **'إضافة المستوى'**
  String get addTier;

  /// No description provided for @noTiers.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مستويات مكافآت بعد.'**
  String get noTiers;

  /// No description provided for @groupEach.
  ///
  /// In ar, this message translates to:
  /// **'لكل فرد'**
  String get groupEach;

  /// No description provided for @groupFamily.
  ///
  /// In ar, this message translates to:
  /// **'لمجموع الأسرة'**
  String get groupFamily;

  /// No description provided for @tierPoints.
  ///
  /// In ar, this message translates to:
  /// **'{points}+ نقطة'**
  String tierPoints(String points);

  /// No description provided for @dueNow.
  ///
  /// In ar, this message translates to:
  /// **'المستحقون الآن'**
  String get dueNow;

  /// No description provided for @wholeFamily.
  ///
  /// In ar, this message translates to:
  /// **'👨‍👩‍👧 الأسرة كاملة'**
  String get wholeFamily;

  /// No description provided for @delivered.
  ///
  /// In ar, this message translates to:
  /// **'سُلّمت ✓'**
  String get delivered;

  /// No description provided for @markDelivered.
  ///
  /// In ar, this message translates to:
  /// **'تم التسليم'**
  String get markDelivered;

  /// No description provided for @noDue.
  ///
  /// In ar, this message translates to:
  /// **'لم يصل أحد لأي مستوى بعد.'**
  String get noDue;

  /// No description provided for @tierAdded.
  ///
  /// In ar, this message translates to:
  /// **'أُضيف المستوى ✓'**
  String get tierAdded;

  /// No description provided for @deliveredToast.
  ///
  /// In ar, this message translates to:
  /// **'سُجّل التسليم ✓'**
  String get deliveredToast;

  /// No description provided for @daily.
  ///
  /// In ar, this message translates to:
  /// **'يومي'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get weekly;

  /// No description provided for @weekPoints.
  ///
  /// In ar, this message translates to:
  /// **'نقاط الأسبوع'**
  String get weekPoints;

  /// No description provided for @helloMember.
  ///
  /// In ar, this message translates to:
  /// **'أهلاً {name}'**
  String helloMember(String name);

  /// No description provided for @todaySummary.
  ///
  /// In ar, this message translates to:
  /// **'اليوم: {points} نقطة · أنجزت {done} من {total}'**
  String todaySummary(String points, String done, String total);

  /// No description provided for @tabMyTasks.
  ///
  /// In ar, this message translates to:
  /// **'مهامي'**
  String get tabMyTasks;

  /// No description provided for @tabComps.
  ///
  /// In ar, this message translates to:
  /// **'المسابقات'**
  String get tabComps;

  /// No description provided for @tabRewards.
  ///
  /// In ar, this message translates to:
  /// **'المكافآت'**
  String get tabRewards;

  /// No description provided for @tabNotices.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get tabNotices;

  /// No description provided for @noTasksNow.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مهام لك الآن.'**
  String get noTasksNow;

  /// No description provided for @doneIt.
  ///
  /// In ar, this message translates to:
  /// **'أنجزتها'**
  String get doneIt;

  /// No description provided for @doneWithPhoto.
  ///
  /// In ar, this message translates to:
  /// **'أنجزتها مع صورة'**
  String get doneWithPhoto;

  /// No description provided for @awaitingApproval.
  ///
  /// In ar, this message translates to:
  /// **'بانتظار الموافقة ⏳'**
  String get awaitingApproval;

  /// No description provided for @todayLabel.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get todayLabel;

  /// No description provided for @weekLabel.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get weekLabel;

  /// No description provided for @photoOptional.
  ///
  /// In ar, this message translates to:
  /// **'📷 تقدر ترفق صورة للمهمة كإثبات، وهذا اختياري.'**
  String get photoOptional;

  /// No description provided for @sentForApproval.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت للمسؤول بانتظار الموافقة ⏳'**
  String get sentForApproval;

  /// No description provided for @sentWithPhoto.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت مع الصورة للمسؤول ⏳'**
  String get sentWithPhoto;

  /// No description provided for @rewardToday.
  ///
  /// In ar, this message translates to:
  /// **'مكافأة اليوم'**
  String get rewardToday;

  /// No description provided for @rewardWeek.
  ///
  /// In ar, this message translates to:
  /// **'مكافأة الأسبوع'**
  String get rewardWeek;

  /// No description provided for @forWholeFamily.
  ///
  /// In ar, this message translates to:
  /// **' · للأسرة كاملة'**
  String get forWholeFamily;

  /// No description provided for @yourPoints.
  ///
  /// In ar, this message translates to:
  /// **'نقاطك'**
  String get yourPoints;

  /// No description provided for @familyPoints.
  ///
  /// In ar, this message translates to:
  /// **'نقاط الأسرة'**
  String get familyPoints;

  /// No description provided for @youEarned.
  ///
  /// In ar, this message translates to:
  /// **'استحققت: {tier}'**
  String youEarned(String tier);

  /// No description provided for @notYet.
  ///
  /// In ar, this message translates to:
  /// **'لم تصل لأي مستوى بعد'**
  String get notYet;

  /// No description provided for @remainingFor.
  ///
  /// In ar, this message translates to:
  /// **' · باقي {n} نقطة لـ{tier}'**
  String remainingFor(String n, String tier);

  /// No description provided for @noRewardsYet.
  ///
  /// In ar, this message translates to:
  /// **'لم يحدد المسؤول مكافآت بعد.'**
  String get noRewardsYet;

  /// No description provided for @noNotices.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تنبيهات.'**
  String get noNotices;

  /// No description provided for @camera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In ar, this message translates to:
  /// **'المعرض'**
  String get gallery;

  /// No description provided for @attachProof.
  ///
  /// In ar, this message translates to:
  /// **'إرفاق صورة إثبات'**
  String get attachProof;

  /// No description provided for @now.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get now;

  /// No description provided for @minutesAgo.
  ///
  /// In ar, this message translates to:
  /// **'قبل {n} دقيقة'**
  String minutesAgo(String n);

  /// No description provided for @hoursAgo.
  ///
  /// In ar, this message translates to:
  /// **'قبل {n} ساعة'**
  String hoursAgo(String n);

  /// No description provided for @chooseAvatarFor.
  ///
  /// In ar, this message translates to:
  /// **'اختر رمزاً لـ{name}'**
  String chooseAvatarFor(String name);

  /// No description provided for @avatarChangedMine.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر رمزك ✓'**
  String get avatarChangedMine;

  /// No description provided for @avatarChanged.
  ///
  /// In ar, this message translates to:
  /// **'تغيّر رمز {name} ✓'**
  String avatarChanged(String name);

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @fbIntro.
  ///
  /// In ar, this message translates to:
  /// **'رسالتك تصل مباشرة لفريق أسرتي، ونقرأ كل رسالة.'**
  String get fbIntro;

  /// No description provided for @fbSuggestion.
  ///
  /// In ar, this message translates to:
  /// **'اقتراح'**
  String get fbSuggestion;

  /// No description provided for @fbComplaint.
  ///
  /// In ar, this message translates to:
  /// **'شكوى'**
  String get fbComplaint;

  /// No description provided for @fbBug.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة تقنية'**
  String get fbBug;

  /// No description provided for @fbTextHint.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رسالتك هنا… مثلاً: أتمنى إضافة مهام خاصة برمضان'**
  String get fbTextHint;

  /// No description provided for @fbEmailHint.
  ///
  /// In ar, this message translates to:
  /// **'بريدك للرد عليك (اختياري)'**
  String get fbEmailHint;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @fbPrevious.
  ///
  /// In ar, this message translates to:
  /// **'رسائلك السابقة'**
  String get fbPrevious;

  /// No description provided for @fbSentAgo.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت · {ago}'**
  String fbSentAgo(String ago);

  /// No description provided for @fbThanks.
  ///
  /// In ar, this message translates to:
  /// **'وصلت رسالتك ✓ شكراً لمساعدتنا في تحسين أسرتي'**
  String get fbThanks;

  /// No description provided for @mailboxNote.
  ///
  /// In ar, this message translates to:
  /// **'يحاكي الرسائل التي سيرسلها التطبيق الحقيقي إلى بريد كل شخص.'**
  String get mailboxNote;

  /// No description provided for @noMail.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد رسائل بعد.'**
  String get noMail;

  /// No description provided for @mailTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى:'**
  String get mailTo;

  /// No description provided for @appearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب الجهاز'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'ليلي'**
  String get themeDark;

  /// No description provided for @privacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get privacyPolicy;

  /// No description provided for @deleteMyAccount.
  ///
  /// In ar, this message translates to:
  /// **'حذف حسابي'**
  String get deleteMyAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف حسابك وبياناتك من الأسرة نهائياً. هل أنت متأكد؟'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteFamily.
  ///
  /// In ar, this message translates to:
  /// **'حذف الأسرة كاملة'**
  String get deleteFamily;

  /// No description provided for @deleteFamilyConfirm.
  ///
  /// In ar, this message translates to:
  /// **'ستُحذف الأسرة وكل أفرادها ومهامها ونقاطها نهائياً ولا يمكن التراجع. هل أنت متأكد؟'**
  String get deleteFamilyConfirm;

  /// No description provided for @deleteConfirmBtn.
  ///
  /// In ar, this message translates to:
  /// **'حذف نهائي'**
  String get deleteConfirmBtn;

  /// No description provided for @deleted.
  ///
  /// In ar, this message translates to:
  /// **'تم الحذف'**
  String get deleted;

  /// No description provided for @dangerZone.
  ///
  /// In ar, this message translates to:
  /// **'الحذف'**
  String get dangerZone;

  /// No description provided for @version.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {v}'**
  String version(String v);

  /// No description provided for @demoMode.
  ///
  /// In ar, this message translates to:
  /// **'الوضع التجريبي'**
  String get demoMode;

  /// No description provided for @demoBanner.
  ///
  /// In ar, this message translates to:
  /// **'أنت في التجربة السريعة — البيانات على جهازك فقط'**
  String get demoBanner;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل…'**
  String get loading;

  /// Quick task suggestions, separated by |
  ///
  /// In ar, this message translates to:
  /// **'ترتيب السرير|قراءة صفحة قرآن|صلاة الفجر في وقتها|مراجعة الواجبات|ترتيب المجلس|المساعدة في المطبخ|قراءة كتاب 15 دقيقة|ترتيب الألعاب'**
  String get taskPresets;

  /// No description provided for @memberTaskMeta.
  ///
  /// In ar, this message translates to:
  /// **'{when} · {points} نقطة'**
  String memberTaskMeta(String when, String points);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return L10nAr();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
