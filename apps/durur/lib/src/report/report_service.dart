/// زر «أبلغ عن خطأ» بلا خادم (SPEC الميزة 9، ARCHITECTURE §10، D14 وقرار
/// المالك النهائي: نموذج Google بلا بريد). Dart صافٍ بلا Flutter.
///
/// الترتيب: نموذج خارجي (إن ضُبط رابطه) ← نافذة فيها نص البلاغ مع «نسخ».
/// لا يُرسل شيء تلقائياً، ولا بيانات شخصية: لا مدينة ولا إحداثيات ولا معرّف.
library;

/// رابط يُسمح بفتحه في المتصفح: https مع نطاق، ولا شيء غيره.
bool isOpenableUrl(Uri uri) => uri.scheme == 'https' && uri.host.isNotEmpty;

/// حقول النموذج التي يمكن تعبئتها مسبقاً.
enum ReportField {
  item('item'),
  region('region'),
  date('date'),
  appVersion('appVersion'),
  dataVersion('dataVersion'),
  details('details');

  const ReportField(this.code);

  /// الاسم في `REPORT_FORM_FIELDS`.
  final String code;

  static ReportField? fromCode(String code) {
    for (final f in values) {
      if (f.code == code) return f;
    }
    return null;
  }
}

/// معرّف حقل في نموذج Google: `entry.<رقم>`.
final _entryId = RegExp(r'^entry\.\d+$');

/// يقرأ `REPORT_FORM_FIELDS`: أزواج `اسم=entry.رقم` مفصولة بفواصل، مثل
/// `item=entry.111,region=entry.222`. يُهمل أي زوج غير صالح (اسم غير معروف أو
/// معرّف ليس `entry.<رقم>`) فلا يدخل الرابط شيء غير متوقع.
Map<ReportField, String> parseFormFields(String raw) {
  final result = <ReportField, String>{};
  for (final part in raw.split(',')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    final field = ReportField.fromCode(part.substring(0, i).trim());
    final id = part.substring(i + 1).trim();
    if (field == null || !_entryId.hasMatch(id)) continue;
    result[field] = id;
  }
  return result;
}

/// إعدادات البلاغ من `--dart-define-from-file=config/app_config.json`
/// (ليست أسراراً، لكنها لا تُكتب في الكود).
class ReportConfig {
  const ReportConfig({this.formUrl = '', this.formFields = ''});

  /// القيم المضمّنة وقت البناء؛ فارغة إن لم تُمرَّر.
  factory ReportConfig.fromEnvironment() => const ReportConfig(
    formUrl: String.fromEnvironment('REPORT_FORM_URL'),
    formFields: String.fromEnvironment('REPORT_FORM_FIELDS'),
  );

  /// `REPORT_FORM_URL`: رابط النموذج (https فقط).
  final String formUrl;

  /// `REPORT_FORM_FIELDS`: اختياري، انظر [parseFormFields].
  final String formFields;

  /// رابط النموذج إن كان صالحاً (https بنطاق)، وإلا null.
  Uri? get formUri {
    final raw = formUrl.trim();
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    return uri != null && isOpenableUrl(uri) ? uri : null;
  }

  bool get hasForm => formUri != null;

  /// خريطة الحقول الصالحة (قد تكون فارغة).
  Map<ReportField, String> get fields => parseFormFields(formFields);

  /// يُعبأ النموذج مسبقاً إن وُجد حقل صالح واحد على الأقل.
  bool get prefills => hasForm && fields.isNotEmpty;
}

/// محتوى البلاغ: الأسطر المعروضة والمنسوخة (من ملف الترجمة)، وقيم حقول
/// النموذج. لا يحمل إلا: العنصر، والمنطقة، والتاريخ المعروض، ونسخة التطبيق،
/// ونسخة البيانات.
class ReportMessage {
  const ReportMessage({required this.lines, required this.values});

  /// كل معلومة في سطر (DESIGN 8.8 بند 3).
  final List<String> lines;

  /// قيم حقول النموذج (بلا [ReportField.details]، فهو [text]).
  final Map<ReportField, String> values;

  /// النص الذي يُنسخ.
  String get text => lines.join('\n');

  String valueOf(ReportField field) =>
      field == ReportField.details ? text : (values[field] ?? '');
}

/// رابط النموذج، معبأً مسبقاً بالحقول المضبوطة (إن وُجدت). القيم مرمّزة
/// (UTF-8 بنسبة مئوية)؛ ومعاملات الرابط الأصلية تبقى كما هي.
Uri buildFormUri(Uri form, Map<ReportField, String> fields, ReportMessage m) {
  if (fields.isEmpty) return form;
  final added = [
    for (final f in ReportField.values)
      if (fields[f] case final id?)
        '$id=${Uri.encodeQueryComponent(m.valueOf(f))}',
  ].join('&');
  final query = form.query.isEmpty ? added : '${form.query}&$added';
  return form.replace(query: query);
}

/// نتيجة الضغط على زر البلاغ.
enum ReportOutcome {
  /// فُتح النموذج معبأً مسبقاً.
  formPrefilled,

  /// فُتح النموذج بلا تعبئة، ونُسخ نص البلاغ للحافظة ليلصقه المستخدم.
  formWithCopiedText,

  /// لم يُضبط نموذج، أو تعذّر فتحه: نافذة النسخ.
  copy,

  /// تعذّر النسخ للحافظة قبل فتح النموذج (بلا تعبئة مسبقة)، فلم يُفتح:
  /// رسالة فشل النسخ لا «تعذّر فتح النموذج».
  copyFailed,
}

/// يفتح رابطاً (https فقط، `urlOpenerProvider`)؛ false عند الفشل.
typedef UrlOpener = Future<bool> Function(Uri uri);

/// ينسخ نصاً للحافظة.
typedef TextCopier = Future<void> Function(String text);

class ReportService {
  const ReportService({
    required this.config,
    required this.openUrl,
    required this.copyText,
  });

  final ReportConfig config;
  final UrlOpener openUrl;
  final TextCopier copyText;

  /// نموذج ← نسخ. بلا تعبئة مسبقة يُنسخ النص للحافظة قبل فتح النموذج.
  /// فشل النسخ ← [ReportOutcome.copyFailed] بلا فتح؛ فشل الفتح ←
  /// [ReportOutcome.copy]. لا يرمي.
  Future<ReportOutcome> report(ReportMessage message) async {
    final form = config.formUri;
    if (form == null) return ReportOutcome.copy;
    final fields = config.fields;
    try {
      if (fields.isEmpty) {
        try {
          await copyText(message.text);
        } on Object {
          return ReportOutcome.copyFailed;
        }
        if (await openUrl(form)) return ReportOutcome.formWithCopiedText;
      } else {
        if (await openUrl(buildFormUri(form, fields, message))) {
          return ReportOutcome.formPrefilled;
        }
      }
    } on Object {
      // يسقط إلى النسخ.
    }
    return ReportOutcome.copy;
  }
}
