/// القيم المرجعية لطلوع سهيل والثريا كما في research/REFERENCE_RISINGS.md
/// (منقولة للاختبار فقط، **غير معتمدة بعد** من المراجع).
///
/// المعيار المعتمد للتطبيق: الرؤية **بالعين المجردة** (قرار المدير). لذلك:
/// - [ReferenceKind.nakedEye]: يُختبر الفرق ±يومين (SPEC الميزة 5، المعيار 3).
/// - [ReferenceKind.instrument]: رصد بمنظار/تصوير، يسبق العين المجردة عادة؛
///   يُختبر فقط أن المحسوب ليس قبله.
/// - [ReferenceKind.unknown]: إعلان تقريبي أو معيار غير مذكور؛ لا يُختبر.
/// - [ReferenceKind.conflicting]: يتعارض هندسياً مع مراجع العين المجردة الأخرى
///   (بأي قوس رؤية)؛ سؤال للمراجع في research/GAPS.md. يُختبر بدله الفرق
///   الهندسي المتوقع (انظر heliacal_reference_test.dart).
enum ReferenceKind { nakedEye, instrument, unknown, conflicting }

class ReferenceRising {
  const ReferenceRising({
    required this.star,
    required this.cityId,
    required this.years,
    required this.month,
    required this.day,
    required this.kind,
    required this.source,
    this.firstSighting = true,
    this.note,
    this.conflict,
  });

  /// 'suhail' أو 'thurayya'.
  final String star;

  /// أقرب مدينة في cities.json للموقع المذكور.
  final String cityId;

  /// السنة المذكورة، أو مدى 2025–2040 إن كان التاريخ «متكرراً سنوياً».
  final List<int> years;
  final int month;
  final int day;
  final ReferenceKind kind;
  final String source;

  /// هل يقول المصدر إنه **أول** رؤية؟ فقط عندها يصلح رصد الأداة حداً أدنى.
  final bool firstSighting;
  final String? note;

  /// سبب التصنيف [ReferenceKind.conflicting].
  final String? conflict;
}

final _everyYear = [for (var y = 2025; y <= 2040; y++) y];

final referenceRisings = <ReferenceRising>[
  // —— سهيل ——
  ReferenceRising(
    star: 'suhail',
    cityId: 'kuwait_city',
    years: _everyYear,
    month: 9,
    day: 7,
    kind: ReferenceKind.nakedEye,
    source: 'S13',
    note: 'المنظار 4 سبتمبر ثم العين المجردة بعد نحو 3 أيام (≈ 7 سبتمبر)',
  ),
  ReferenceRising(
    star: 'suhail',
    cityId: 'sakaka',
    years: [2026],
    month: 9,
    day: 8,
    kind: ReferenceKind.nakedEye,
    source: 'S23',
    note: 'أقصى شمال السعودية ≈ 30–31° ش، تقريبي؛ سكاكا 29.97° ش',
  ),
  ReferenceRising(
    star: 'suhail',
    cityId: 'kuwait_city',
    years: _everyYear,
    month: 9,
    day: 4,
    kind: ReferenceKind.instrument,
    source: 'S13',
  ),
  ReferenceRising(
    star: 'suhail',
    cityId: 'dubai',
    years: [2026],
    month: 8,
    day: 22,
    kind: ReferenceKind.instrument,
    source: 'S11',
  ),
  ReferenceRising(
    star: 'suhail',
    cityId: 'kuwait_city',
    years: _everyYear,
    month: 9,
    day: 5,
    kind: ReferenceKind.unknown,
    source: 'S14',
  ),
  ReferenceRising(
    star: 'suhail',
    cityId: 'jazan',
    years: [2026],
    month: 8,
    day: 7,
    kind: ReferenceKind.unknown,
    source: 'S23',
  ),
  ReferenceRising(
    star: 'suhail',
    cityId: 'muscat',
    years: [2024],
    month: 8,
    day: 26,
    kind: ReferenceKind.unknown,
    source: 'S25',
    note: 'رؤية في أو قبل 26 أغسطس؛ المدينة غير مذكورة',
  ),
  ReferenceRising(
    star: 'suhail',
    cityId: 'doha',
    years: [2025],
    month: 9,
    day: 1,
    kind: ReferenceKind.conflicting,
    source: 'S24',
    note: 'الأسبوع الأول من سبتمبر (1–7) بالعين المجردة، دار التقويم القطري',
    conflict:
        'الدوحة (25.3° ش) جنوب الكويت (29.4° ش) بنحو 4°، فيطلع فيها سهيل '
        'قبل الكويت بنحو 10 أيام بأي قوس رؤية؛ فلا يتسق «الأسبوع الأول من '
        'سبتمبر» للدوحة مع «≈ 7 سبتمبر» للكويت (S13). سؤال للمراجع في GAPS.md.',
  ),
  // —— الثريا ——
  ReferenceRising(
    star: 'thurayya',
    cityId: 'dubai',
    years: [2025],
    month: 6,
    day: 12,
    kind: ReferenceKind.instrument,
    source: 'S26',
    firstSighting: false,
    note: 'تصوير قبل الشروق بنحو 35 دقيقة؛ المدينة غير محددة في الإمارات',
  ),
];
